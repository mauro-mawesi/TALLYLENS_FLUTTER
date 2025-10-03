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

class _BubblesShimmer extends StatefulWidget {
  const _BubblesShimmer();
  @override
  State<_BubblesShimmer> createState() => _BubblesShimmerState();
}

class _BubblesShimmerState extends State<_BubblesShimmer> with TickerProviderStateMixin {
  late AnimationController _shimmerController;
  late AnimationController _pulseController;
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _pulseController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      height: 196,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;

          // Posiciones de las burbujas (simulando el layout real)
          final bubbleCount = 4;
          final sizes = [72.0, 64.0, 78.0, 68.0];
          final yFracs = [0.45, 0.65, 0.35, 0.55];

          final sidePad = 50.0;
          final gap = (w - 2 * sidePad) / (bubbleCount - 1);

          final positions = List.generate(bubbleCount, (i) {
            final cx = sidePad + i * gap;
            final cy = 60 + yFracs[i] * (h - 100);
            return Offset(cx, cy);
          });

          return AnimatedBuilder(
            animation: Listenable.merge([_shimmerController, _pulseController, _fadeController]),
            builder: (context, child) {
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // Líneas de conexión con fade
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _ShimmerLinePainter(
                        offsets: positions,
                        progress: _fadeController.value,
                        color: isDark
                          ? Colors.white.withOpacity(0.1)
                          : Colors.black.withOpacity(0.08),
                      ),
                    ),
                  ),

                  // Burbujas con pulso y shimmer
                  ...List.generate(bubbleCount, (i) {
                    final pos = positions[i];
                    final size = sizes[i];
                    final radius = size / 2;

                    // Fase de pulso escalonada para cada burbuja
                    final phaseOffset = i * 0.25;
                    final pulseValue = (((_pulseController.value + phaseOffset) % 1.0) * 2 - 1).abs();
                    final scale = 1.0 + pulseValue * 0.08;

                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Label shimmer (encima de la burbuja)
                        Positioned(
                          left: pos.dx - 30,
                          top: pos.dy - radius - 24,
                          child: _ShimmerBox(
                            width: 60,
                            height: 12,
                            shimmerProgress: _shimmerController.value,
                            borderRadius: 6,
                            isDark: isDark,
                          ),
                        ),

                        // Burbuja con glow animado
                        Positioned(
                          left: pos.dx - radius,
                          top: pos.dy - radius,
                          child: Transform.scale(
                            scale: scale,
                            child: Container(
                              width: size,
                              height: size,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    (isDark ? Colors.white : Colors.black).withOpacity(0.08),
                                    (isDark ? Colors.white : Colors.black).withOpacity(0.04),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: cs.primary.withOpacity(0.15 * pulseValue),
                                    blurRadius: 20 + pulseValue * 10,
                                    spreadRadius: 2 + pulseValue * 3,
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                                  child: Stack(
                                    children: [
                                      // Shimmer gradient overlay
                                      Positioned.fill(
                                        child: CustomPaint(
                                          painter: _CircleShimmerPainter(
                                            progress: _shimmerController.value,
                                            color: cs.primary.withOpacity(0.12),
                                          ),
                                        ),
                                      ),
                                      // Valor simulado
                                      Center(
                                        child: _ShimmerBox(
                                          width: size * 0.5,
                                          height: 10,
                                          shimmerProgress: _shimmerController.value,
                                          borderRadius: 5,
                                          isDark: isDark,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Partículas flotantes alrededor
                        if (pulseValue > 0.7)
                          ...List.generate(3, (j) {
                            final angle = (i * 3 + j) * math.pi * 2 / 9;
                            final distance = radius + 10 + pulseValue * 8;
                            final px = pos.dx + math.cos(angle) * distance;
                            final py = pos.dy + math.sin(angle) * distance;

                            return Positioned(
                              left: px - 2,
                              top: py - 2,
                              child: Opacity(
                                opacity: (pulseValue - 0.7) * 3.3,
                                child: Container(
                                  width: 4,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: cs.primary.withOpacity(0.6),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: cs.primary.withOpacity(0.4),
                                        blurRadius: 4,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                      ],
                    );
                  }),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

// Widget reutilizable para cajas con efecto shimmer
class _ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final double shimmerProgress;
  final double borderRadius;
  final bool isDark;

  const _ShimmerBox({
    required this.width,
    required this.height,
    required this.shimmerProgress,
    this.borderRadius = 8,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
          begin: Alignment(-1.0 + shimmerProgress * 2, 0),
          end: Alignment(shimmerProgress * 2, 0),
          colors: [
            (isDark ? Colors.white : Colors.black).withOpacity(0.06),
            (isDark ? Colors.white : Colors.black).withOpacity(0.12),
            (isDark ? Colors.white : Colors.black).withOpacity(0.06),
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
    );
  }
}

// Painter para líneas con fade animado
class _ShimmerLinePainter extends CustomPainter {
  final List<Offset> offsets;
  final double progress;
  final Color color;

  _ShimmerLinePainter({
    required this.offsets,
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (offsets.length < 2) return;

    for (int i = 0; i < offsets.length - 1; i++) {
      final p0 = offsets[i];
      final p1 = offsets[i + 1];

      // Opacidad oscilante
      final opacity = 0.3 + progress * 0.4;

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color.withOpacity(opacity)
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(p0, p1, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ShimmerLinePainter oldDelegate) =>
    oldDelegate.progress != progress || oldDelegate.offsets != offsets;
}

// Painter para efecto shimmer circular
class _CircleShimmerPainter extends CustomPainter {
  final double progress;
  final Color color;

  _CircleShimmerPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Gradiente radial animado
    final paint = Paint()
      ..shader = RadialGradient(
        center: Alignment(-1.0 + progress * 2, -1.0 + progress * 2),
        radius: 1.5,
        colors: [
          color,
          color.withOpacity(0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _CircleShimmerPainter oldDelegate) =>
    oldDelegate.progress != progress;
}
