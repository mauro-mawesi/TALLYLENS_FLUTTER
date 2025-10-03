import 'dart:ui';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:recibos_flutter/core/di/service_locator.dart';
import 'package:recibos_flutter/core/theme/app_colors.dart';
import '../bloc/monthly_bubbles_cubit.dart';
import '../bloc/monthly_bubbles_state.dart';

class MonthlyBubbles extends StatelessWidget {
  const MonthlyBubbles({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => MonthlyBubblesCubit(api: sl())..load(months: 4),
      child: const _MonthlyBubblesView(),
    );
  }
}

class _MonthlyBubblesView extends StatelessWidget {
  const _MonthlyBubblesView();
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MonthlyBubblesCubit, MonthlyBubblesState>(
      builder: (context, state) {
        if (state is MonthlyBubblesLoading) {
          return const _BubblesShimmer();
        }
        if (state is MonthlyBubblesLoaded) {
          final points = state.points;
          return _BubblesPainterWidget(points: points);
        }
        return const SizedBox.shrink();
      },
    );
  }
}

class _BubblesPainterWidget extends StatelessWidget {
  final List<MonthlyPoint> points;
  const _BubblesPainterWidget({required this.points});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 196,
      child: LayoutBuilder(builder: (ctx, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final n = points.length;
        // Bubble sizes (stable pseudo-random per month)
        const minD = 56.0;
        const maxD = 84.0;
        final sizes = <double>[];
        for (int i = 0; i < n; i++) {
          final seed = points[i].month.millisecondsSinceEpoch ^ (i * 9973);
          final r = math.Random(seed & 0x7fffffff);
          final d = minD + r.nextDouble() * (maxD - minD);
          sizes.add(d);
        }
        final radii = sizes.map((d) => d / 2).toList();
        final maxR = radii.isEmpty ? 20.0 : radii.reduce((a, b) => a > b ? a : b);
        final textStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontSize: 11,
            ) ?? const TextStyle(fontSize: 11);
        // Estimate label height via TextPainter using a sample
        final tp = TextPainter(
          text: TextSpan(text: 'MMM 24', style: textStyle),
          textDirection: Directionality.of(context),
          maxLines: 1,
        )..layout(maxWidth: 100);
        final labelH = tp.size.height;

        final sidePad = maxR + 8; // keep circles inside width
        final gap = n > 1 ? (w - 2 * sidePad) / (n - 1) : 0;

        // Altura aleatoria estable con patrón alternado (arriba/abajo) respecto al anterior
        const double minFrac = 0.25; // parte superior (más alto)
        const double maxFrac = 0.85; // parte inferior (más bajo)
        const double delta = 0.06;   // separación mínima entre consecutivos
        final fracs = <double>[];
        for (int i = 0; i < n; i++) {
          final seed = points[i].month.millisecondsSinceEpoch ^ (i * 7919);
          final r = math.Random(seed & 0x7fffffff).nextDouble();
          double base = minFrac + r * (maxFrac - minFrac);
          if (i == 0) {
            fracs.add(base);
          } else if (i == 1) {
            // determinar patrón inicial
            if ((base - fracs[0]).abs() < 0.01) {
              base = (base + 0.02).clamp(minFrac, maxFrac);
            }
            fracs.add(base);
          } else {
            final prev = fracs[i - 1];
            final upPattern = fracs[0] < fracs[1];
            final wantGreater = upPattern ? (i % 2 == 1) : (i % 2 == 0);
            final r2 = math.Random((seed + 1337) & 0x7fffffff).nextDouble();
            if (wantGreater) {
              double lower = (prev + delta).clamp(minFrac, math.max(minFrac, maxFrac - 0.01));
              double upper = maxFrac;
              if (lower >= upper) { lower = math.max(minFrac, prev); upper = math.min(maxFrac, lower + 0.02); }
              base = lower + r2 * (upper - lower);
            } else {
              double lower = minFrac;
              double upper = (prev - delta).clamp(math.min(minFrac + 0.01, maxFrac - 0.01), maxFrac);
              if (upper <= lower) { upper = math.min(maxFrac, prev); lower = math.max(minFrac, upper - 0.02); }
              base = lower + r2 * (upper - lower);
            }
            fracs.add(base);
          }
        }

        final centers = <Offset>[];
        for (int i = 0; i < n; i++) {
          final double cx = sidePad + i * gap;
          final topReserve = labelH + 6 + maxR;
          const bottomReserve = 20.0;
          final usable = h - topReserve - bottomReserve;
          final cy = topReserve + (1 - fracs[i]) * usable;
          centers.add(Offset(cx, cy));
        }

        // Determine gradient endpoints based on bubble color of first and last node
        final palette = const [
          Color(0xFF5A29A8), // purple
          Color(0xFF2C5A4C), // deep green
          Color(0xFF45C677), // green
          Color(0xFF2D6372), // teal
        ];
        final bubbleColors = List<Color>.generate(n, (i) => palette[i % palette.length]);

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Line gradient from first bubble color to last bubble color
            Positioned.fill(
              child: CustomPaint(
                painter: _LinePainter(offsets: centers, colors: bubbleColors),
              ),
            ),
            ...List.generate(n, (i) {
              final c = centers[i];
              final p = points[i];
              final bubbleColor = bubbleColors[i];
              final bubbleD = sizes[i];
              final bubbleR = radii[i];
              final locale = Localizations.localeOf(context).toLanguageTag();
              final currency = NumberFormat.simpleCurrency(locale: locale);
              final valueStr = currency.format(p.value);
              final raw = DateFormat.MMM(locale).format(p.month).replaceAll('.', '').trim();
              final mmm = (raw.length <= 3 ? raw : raw.substring(0, 3)).toUpperCase();
              final yy = (p.month.year % 100).toString().padLeft(2, '0');
              final label = '$mmm $yy';

              // Label position centered above the circle
              final labelTP = TextPainter(
                text: TextSpan(text: label, style: textStyle),
                textDirection: Directionality.of(context),
                maxLines: 1,
                ellipsis: '…',
              )..layout(maxWidth: 80);
              final lw = labelTP.size.width;
              final lh = labelTP.size.height;

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // Label
                  Positioned(
                    left: (c.dx - lw / 2).clamp(0.0, w - lw),
                    top: c.dy - bubbleR - 6 - lh,
                    child: SizedBox(width: lw, height: lh, child: Text(label, style: textStyle, textAlign: TextAlign.center)),
                  ),
                  // Circle
                  Positioned(
                    left: c.dx - bubbleR,
                    top: c.dy - bubbleR,
                    width: bubbleD,
                    height: bubbleD,
                  child: Container(
                      decoration: BoxDecoration(
                        color: bubbleColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: bubbleColor.withOpacity(0.35), blurRadius: 16, spreadRadius: 0.5),
                        ],
                        border: Border.all(color: FlowColors.divider(context), width: 0.8),
                      ),
                      alignment: Alignment.center,
                      child: Builder(builder: (context) {
                        final bool useBlack = bubbleColor.value == 0xFF45C677; // green bubble → black text
                        return Text(
                          valueStr,
                          style: TextStyle(color: useBlack ? Colors.black : Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                          textAlign: TextAlign.center,
                        );
                      }),
                    ),
                  ),
                ],
              );
            }),
          ],
        );
      }),
    );
  }
}

