import 'dart:io';
import 'package:uuid/uuid.dart';
import 'api_service.dart';
import 'package:image/image.dart' as img;
import 'package:recibos_flutter/core/services/receipts_cache.dart';
import 'package:recibos_flutter/core/models/page_result.dart';
import 'package:recibos_flutter/core/services/widget_service.dart';
import 'package:recibos_flutter/core/services/sync_service.dart';
import 'package:recibos_flutter/core/services/errors.dart';
import 'dart:convert';

/// Clase que maneja la lógica de negocio relacionada con los recibos.
/// Orquesta las operaciones utilizando otros servicios de más bajo nivel.
/// OFFLINE-FIRST: Guarda localmente primero, sincroniza después
class ReceiptService {
  final ApiService _apiService;
  final WidgetService? _widgetService;
  final SyncService _syncService;
  final _uuid = const Uuid();

  ReceiptService({
    required ApiService apiService,
    WidgetService? widgetService,
    required SyncService syncService,
  })  : _apiService = apiService,
        _widgetService = widgetService,
        _syncService = syncService;

  /// Obtiene la lista de recibos desde la API.
  Future<List<dynamic>> getReceipts({
    String? category,
    String? merchant,
    DateTime? dateFrom,
    DateTime? dateTo,
    double? minAmount,
    double? maxAmount,
  }) {
    return _apiService.getReceipts(
      category: category,
      merchant: merchant,
      dateFrom: dateFrom,
      dateTo: dateTo,
      minAmount: minAmount,
      maxAmount: maxAmount,
    );
  }

  /// Proceso completo para crear un nuevo recibo OFFLINE-FIRST.
  /// 1. Guarda el recibo offline inmediatamente (Optimistic UI)
  /// 2. Intenta subir la imagen y sincronizar con el servidor
  /// 3. Si falla, el recibo queda pendiente de sincronización
  /// 4. SyncService se encarga de reintentar automáticamente
  Future<Map<String, dynamic>> createNewReceipt(
    File imageFile, { bool processedByMLKit = false, String? source, bool? forceDuplicate }
  ) async {
    try {
      // Generar ID local único
      final localId = _uuid.v4();

      // 1. OFFLINE-FIRST: Guardar recibo localmente PRIMERO
      final offlineReceipt = await _syncService.saveOfflineReceipt(
        localId: localId,
        imageLocalPath: imageFile.path,
        processedByMLKit: processedByMLKit,
        source: source,
      );

      // 2. Invalidar cache inmediatamente para mostrar el nuevo recibo
      await invalidateCache();

      // 3. INTENTAR sincronizar en background (no bloquear UI)
      _syncInBackground(imageFile, localId, processedByMLKit, source, forceDuplicate);

      // 4. Retornar respuesta optimista
      return {
        'status': 'success',
        'data': {
          'id': localId,
          'localId': localId,
          'imageUrl': imageFile.path,
          'processingStatus': 'pending',
          'syncStatus': 'pending',
          '_isOffline': true, // Flag para indicar que es offline
        }
      };
    } catch (e) {
      print('Error en createNewReceipt: $e');
      rethrow;
    }
  }

  /// Sincroniza en background sin bloquear la UI
  Future<void> _syncInBackground(
    File imageFile,
    String localId,
    bool processedByMLKit,
    String? source,
    bool? forceDuplicate,
  ) async {
    try {
      // 1. Preparar y subir imagen
      final prepared = await _prepareImageForUpload(imageFile);
      String? imageUrl;

      try {
        imageUrl = await _apiService.uploadImage(prepared);
      } catch (uploadError) {
        print('Error uploading image, will retry later: $uploadError');
        // El SyncService reintentará automáticamente
        return;
      }

      // 2. Actualizar recibo offline con la URL de la imagen
      final offlineBox = _syncService.offlineBox;
      final receipt = offlineBox?.get(localId);
      if (receipt != null) {
        receipt.imageUrl = imageUrl;
        await receipt.save();
      }

      // 3. SyncService se encargará de crear el recibo en el servidor
      // mediante el endpoint /receipts/sync
      await _syncService.syncPendingReceipts();

      // 4. Actualizar widgets
      _widgetService?.updateWidgets();

    } catch (e) {
      print('Background sync error (will retry): $e');
      // No hacer nada, el SyncService reintentará automáticamente
    }
  }

