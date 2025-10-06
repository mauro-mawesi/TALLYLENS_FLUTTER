import 'package:flutter/material.dart';
import 'package:recibos_flutter/core/services/sync_service.dart';
import 'package:recibos_flutter/core/di/service_locator.dart';
import 'package:recibos_flutter/core/models/sync_stats.dart';

/// Widget que muestra el estado de sincronización
/// Incluye badge con número de recibos pendientes y botón de sync manual
class SyncIndicator extends StatefulWidget {
  final bool showManualSyncButton;
  final bool compact;

  const SyncIndicator({
    super.key,
    this.showManualSyncButton = true,
    this.compact = false,
  });

  @override
  State<SyncIndicator> createState() => _SyncIndicatorState();
}

class _SyncIndicatorState extends State<SyncIndicator> {
  late final SyncService _syncService;

  @override
  void initState() {
    super.initState();
    _syncService = sl<SyncService>();
    _syncService.addListener(_onSyncStateChanged);
  }

  @override
  void dispose() {
    _syncService.removeListener(_onSyncStateChanged);
    super.dispose();
  }

  void _onSyncStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _manualSync() async {
    await _syncService.syncPendingReceipts(force: true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sincronización completada'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_syncService.isInitialized) {
      return const SizedBox.shrink();
    }

    final stats = _syncService.getStats();

    if (widget.compact) {
      return _buildCompactIndicator(stats);
    }

    return _buildFullIndicator(stats);
  }

  Widget _buildCompactIndicator(SyncStats stats) {
    if (!stats.hasPendingReceipts && !stats.isSyncing) {
      return const SizedBox.shrink();
    }

    return Badge(
      label: Text('${stats.pending}'),
      isLabelVisible: stats.pending > 0,
      child: IconButton(
        icon: stats.isSyncing
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.cloud_upload_outlined),
        onPressed: stats.isSyncing ? null : _manualSync,
        tooltip: stats.isSyncing
            ? 'Sincronizando...'
            : '${stats.pending} recibos pendientes',
      ),
    );
  }

  Widget _buildFullIndicator(SyncStats stats) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  stats.isSyncing
                      ? Icons.cloud_sync
                      : stats.hasPendingReceipts
                          ? Icons.cloud_upload_outlined
                          : Icons.cloud_done_outlined,
                  color: stats.isSyncing
                      ? colors.primary
                      : stats.hasPendingReceipts
                          ? colors.secondary
                          : Colors.green,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getSyncStatusTitle(stats),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (stats.lastSyncTime != null)
                        Text(
                          _getLastSyncText(stats.lastSyncTime!),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurface.withOpacity(0.6),
                          ),
                        ),
                    ],
                  ),
                ),
                if (widget.showManualSyncButton)
                  IconButton(
                    icon: stats.isSyncing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                    onPressed: stats.isSyncing ? null : _manualSync,
                    tooltip: 'Sincronizar ahora',
                  ),
              ],
            ),
            if (stats.pending > 0 || stats.errors > 0) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (stats.pending > 0)
                    _buildStatChip(
                      icon: Icons.schedule,
                      label: '${stats.pending} pendientes',
                      color: colors.secondary,
                    ),
                  if (stats.syncing > 0)
                    _buildStatChip(
                      icon: Icons.sync,
                      label: '${stats.syncing} sincronizando',
                      color: colors.primary,
                    ),
                  if (stats.errors > 0)
                    _buildStatChip(
                      icon: Icons.error_outline,
                      label: '${stats.errors} errores',
                      color: colors.error,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Chip(
      avatar: Icon(icon, size: 16, color: color),
      label: Text(label),
      labelStyle: TextStyle(fontSize: 12, color: color),
      backgroundColor: color.withOpacity(0.1),
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  String _getSyncStatusTitle(SyncStats stats) {
    if (stats.isSyncing) {
      return 'Sincronizando...';
    } else if (stats.pending > 0) {
      return '${stats.pending} recibo${stats.pending > 1 ? 's' : ''} pendiente${stats.pending > 1 ? 's' : ''}';
    } else if (stats.errors > 0) {
      return 'Errores de sincronización';
    } else {
      return 'Todo sincronizado';
    }
  }

  String _getLastSyncText(DateTime lastSync) {
    final now = DateTime.now();
    final diff = now.difference(lastSync);

    if (diff.inSeconds < 60) {
      return 'Hace un momento';
    } else if (diff.inMinutes < 60) {
      return 'Hace ${diff.inMinutes} min';
    } else if (diff.inHours < 24) {
      return 'Hace ${diff.inHours} h';
    } else {
      return 'Hace ${diff.inDays} día${diff.inDays > 1 ? 's' : ''}';
    }
  }
}

/// Badge simple para mostrar en la barra de navegación
class SyncBadge extends StatefulWidget {
  const SyncBadge({super.key});

  @override
  State<SyncBadge> createState() => _SyncBadgeState();
}

class _SyncBadgeState extends State<SyncBadge> {
  late final SyncService _syncService;

  @override
  void initState() {
    super.initState();
    _syncService = sl<SyncService>();
    _syncService.addListener(_onSyncStateChanged);
  }

  @override
  void dispose() {
    _syncService.removeListener(_onSyncStateChanged);
    super.dispose();
  }

  void _onSyncStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_syncService.isInitialized) {
      return const SizedBox.shrink();
    }

    final stats = _syncService.getStats();

    if (!stats.hasPendingReceipts) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '${stats.pending}',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSecondary,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
