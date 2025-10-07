import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:recibos_flutter/core/models/receipt.dart';
import 'package:recibos_flutter/core/theme/app_colors.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:recibos_flutter/core/widgets/glass_card.dart';

class ReceiptTicketHeader extends StatelessWidget {
  final Receipt receipt;
  const ReceiptTicketHeader({super.key, required this.receipt});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final currency = NumberFormat.simpleCurrency(locale: localeTag, name: receipt.currency);
    final title = receipt.merchantName ?? (receipt.category ?? t.receiptLabel);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TicketTopEdge(),
        GlassCard(
          borderRadius: 20,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title and total
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: FlowColors.text(context),
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: FlowColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      currency.format(receipt.amount ?? 0),
                      style: const TextStyle(
                        color: FlowColors.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Info chips
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (receipt.purchaseDate != null)
                    _InfoChip(
                      icon: Icons.event_outlined,
                      label: DateFormat.yMMMd(localeTag).format(receipt.purchaseDate!.toLocal()),
                    ),
                  if ((receipt.category ?? '').isNotEmpty)
                    _InfoChip(
                      icon: Icons.sell_outlined,
                      label: receipt.category!,
                    ),
                  if ((receipt.notes ?? '').isNotEmpty)
                    _InfoChip(
                      icon: Icons.sticky_note_2_outlined,
                      label: receipt.notes!,
                      maxWidth: 180,
                    ),
                ],
              ),
            ],
          ),
        ),
        _TicketPerforation(),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final double? maxWidth;
  const _InfoChip({required this.icon, required this.label, this.maxWidth});

  @override
  Widget build(BuildContext context) {
    final text = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: FlowColors.text(context),
            fontWeight: FontWeight.w600,
          ),
    );
    return Container(
      constraints: maxWidth != null ? BoxConstraints(maxWidth: maxWidth!) : const BoxConstraints(),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: FlowColors.glassTint(context),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: FlowColors.divider(context), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: FlowColors.textSecondary(context)),
          const SizedBox(width: 6),
          Flexible(child: text),
        ],
      ),
    );
  }
}

/// Decorative top edge reminiscent of ticket paper.
class _TicketTopEdge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final color = FlowColors.divider(context).withOpacity(0.4);
    return CustomPaint(
      painter: _TopEdgePainter(color),
      child: const SizedBox(height: 10),
    );
  }
}

class _TopEdgePainter extends CustomPainter {
  final Color color;
  _TopEdgePainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    // Small rounded tabs along the width
    const radius = 3.0;
    final spacing = 16.0;
    for (double x = spacing / 2; x < size.width; x += spacing) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(x, size.height), width: radius * 2, height: radius * 2), const Radius.circular(radius)),
        paint,
      );
    }
  }
  @override
  bool shouldRepaint(covariant _TopEdgePainter oldDelegate) => false;
}

/// Perforated line like a ticket tear line.
class _TicketPerforation extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final color = FlowColors.divider(context).withOpacity(0.7);
    return SizedBox(
      height: 20,
      child: Stack(
        children: [
          // dashed line
          Positioned.fill(
            child: CustomPaint(painter: _DashedLinePainter(color)),
          ),
          // side cutouts
          Align(
            alignment: Alignment.centerLeft,
            child: _CutoutDot(),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: _CutoutDot(),
          ),
        ],
      ),
    );
  }
}

class _CutoutDot extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      decoration: const BoxDecoration(
        color: Colors.transparent,
        shape: BoxShape.circle,
      ),
      child: CustomPaint(
        painter: _CutoutPainter(FlowColors.background(context)),
      ),
    );
  }
}

class _CutoutPainter extends CustomPainter {
  final Color bg;
  _CutoutPainter(this.bg);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = bg;
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.width / 2, paint);
    final border = Paint()
      ..color = bg.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.width / 2, border);
  }
  @override
  bool shouldRepaint(covariant _CutoutPainter oldDelegate) => false;
}

class _DashedLinePainter extends CustomPainter {
  final Color color;
  _DashedLinePainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    const dashWidth = 6.0;
    const dashSpace = 6.0;
    double x = 0;
    final y = size.height / 2;
    while (x < size.width) {
      canvas.drawLine(Offset(x, y), Offset(x + dashWidth, y), paint);
      x += dashWidth + dashSpace;
    }
  }
  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) => false;
}

