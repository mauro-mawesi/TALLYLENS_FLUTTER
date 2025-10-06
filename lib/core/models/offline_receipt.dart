import 'package:hive/hive.dart';

part 'offline_receipt.g.dart';

/// Estado de sincronización de un recibo offline
enum SyncStatus {
  pending,    // Pendiente de sincronizar
  syncing,    // Sincronizando en este momento
  synced,     // Sincronizado exitosamente
  error,      // Error al sincronizar
}

/// Modelo para recibos almacenados offline
@HiveType(typeId: 0)
class OfflineReceipt extends HiveObject {
  @HiveField(0)
  String localId; // ID local único (UUID generado en cliente)

  @HiveField(1)
  String? serverId; // ID del servidor después de sync (null si aún no está sincronizado)

  @HiveField(2)
  String imageLocalPath; // Path local de la imagen

  @HiveField(3)
  String? imageUrl; // URL de la imagen en servidor (después de upload)

  @HiveField(4)
  String? merchantName;

  @HiveField(5)
  String? category;

  @HiveField(6)
  double? amount;

  @HiveField(7)
  String? currency;

  @HiveField(8)
  DateTime? purchaseDate;

  @HiveField(9)
  String? notes;

  @HiveField(10)
  int syncStatus; // SyncStatus as int (0=pending, 1=syncing, 2=synced, 3=error)

  @HiveField(11)
  DateTime createdAt;

  @HiveField(12)
  DateTime updatedAt;

  @HiveField(13)
  String? errorMessage; // Mensaje de error si syncStatus == error

  @HiveField(14)
  int retryCount; // Número de intentos de sincronización

  @HiveField(15)
  DateTime? lastSyncAttempt; // Última vez que se intentó sincronizar

  @HiveField(16)
  bool processedByMLKit; // Si la imagen fue procesada por ML Kit

  @HiveField(17)
  String? source; // 'camera' o 'gallery'

  @HiveField(18)
  Map<String, dynamic>? parsedData; // Datos parseados del recibo (JSON)

  @HiveField(19)
  List<Map<String, dynamic>>? items; // Items del recibo

  OfflineReceipt({
    required this.localId,
    this.serverId,
    required this.imageLocalPath,
    this.imageUrl,
    this.merchantName,
    this.category,
    this.amount,
    this.currency,
    this.purchaseDate,
    this.notes,
    this.syncStatus = 0, // pending por defecto
    required this.createdAt,
    required this.updatedAt,
    this.errorMessage,
    this.retryCount = 0,
    this.lastSyncAttempt,
    this.processedByMLKit = false,
    this.source,
    this.parsedData,
    this.items,
  });

  /// Getter para status tipado
  SyncStatus get status {
    switch (syncStatus) {
      case 1:
        return SyncStatus.syncing;
      case 2:
        return SyncStatus.synced;
      case 3:
        return SyncStatus.error;
      default:
        return SyncStatus.pending;
    }
  }

  /// Setter para status tipado
  set status(SyncStatus value) {
    syncStatus = value.index;
  }

  /// Marca como pendiente de sincronización
  void markAsPending() {
    syncStatus = SyncStatus.pending.index;
    errorMessage = null;
    updatedAt = DateTime.now();
  }

  /// Marca como sincronizando
  void markAsSyncing() {
    syncStatus = SyncStatus.syncing.index;
    lastSyncAttempt = DateTime.now();
    updatedAt = DateTime.now();
  }

  /// Marca como sincronizado exitosamente
  void markAsSynced({required String serverId, String? imageUrl}) {
    this.serverId = serverId;
    if (imageUrl != null) {
      this.imageUrl = imageUrl;
    }
    syncStatus = SyncStatus.synced.index;
    errorMessage = null;
    retryCount = 0;
    updatedAt = DateTime.now();
  }

  /// Marca como error en sincronización
  void markAsError(String error) {
    syncStatus = SyncStatus.error.index;
    errorMessage = error;
    retryCount++;
    updatedAt = DateTime.now();
  }

  /// Indica si debe reintentarse la sincronización
  /// Retry con exponential backoff:
  /// - 1 intento: inmediato
  /// - 2 intentos: 1 min
  /// - 3 intentos: 5 min
  /// - 4 intentos: 15 min
  /// - 5+ intentos: 30 min
  bool shouldRetry() {
    if (status == SyncStatus.synced) return false;
    if (lastSyncAttempt == null) return true;

    final now = DateTime.now();
    final timeSinceLastAttempt = now.difference(lastSyncAttempt!);

    if (retryCount == 0) return true;
    if (retryCount == 1 && timeSinceLastAttempt.inMinutes >= 1) return true;
    if (retryCount == 2 && timeSinceLastAttempt.inMinutes >= 5) return true;
    if (retryCount == 3 && timeSinceLastAttempt.inMinutes >= 15) return true;
    if (retryCount >= 4 && timeSinceLastAttempt.inMinutes >= 30) return true;

    return false;
  }

  /// Convierte a JSON para enviar al servidor
  Map<String, dynamic> toServerJson() {
    return {
      'localId': localId,
      'imageUrl': imageUrl,
      'merchantName': merchantName,
      'category': category,
      'amount': amount,
      'currency': currency,
      'purchaseDate': purchaseDate?.toIso8601String(),
      'notes': notes,
      'processedByMLKit': processedByMLKit,
      'source': source,
      'parsedData': parsedData,
      'items': items,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Crea desde datos del servidor
  factory OfflineReceipt.fromServerResponse(Map<String, dynamic> json, String localId, String imageLocalPath) {
    return OfflineReceipt(
      localId: localId,
      serverId: json['id'] as String?,
      imageLocalPath: imageLocalPath,
      imageUrl: json['imageUrl'] as String?,
      merchantName: json['merchantName'] as String?,
      category: json['category'] as String?,
      amount: (json['amount'] as num?)?.toDouble(),
      currency: json['currency'] as String?,
      purchaseDate: json['purchaseDate'] != null
          ? DateTime.parse(json['purchaseDate'] as String)
          : null,
      notes: json['notes'] as String?,
      syncStatus: SyncStatus.synced.index,
      createdAt: DateTime.parse(json['createdAt'] as String? ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updatedAt'] as String? ?? DateTime.now().toIso8601String()),
      processedByMLKit: json['processedByMLKit'] as bool? ?? false,
      source: json['source'] as String?,
      parsedData: json['parsedData'] as Map<String, dynamic>?,
      items: (json['items'] as List<dynamic>?)?.cast<Map<String, dynamic>>(),
    );
  }

  @override
  String toString() {
    return 'OfflineReceipt(localId: $localId, serverId: $serverId, status: $status, merchant: $merchantName, amount: $amount)';
  }
}