  /// Invalida todo el cache de recibos
  Future<void> invalidateCache() async {
    try {
      await ReceiptsCache.clearAll();
    } catch (e) {
      print('Error invalidating cache: $e');
    }
  }

  /// Redimensiona y comprime la imagen antes de subir para reducir tamaño
  /// - Máximo de lado: 2000px
  /// - Calidad JPEG: 85
  /// Si ocurre algún error, devuelve el archivo original.
  Future<File> _prepareImageForUpload(File input) async {
    try {
      final bytes = await input.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return input;
      final int maxSide = 2000;
      img.Image processed = decoded;
      if (decoded.width > maxSide || decoded.height > maxSide) {
        final scale = decoded.width > decoded.height
            ? maxSide / decoded.width
            : maxSide / decoded.height;
        final newW = (decoded.width * scale).round();
        final newH = (decoded.height * scale).round();
        processed = img.copyResize(decoded, width: newW, height: newH, interpolation: img.Interpolation.average);
      }
      final jpg = img.encodeJpg(processed, quality: 85);
      final tempDir = Directory.systemTemp;
      final outPath = '${tempDir.path}/receipt_upload_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final outFile = File(outPath);
      await outFile.writeAsBytes(jpg, flush: true);
      return outFile;
    } catch (_) {
      return input;
    }
  }

  /// Paginación con cache (TTL 10 min). Si la API soporta page/limit, se usa; si no,
  /// igualmente cacheamos la lista completa y servimos páginas locales.
  ///
  /// [forceRefresh]: Si es true, ignora el cache y obtiene datos frescos del servidor
  Future<PageResult> getReceiptsPaged({
    String? category,
    String? merchant,
    DateTime? dateFrom,
    DateTime? dateTo,
    double? minAmount,
    double? maxAmount,
    required int page,
    int pageSize = 20,
    bool forceRefresh = false,
  }) async {
    final key = _cacheKey(
      category: category,
      merchant: merchant,
      dateFrom: dateFrom,
      dateTo: dateTo,
      minAmount: minAmount,
      maxAmount: maxAmount,
    );

    // 1) Intentar usar caché solo para la primera página (si no se forzó refresh)
    if (page == 1 && !forceRefresh) {
      final cached = await ReceiptsCache.get(key, ttl: const Duration(minutes: 10));
      if (cached != null && cached.items.isNotEmpty) {
        final slice = _slice(cached.items, page, pageSize);
        final hasMore = page * pageSize < cached.items.length;
        return PageResult(items: slice, hasMore: hasMore, page: page, pageSize: pageSize, total: cached.total);
      }
    }

    // 2) Llamar API con hint de page/limit (el backend puede ignorarlo sin romper)
    final items = await _apiService.getReceipts(
      category: category,
      merchant: merchant,
      dateFrom: dateFrom,
      dateTo: dateTo,
      minAmount: minAmount,
      maxAmount: maxAmount,
      page: page,
      limit: pageSize,
    );
    // El backend devuelve una página (limit/offset): hasMore por longitud
    bool hasMore = items.length == pageSize;

    // 3) Cachear acumulado (para navegación fluida)
    // 3) Cachear solo la primera página para mejorar UX de pull-to-refresh
    try {
      if (page == 1) {
        await ReceiptsCache.put(key, ReceiptsCacheEntry(
          timestamp: DateTime.now(),
          items: items,
          total: items.length,
        ));
      }
    } catch (_) {}

    // Devolver directamente la página recibida
    return PageResult(items: items, hasMore: hasMore, page: page, pageSize: pageSize, total: null);
  }

  List<dynamic> _slice(List<dynamic> list, int page, int pageSize) {
    final start = (page - 1) * pageSize;
    if (start >= list.length) return const [];
    final end = (start + pageSize).clamp(0, list.length);
    return list.sublist(start, end);
  }

  String _cacheKey({
    String? category,
    String? merchant,
    DateTime? dateFrom,
    DateTime? dateTo,
    double? minAmount,
    double? maxAmount,
  }) {
    final map = {
      'category': category,
      'merchant': merchant,
      'dateFrom': dateFrom?.toIso8601String(),
      'dateTo': dateTo?.toIso8601String(),
      'minAmount': minAmount,
      'maxAmount': maxAmount,
    };
    return base64Url.encode(utf8.encode(json.encode(map)));
  }
}
