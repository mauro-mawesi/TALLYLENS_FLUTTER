import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:recibos_flutter/core/models/offline_receipt.dart';
import 'package:recibos_flutter/core/models/sync_stats.dart';
import 'package:recibos_flutter/core/services/api_service.dart';
import 'package:recibos_flutter/core/services/connectivity_service.dart';
import 'package:recibos_flutter/core/services/errors.dart';
import 'package:path_provider/path_provider.dart';

/// Servicio de sincronización offline-first
/// Maneja la cola de recibos pendientes y sincronización automática
class SyncService with ChangeNotifier {
  static const String _offlineReceiptsBoxName = 'offline_receipts';
  static const String _syncMetaBoxName = 'sync_meta';

  final ApiService _api;
  final ConnectivityService _connectivity;

  Box<OfflineReceipt>? _offlineBox;
  Box? _metaBox;

  bool _isSyncing = false;
  bool _initialized = false;
  Timer? _autoSyncTimer;

  SyncService({
    required ApiService api,
    required ConnectivityService connectivity,
  })  : _api = api,
        _connectivity = connectivity;

  bool get isInitialized => _initialized;
  bool get isSyncing => _isSyncing;

  /// Expone la box de recibos offline (solo para uso interno de servicios)
  Box<OfflineReceipt>? get offlineBox => _offlineBox;

