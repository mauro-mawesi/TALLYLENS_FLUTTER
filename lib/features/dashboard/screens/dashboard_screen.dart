import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:recibos_flutter/core/widgets/glass_card.dart';
import 'package:recibos_flutter/core/theme/app_colors.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          t.dashboardTitle,
          style: TextStyle(
            color: FlowColors.text(context),
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: IconThemeData(
          color: FlowColors.iconColor(context),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: FlowColors.backgroundGradient(context),
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _MetricsRow(),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                t.recentLabel,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: FlowColors.text(context),
                ),
              ),
            ),
            const SizedBox(height: 12),
            ...List.generate(3, (i) => _RecentTile(index: i + 1)),
          ],
        ),
      ),
    );
  }
}

class _MetricsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Row(
      children: [
        Expanded(
          child: GlassCard(
            borderRadius: 20,
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.spend30d,
                  style: TextStyle(
                    color: FlowColors.textSecondary(context),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  t.amountDash,
                  style: const TextStyle(
                    color: FlowColors.primary,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: 0.4,
                    minHeight: 6,
                    backgroundColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                    valueColor: AlwaysStoppedAnimation(FlowColors.secondary(context)),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GlassCard(
            borderRadius: 20,
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.receipts30d,
                  style: TextStyle(
                    color: FlowColors.textSecondary(context),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  t.valueDash,
                  style: const TextStyle(
                    color: FlowColors.primary,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: 0.2,
                    minHeight: 6,
                    backgroundColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                    valueColor: AlwaysStoppedAnimation(FlowColors.secondary(context)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RecentTile extends StatelessWidget {
  final int index;
  const _RecentTile({required this.index});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: GlassCard(
        borderRadius: 20,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: FlowColors.secondary(context).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.receipt_long_outlined,
              color: FlowColors.secondary(context),
            ),
          ),
          title: Text(
            '${t.receiptLabel} #$index',
            style: TextStyle(
              color: FlowColors.text(context),
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            t.valueDash,
            style: TextStyle(
              color: FlowColors.textSecondary(context),
              fontSize: 13,
            ),
          ),
          trailing: Text(
            t.amountDash,
            style: const TextStyle(
              color: FlowColors.primary,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }
}
