import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:recibos_flutter/core/theme/app_colors.dart';
import 'package:recibos_flutter/core/models/receipt.dart';
import 'package:recibos_flutter/core/models/receipt_item.dart';

class ReceiptPaperHeader extends StatelessWidget {
  final Receipt receipt;
  final List<ReceiptItem> items;
  const ReceiptPaperHeader({super.key, required this.receipt, required this.items});

  double? _inferTax() {
    final keywords = ['tax', 'vat', 'iva', 'impuesto'];
    for (final it in items) {
      final txt = (it.product?.name ?? it.originalText ?? '').toLowerCase();
      if (keywords.any((k) => txt.contains(k))) {
        final q = it.quantity ?? 1;
        final u = it.unitPrice ?? 0;
        return it.totalPrice ?? (q * u);
      }
    }
    final total = receipt.amount;
    if (total == null || items.isEmpty) return null;
    final sum = items.fold<double>(0, (p, e) => p + (e.totalPrice ?? 0));
    final diff = total - sum;
    return diff > 0.01 ? diff : null;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final currency = NumberFormat.simpleCurrency(locale: localeTag, name: receipt.currency);
    final date = receipt.purchaseDate?.toLocal();
    final tax = _inferTax();

    final screenW = MediaQuery.of(context).size.width;
    final maxW = math.min(screenW - 32, 360.0);

    final paper = Stack(
      children: [
        // Shadow
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 24, spreadRadius: 2, offset: const Offset(0, 12)),
                  BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6, spreadRadius: 0.5, offset: const Offset(0, 2)),
                ],
              ),
            ),
          ),
        ),
        // Paper body (top scallops only, flat bottom)
        ClipPath(
          clipper: _ScallopedClipper(radius: 5, spacing: 12),
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.black12, width: 0.75),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 24, 18, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            t.receiptLabel.toUpperCase(),
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  letterSpacing: 1.2,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            (receipt.merchantName ?? t.merchantLabel).toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: Colors.black87,
                                  fontSize: 22,
                                ),
                          ),
                          if (date != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              DateFormat('yyyy-MM-dd HH:mm').format(date),
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black87),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const _DashedDivider(),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Total', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: Colors.black87)),
                              if (tax != null) ...[
                                const SizedBox(height: 8),
                                Text(t.tax, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black87)),
                              ],
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              currency.format(receipt.amount ?? 0),
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900, color: Colors.black87, fontSize: 28),
                            ),
                            if (tax != null) ...[
                              const SizedBox(height: 8),
                              Text(currency.format(tax), style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black87)),
                            ],
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const _DashedDivider(),
                  ],
                ),
              ),
              // Inner shadow near bottom to simulate paper curvature (STRONG)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 32,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withOpacity(0.50),
                          Colors.black.withOpacity(0.28),
                          Colors.black.withOpacity(0.12),
                          Colors.black.withOpacity(0.04),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.22, 0.50, 0.75, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
              // Highlight above the shadow to reinforce the fold effect (STRONG)
              Positioned(
                left: 0,
                right: 0,
                bottom: 20,
                height: 28,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withOpacity(0.92),
                          Colors.white.withOpacity(0.60),
                          Colors.white.withOpacity(0.25),
                          Colors.white.withOpacity(0.08),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.25, 0.55, 0.80, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Minimal external fade for smooth integration with background
        Positioned(
          left: 6,
          right: 6,
          bottom: -8,
          height: 10,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.03),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );

    // Reveal animation: slide up from bottom (printer effect) + fade-in
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
          builder: (context, v, child) {
            return Opacity(
              opacity: v.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, (1 - v) * 110),
                child: child,
              ),
            );
          },
          child: paper,
        ),
      ),
    );
  }
}

class _ScallopedClipper extends CustomClipper<Path> {
  final double radius;
  final double spacing;
  _ScallopedClipper({required this.radius, required this.spacing});

  @override
  Path getClip(Size size) {
    final base = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final cutouts = Path();
    for (double x = spacing / 2; x < size.width; x += spacing) {
      cutouts.addOval(Rect.fromCircle(center: Offset(x, 0), radius: radius));
    }
    return Path.combine(ui.PathOperation.difference, base, cutouts);
  }

  @override
  bool shouldReclip(covariant _ScallopedClipper oldClipper) => false;
}

class _DashedDivider extends StatelessWidget {
  const _DashedDivider();
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 16,
      child: CustomPaint(
        painter: _DashedLinePainter(Colors.black54),
        child: const SizedBox.expand(),
      ),
    );
  }
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