  /// Inicializa Hive y boxes
  Future<void> init() async {
    if (_initialized) return;

    try {
      // Inicializar Hive. Si ya está abierto, de todos modos asegura el registro del adapter
      if (!Hive.isBoxOpen(_offlineReceiptsBoxName)) {
        final dir = await getApplicationDocumentsDirectory();
        Hive.init(dir.path);
      }

      // Registrar adaptadores si no están registrados
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(OfflineReceiptAdapter());
      }

      // Abrir boxes
      _offlineBox = await Hive.openBox<OfflineReceipt>(_offlineReceiptsBoxName);
      _metaBox = await Hive.openBox(_syncMetaBoxName);

      // Escuchar cambios de conectividad para auto-sync
      _connectivity.addListener(_onConnectivityRestored);

      // Auto-sync periódico cada 5 minutos si hay conexión
      _autoSyncTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
        if (_connectivity.isOnline) {
          syncPendingReceipts();
        }
      });

      _initialized = true;
      notifyListeners();

      // Sincronizar pendientes si hay conexión
      if (_connectivity.isOnline) {
        await syncPendingReceipts();
      }
    } catch (e) {
      if (kDebugMode) {
        print('[SyncService] Error initializing: $e');
      }
    }
  }

  /// Se llama cuando se restaura la conectividad
  void _onConnectivityRestored() {
    if (_connectivity.isOnline) {
      if (kDebugMode) {
        print('[SyncService] Connectivity restored, syncing pending receipts...');
      }
      syncPendingReceipts();
    }
  }

  /// Guarda un recibo offline
  Future<OfflineReceipt> saveOfflineReceipt({
    required String localId,
    required String imageLocalPath,
    String? imageUrl,
    String? merchantName,
    String? category,
    double? amount,
    String? currency,
    DateTime? purchaseDate,
    String? notes,
    bool processedByMLKit = false,
    String? source,
    Map<String, dynamic>? parsedData,
    List<Map<String, dynamic>>? items,
  }) async {
    if (!_initialized || _offlineBox == null) {
      await init();
    }

    final now = DateTime.now();
    final receipt = OfflineReceipt(
      localId: localId,
      imageLocalPath: imageLocalPath,
      imageUrl: imageUrl,
      merchantName: merchantName,
      category: category,
      amount: amount,
      currency: currency,
      purchaseDate: purchaseDate,
      notes: notes,
      syncStatus: SyncStatus.pending.index,
      createdAt: now,
      updatedAt: now,
      processedByMLKit: processedByMLKit,
      source: source,
      parsedData: parsedData,
      items: items,
    );

    await _offlineBox!.put(localId, receipt);

    if (kDebugMode) {
      print('[SyncService] Saved offline receipt: $localId');
    }

    notifyListeners();

    // Intentar sincronizar inmediatamente si hay conexión
    if (_connectivity.isOnline) {
      syncPendingReceipts();
    }

    return receipt;
  }

  /// Obtiene todos los recibos offline
  List<OfflineReceipt> getAllOfflineReceipts() {
    if (_offlineBox == null) return [];
    return _offlineBox!.values.toList();
  }

  /// Obtiene recibos pendientes de sincronización
  List<OfflineReceipt> getPendingReceipts() {
    if (_offlineBox == null) return [];
    return _offlineBox!.values
        .where((r) => r.status == SyncStatus.pending || r.status == SyncStatus.error)
        .where((r) => r.shouldRetry())
        .toList();
  }

  /// Obtiene estadísticas de sincronización
  SyncStats getStats() {
    if (_offlineBox == null) {
      return SyncStats.empty();
    }

    final all = _offlineBox!.values.toList();
    final pending = all.where((r) => r.status == SyncStatus.pending).length;
    final syncing = all.where((r) => r.status == SyncStatus.syncing).length;
    final synced = all.where((r) => r.status == SyncStatus.synced).length;
    final errors = all.where((r) => r.status == SyncStatus.error).length;

    final lastSyncTime = _metaBox?.get('lastSyncTime') as DateTime?;

    return SyncStats(
      totalOffline: all.length,
      pending: pending,
      syncing: syncing,
      synced: synced,
      errors: errors,
      lastSyncTime: lastSyncTime,
      isSyncing: _isSyncing,
    );
  }

  /// Sincroniza recibos pendientes con el backend
  Future<void> syncPendingReceipts({bool force = false}) async {
    if (!_initialized || _offlineBox == null) {
      await init();
    }

    // Evitar sincronizaciones concurrentes
    if (_isSyncing && !force) {
      if (kDebugMode) {
        print('[SyncService] Sync already in progress, skipping...');
      }
      return;
    }

    // Verificar conectividad
    if (!_connectivity.isOnline) {
      if (kDebugMode) {
        print('[SyncService] No connectivity, skipping sync');
      }
      return;
    }

    final pending = getPendingReceipts();
    if (pending.isEmpty) {
      if (kDebugMode) {
        print('[SyncService] No pending receipts to sync');
      }
      return;
    }

    _isSyncing = true;
    notifyListeners();

    if (kDebugMode) {
      print('[SyncService] Syncing ${pending.length} pending receipts...');
    }

    try {
      // Sincronizar en lotes de 10
      const batchSize = 10;
      for (var i = 0; i < pending.length; i += batchSize) {
        final end = (i + batchSize < pending.length) ? i + batchSize : pending.length;
        final batch = pending.sublist(i, end);

        await _syncBatch(batch);
      }

      // Actualizar tiempo de última sincronización
      await _metaBox?.put('lastSyncTime', DateTime.now());

      if (kDebugMode) {
        print('[SyncService] Sync completed successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[SyncService] Sync error: $e');
      }
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Sincroniza un lote de recibos
  Future<void> _syncBatch(List<OfflineReceipt> batch) async {
    // Marcar como syncing
    for (final receipt in batch) {
      receipt.markAsSyncing();
      await receipt.save();
    }
    notifyListeners();

    try {
      // 1. Subir imágenes que no tengan URL
      for (final receipt in batch) {
        if (receipt.imageUrl == null || receipt.imageUrl!.isEmpty) {
          try {
            final imageFile = File(receipt.imageLocalPath);
            if (await imageFile.exists()) {
              final imageUrl = await _api.uploadImage(imageFile);
              receipt.imageUrl = imageUrl;
              await receipt.save();
            }
          } catch (e) {
            if (kDebugMode) {
              print('[SyncService] Error uploading image for ${receipt.localId}: $e');
            }
            receipt.markAsError('Error uploading image: $e');
            await receipt.save();
            continue;
          }
        }
      }

      // 2. Preparar payload para batch sync
      final receiptsToSync = batch
          .where((r) => r.imageUrl != null && r.imageUrl!.isNotEmpty)
          .map((r) => r.toServerJson())
          .toList();

      if (receiptsToSync.isEmpty) {
        if (kDebugMode) {
          print('[SyncService] No receipts ready for sync in this batch');
        }
        return;
      }

      // 3. Llamar endpoint de batch sync (si existe). Si falla/no existe, fallback a crear uno a uno
      Response? response;
      try {
        response = await _api.dio.post('/receipts/sync', data: {
          'receipts': receiptsToSync,
        });
      } on DioException catch (e) {
        response = e.response; // usaremos fallback abajo
      }

      final shouldFallback = response == null || response.statusCode != 200;
      if (!shouldFallback) {
        final data = response!.data;
        final synced = data['data']?['synced'] as List<dynamic>?;
        final failed = data['data']?['failed'] as List<dynamic>?;

        // 4. Procesar resultados exitosos
        if (synced != null) {
          for (final syncedReceipt in synced) {
            final localId = syncedReceipt['localId'] as String?;
            final serverId = syncedReceipt['id'] as String?;

            if (localId != null && serverId != null) {
              final receipt = batch.firstWhere((r) => r.localId == localId);
              receipt.markAsSynced(serverId: serverId);
              await receipt.save();
            }
          }
        }

        // 5. Procesar errores
        if (failed != null) {
          for (final failedReceipt in failed) {
            final localId = failedReceipt['localId'] as String?;
            final error = failedReceipt['error'] as String? ?? 'Unknown error';

            if (localId != null) {
              final receipt = batch.firstWhere((r) => r.localId == localId);
              receipt.markAsError(error);
              await receipt.save();
            }
          }
        }

        if (kDebugMode) {
          print('[SyncService] Batch synced: ${synced?.length ?? 0} succeeded, ${failed?.length ?? 0} failed');
        }
      } else {
        // Fallback: crear recibos de a uno con /receipts
        if (kDebugMode) {
          print('[SyncService] /receipts/sync not available or failed (status: ${response?.statusCode}). Fallback to per-item /receipts');
        }
        for (final r in batch) {
          if (r.imageUrl == null || r.imageUrl!.isEmpty) {
            // nada que hacer, ya marcado error arriba por upload
            continue;
          }
          try {
            final created = await _api.createReceipt(
              r.imageUrl!,
              processedByMLKit: r.processedByMLKit,
              source: r.source,
            );
            // extraer id de server de forma resiliente
            String? serverId;
            if (created is Map<String, dynamic>) {
              final dd = created['data'];
              if (dd is Map<String, dynamic>) {
                final maybeId = dd['id'] ?? dd['_id'];
                if (maybeId != null) serverId = maybeId.toString();
              } else {
                final maybeId = created['id'] ?? created['_id'];
                if (maybeId != null) serverId = maybeId.toString();
              }
            }
            if (serverId != null && serverId.isNotEmpty) {
              r.markAsSynced(serverId: serverId);
              await r.save();
            } else {
              r.markAsError('Invalid server response (missing id)');
              await r.save();
            }
          } on DuplicateReceiptException catch (e) {
            final existingId = e.existingReceipt?['id']?.toString();
            if (existingId != null && existingId.isNotEmpty) {
              r.markAsSynced(serverId: existingId);
              await r.save();
            } else {
              r.markAsError('Duplicate but no existing id');
              await r.save();
            }
          } catch (e) {
            if (kDebugMode) {
              print('[SyncService] Fallback create error for ${r.localId}: $e');
            }
            r.markAsError('Fallback sync failed: $e');
            await r.save();
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('[SyncService] Batch sync error: $e');
      }

      // Marcar todos como error
      for (final receipt in batch) {
        receipt.markAsError('Sync failed: $e');
        await receipt.save();
      }
    }

    notifyListeners();
  }

  /// Elimina recibos sincronizados antiguos (más de 30 días)
  Future<void> cleanupSyncedReceipts({int daysToKeep = 30}) async {
    if (_offlineBox == null) return;

    final cutoff = DateTime.now().subtract(Duration(days: daysToKeep));
    final toDelete = <String>[];

    for (final receipt in _offlineBox!.values) {
      if (receipt.status == SyncStatus.synced && receipt.updatedAt.isBefore(cutoff)) {
        toDelete.add(receipt.localId);
      }
    }

    for (final localId in toDelete) {
      await _offlineBox!.delete(localId);
    }

    if (kDebugMode && toDelete.isNotEmpty) {
      print('[SyncService] Cleaned up ${toDelete.length} old synced receipts');
    }

    notifyListeners();
  }

  /// Reintenta sincronizar un recibo específico
  Future<void> retryReceipt(String localId) async {
    if (_offlineBox == null) return;

    final receipt = _offlineBox!.get(localId);
    if (receipt == null) return;

    receipt.markAsPending();
    await receipt.save();
    notifyListeners();

    // Intentar sincronizar
    await syncPendingReceipts();
  }

  /// Elimina un recibo offline
  Future<void> deleteOfflineReceipt(String localId) async {
    if (_offlineBox == null) return;

    await _offlineBox!.delete(localId);
    notifyListeners();

    if (kDebugMode) {
      print('[SyncService] Deleted offline receipt: $localId');
    }
  }

  /// Limpia todos los datos offline
  Future<void> clearAll() async {
    if (_offlineBox == null) return;

    await _offlineBox!.clear();
    await _metaBox?.clear();
    notifyListeners();

    if (kDebugMode) {
      print('[SyncService] Cleared all offline data');
    }
  }

  @override
  void dispose() {
    _autoSyncTimer?.cancel();
    _connectivity.removeListener(_onConnectivityRestored);
    _offlineBox?.close();
    _metaBox?.close();
    super.dispose();
  }
}