class _LinePainter extends CustomPainter {
  final List<Offset> offsets;
  final List<Color> colors; // per node, used for segment gradients
  _LinePainter({required this.offsets, required this.colors});
  @override
  void paint(Canvas canvas, Size size) {
    if (offsets.length < 2) return;
    for (int i = 0; i < offsets.length - 1; i++) {
      final p0 = offsets[i];
      final p1 = offsets[i + 1];
      final c0 = colors[i % colors.length];
      final c1 = colors[(i + 1) % colors.length];
      final segPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..shader = ui.Gradient.linear(p0, p1, [c0, c1])
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true;
      // Glow per segment (soft, using start color)
      final glow = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = c0.withOpacity(0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      final seg = Path()
        ..moveTo(p0.dx, p0.dy)
        ..lineTo(p1.dx, p1.dy);
      canvas.drawPath(seg, glow);
      canvas.drawPath(seg, segPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _LinePainter oldDelegate) => oldDelegate.offsets != offsets;
}

class _BubblesShimmer extends StatelessWidget {
  const _BubblesShimmer();
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 120,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(4, (i) => Container(
          width: 44,
          height: 44,
          margin: EdgeInsets.only(left: i == 0 ? 8 : 0, right: i == 3 ? 8 : 0),
          decoration: BoxDecoration(
            color: cs.surfaceVariant.withOpacity(0.3),
            shape: BoxShape.circle,
          ),
        )),
      ),
    );
  }
}
