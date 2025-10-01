import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class NeonLineChart extends StatelessWidget {
  final List<FlSpot> points;
  final List<Color> gradient;
  final double minY;
  final double maxY;
  final EdgeInsetsGeometry padding;
  final bool showDots;
  final bool showGrid;

  const NeonLineChart({
    super.key,
    required this.points,
    required this.gradient,
    required this.minY,
    required this.maxY,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
    this.showDots = false,
    this.showGrid = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: padding,
      child: LineChart(
        LineChartData(
          minY: minY,
          maxY: maxY,
          gridData: FlGridData(show: showGrid, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: cs.outline.withOpacity(0.08), strokeWidth: 1)),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(
            handleBuiltInTouches: true,
            touchTooltipData: LineTouchTooltipData(
              tooltipRoundedRadius: 10,
              tooltipPadding: const EdgeInsets.all(10),
              getTooltipColor: (_) => Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.black.withOpacity(0.75),
              getTooltipItems: (spots) => spots
                  .map((s) => LineTooltipItem(
                        s.y.toStringAsFixed(2),
                        TextStyle(color: cs.onSurface, fontWeight: FontWeight.w600),
                      ))
                  .toList(),
            ),
            getTouchedSpotIndicator: (bar, indexes) => indexes
                .map((i) => TouchedSpotIndicatorData(
                      FlLine(color: cs.primary.withOpacity(0.4), strokeWidth: 1.5),
                      FlDotData(show: true, getDotPainter: (s, p, b, i) => FlDotCirclePainter(radius: 3, color: cs.primary, strokeColor: Colors.white, strokeWidth: 1)),
                    ))
                .toList(),
          ),
          lineBarsData: [
            // Glow underlay (thicker, faint)
            LineChartBarData(
              spots: points,
              isCurved: true,
              preventCurveOverShooting: true,
              curveSmoothness: 0.2,
              barWidth: 8,
              dotData: FlDotData(show: false),
              isStrokeCapRound: true,
              gradient: LinearGradient(colors: gradient.map((c) => c.withOpacity(0.22)).toList(), begin: Alignment.centerLeft, end: Alignment.centerRight),
              belowBarData: BarAreaData(show: false),
            ),
            // Main line
            LineChartBarData(
              spots: points,
              isCurved: true,
              preventCurveOverShooting: true,
              curveSmoothness: 0.2,
              barWidth: 3,
              dotData: FlDotData(show: showDots),
              isStrokeCapRound: true,
              gradient: LinearGradient(colors: gradient, begin: Alignment.centerLeft, end: Alignment.centerRight),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: gradient.map((c) => c.withOpacity(0.18)).toList(),
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
