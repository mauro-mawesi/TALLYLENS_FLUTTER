/// Estadísticas de sincronización
class SyncStats {
  final int totalOffline;
  final int pending;
  final int syncing;
  final int synced;
  final int errors;
  final DateTime? lastSyncTime;
  final bool isSyncing;

  SyncStats({
    required this.totalOffline,
    required this.pending,
    required this.syncing,
    required this.synced,
    required this.errors,
    this.lastSyncTime,
    this.isSyncing = false,
  });

  factory SyncStats.empty() {
    return SyncStats(
      totalOffline: 0,
      pending: 0,
      syncing: 0,
      synced: 0,
      errors: 0,
      lastSyncTime: null,
      isSyncing: false,
    );
  }

  bool get hasPendingReceipts => pending > 0;
  bool get hasErrors => errors > 0;

  SyncStats copyWith({
    int? totalOffline,
    int? pending,
    int? syncing,
    int? synced,
    int? errors,
    DateTime? lastSyncTime,
    bool? isSyncing,
  }) {
    return SyncStats(
      totalOffline: totalOffline ?? this.totalOffline,
      pending: pending ?? this.pending,
      syncing: syncing ?? this.syncing,
      synced: synced ?? this.synced,
      errors: errors ?? this.errors,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      isSyncing: isSyncing ?? this.isSyncing,
    );
  }

  @override
  String toString() {
    return 'SyncStats(total: $totalOffline, pending: $pending, syncing: $syncing, synced: $synced, errors: $errors, isSyncing: $isSyncing)';
  }
}
