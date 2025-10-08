import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:recibos_flutter/core/widgets/glass_card.dart';
import 'package:recibos_flutter/core/theme/app_colors.dart';

/// Widget para mostrar gráficos de presupuesto.
/// Soporta diferentes tipos de gráficos: línea, barra, circular.
class BudgetChart extends StatefulWidget {
  final List<ChartDataPoint> data;
  final ChartType type;
  final String? title;
  final String? subtitle;
  final double? maxY;
  final String currency;
  final double? budgetAmount;  // Para calcular el color según progreso
  final double? currentSpending;  // Gasto actual para determinar el color
  final double? projectedAmount;  // Proyección de gasto al final del período
  final bool showBudgetLine;  // Mostrar línea horizontal de presupuesto
  final bool showProjection;  // Mostrar punto de proyección
  final double? projectionX; // X opcional para el punto de proyección (p. ej., día fin de mes)
  final double? xMax;        // Max X opcional para ajustar el eje (p. ej., total de días del mes)

  const BudgetChart({
    super.key,
    required this.data,
    this.type = ChartType.line,
    this.title,
    this.subtitle,
    this.maxY,
    this.currency = 'USD',
    this.budgetAmount,
    this.currentSpending,
    this.projectedAmount,
    this.showBudgetLine = false,
    this.showProjection = false,
    this.projectionX,
    this.xMax,
  });

  @override
  State<BudgetChart> createState() => _BudgetChartState();
}

class _BudgetChartState extends State<BudgetChart> {
  int? _touchedIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: GlassCard(
        borderRadius: 20,
        color: FlowColors.glassTint(context),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.title != null) ...[
              Text(
                widget.title!,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (widget.subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  widget.subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 16),
            ],
            SizedBox(
              height: 200,
              child: _buildChart(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChart(BuildContext context) {
    switch (widget.type) {
      case ChartType.line:
        return _buildLineChart(context);
      case ChartType.bar:
        return _buildBarChart(context);
      case ChartType.pie:
        return _buildPieChart(context);
    }
  }

  // Determinar el color basado en el progreso (igual que BudgetProgressCard)
  Color _getProgressColor(BuildContext context, double currentValue) {
    final colorScheme = Theme.of(context).colorScheme;

    if (widget.budgetAmount == null || widget.budgetAmount == 0) {
      return colorScheme.primary;
    }

    final percentage = (currentValue / widget.budgetAmount!) * 100;

    if (percentage > 100) {
      return colorScheme.error;  // Rojo - sobre presupuesto
    } else if (percentage >= 90) {
      return Colors.orange;  // Naranja - cerca del límite
    } else if (percentage >= 70) {
      return Colors.amber;  // Amarillo - advertencia
    } else {
      return colorScheme.primary;  // Azul/Púrpura - normal
    }
  }

  // Crear gradiente púrpura-cian (igual que el resumen de gastos)
  LinearGradient _createProgressGradient(BuildContext context) {
    return const LinearGradient(
      colors: [Color(0xFF8A2BE2), Color(0xFF00E3FF)],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    );
  }

  Widget _buildLineChart(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (widget.data.isEmpty) {
      final l10n = AppLocalizations.of(context);
      return Center(
        child: Text(
          l10n?.chartNoDataAvailable ?? 'No data available',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
        ),
      );
    }

    final spots = widget.data.asMap().entries.map((entry) {
      final dp = entry.value;
      final x = dp.x ?? entry.key.toDouble();
      return FlSpot(x, dp.value);
    }).toList();

    // Agregar punto de proyección si está habilitado
    List<FlSpot> projectionSpots = [];
    if (widget.showProjection && widget.projectedAmount != null && spots.isNotEmpty) {
      // El punto de proyección se coloca en X indicada (p. ej., último día del mes)
      final projX = widget.projectionX ?? (spots.last.x + 1);
      projectionSpots.add(FlSpot(projX, widget.projectedAmount!));
    }

    // Crear gradiente basado en el progreso del presupuesto
    final lineGradient = _createProgressGradient(context);

    // Mapa auxiliar x->label (si los data points incluyen x)
    final Map<double, String> xLabelMap = {
      for (final dp in widget.data)
        if (dp.x != null) dp.x!: dp.label
    };

    return LineChart(
      LineChartData(
        // Líneas de referencia (presupuesto y proyección)
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            // Línea de presupuesto (horizontal)
            if (widget.showBudgetLine && widget.budgetAmount != null)
              HorizontalLine(
                y: widget.budgetAmount!,
                color: colorScheme.primary.withOpacity(0.5),
                strokeWidth: 2,
                dashArray: [8, 4],
                label: HorizontalLineLabel(
                  show: true,
                  alignment: Alignment.topRight,
                  padding: const EdgeInsets.only(right: 8, bottom: 4),
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                  labelResolver: (line) => 'Budget',
                ),
              ),
          ],
        ),
        // Touch handling para la línea interactiva
        lineTouchData: LineTouchData(
          enabled: true,
          touchCallback: (FlTouchEvent event, LineTouchResponse? touchResponse) {
            if (event is FlPanUpdateEvent || event is FlTapDownEvent) {
              if (touchResponse?.lineBarSpots != null && touchResponse!.lineBarSpots!.isNotEmpty) {
                setState(() {
                  _touchedIndex = touchResponse.lineBarSpots!.first.spotIndex;
                });
              }
            } else if (event is FlPanEndEvent || event is FlTapUpEvent) {
              setState(() {
                _touchedIndex = null;
              });
            }
          },
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (touchedSpot) => colorScheme.surfaceContainerHighest,
            tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            tooltipRoundedRadius: 8,
            getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
              return touchedBarSpots.map((barSpot) {
                final index = barSpot.x.toInt();
                if (index >= 0 && index < widget.data.length) {
                  return LineTooltipItem(
                    '${widget.data[index].label}\n${widget.currency} ${barSpot.y.toStringAsFixed(2)}',
                    TextStyle(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  );
                }
                return null;
              }).toList();
            },
          ),
          getTouchedSpotIndicator: (LineChartBarData barData, List<int> spotIndexes) {
            return spotIndexes.map((spotIndex) {
              // Interpolar color del gradiente según posición del punto tocado
              final t = widget.data.length > 1 ? spotIndex / (widget.data.length - 1) : 0.0;
              final spotColor = Color.lerp(const Color(0xFF8A2BE2), const Color(0xFF00E3FF), t)!;

              return TouchedSpotIndicatorData(
                // Línea vertical delgada
                FlLine(
                  color: spotColor.withOpacity(0.5),
                  strokeWidth: 1.5,  // Línea más delgada
                  dashArray: [4, 4],  // Línea punteada
                ),
                FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, barData, index) {
                    return FlDotCirclePainter(
                      radius: 6,
                      color: spotColor,
                      strokeWidth: 3,
                      strokeColor: colorScheme.surface,
                    );
                  },
                ),
              );
            }).toList();
          },
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: (widget.maxY ?? _getMaxValue()) / 5,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: colorScheme.surfaceContainerHighest,
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 1,
              getTitlesWidget: (value, meta) {
                // Si hay mapeo x->label (ej: día del mes), úsalo
                final label = xLabelMap[value];
                if (label != null) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  );
                }
                // Fallback: usar índice si no hay x explícito
                final index = value.toInt();
                if (index >= 0 && index < widget.data.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      widget.data[index].label,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toStringAsFixed(0),
                  style: Theme.of(context).textTheme.bodySmall,
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: widget.xMax ?? (projectionSpots.isNotEmpty ? projectionSpots.first.x : (widget.data.length - 1).toDouble()),
        minY: 0,
        maxY: widget.maxY ?? _getMaxValue(),
        lineBarsData: [
          // Línea principal con datos históricos
          LineChartBarData(
            spots: spots,
            isCurved: true,
            gradient: lineGradient,  // Gradiente dinámico según progreso
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                // Interpolar color del gradiente según posición
                final t = widget.data.length > 1 ? index / (widget.data.length - 1) : 0.0;
                final dotColor = Color.lerp(const Color(0xFF8A2BE2), const Color(0xFF00E3FF), t)!;
                return FlDotCirclePainter(
                  radius: 4,
                  color: dotColor,
                  strokeWidth: 2,
                  strokeColor: colorScheme.surface,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: lineGradient.colors.map((c) => c.withOpacity(0.1)).toList(),
                stops: lineGradient.stops,
              ),
            ),
          ),
          // Línea de proyección (punteada desde último punto hasta proyección)
          if (projectionSpots.isNotEmpty)
            LineChartBarData(
              spots: [spots.last, projectionSpots.first],
              isCurved: false,
              color: Colors.orange.withOpacity(0.7),
              barWidth: 2,
              dashArray: [5, 5],
              dotData: FlDotData(
                show: true,
                checkToShowDot: (spot, barData) {
                  // Solo mostrar el punto final (proyección)
                  return spot == projectionSpots.first;
                },
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: 6,
                    color: Colors.orange,
                    strokeWidth: 3,
                    strokeColor: colorScheme.surface,
                  );
                },
              ),
              belowBarData: BarAreaData(show: false),
            ),
        ],
      ),
    );
  }

  Widget _buildBarChart(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (widget.data.isEmpty) {
      final l10n = AppLocalizations.of(context);
      return Center(
        child: Text(
          l10n?.chartNoDataAvailable ?? 'No data available',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
        ),
      );
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: widget.maxY ?? _getMaxValue(),
        barTouchData: BarTouchData(enabled: true),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < widget.data.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      widget.data[index].label,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toStringAsFixed(0),
                  style: Theme.of(context).textTheme.bodySmall,
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: widget.data.asMap().entries.map((entry) {
          return BarChartGroupData(
            x: entry.key,
            barRods: [
              BarChartRodData(
                toY: entry.value.value,
                color: entry.value.color ?? colorScheme.primary,
                width: 16,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
          );
        }).toList(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: (widget.maxY ?? _getMaxValue()) / 5,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: colorScheme.surfaceContainerHighest,
              strokeWidth: 1,
            );
          },
        ),
      ),
    );
  }

  Widget _buildPieChart(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (widget.data.isEmpty) {
      final l10n = AppLocalizations.of(context);
      return Center(
        child: Text(
          l10n?.chartNoDataAvailable ?? 'No data available',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
        ),
      );
    }

    return PieChart(
      PieChartData(
        sections: widget.data.asMap().entries.map((entry) {
          final index = entry.key;
          final dataPoint = entry.value;
          final total = widget.data.fold<double>(0, (sum, item) => sum + item.value);
          final percentage = (dataPoint.value / total * 100).toStringAsFixed(1);

          return PieChartSectionData(
            color: dataPoint.color ?? _getColorForIndex(index, colorScheme),
            value: dataPoint.value,
            title: '$percentage%',
            radius: 60,
            titleStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
          );
        }).toList(),
        sectionsSpace: 2,
        centerSpaceRadius: 40,
      ),
    );
  }

  double _getMaxValue() {
    if (widget.data.isEmpty) return 100;
    final max = widget.data.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    return max * 1.2; // 20% padding
  }

  Color _getColorForIndex(int index, ColorScheme colorScheme) {
    final colors = [
      colorScheme.primary,
      colorScheme.secondary,
      colorScheme.tertiary,
      Colors.orange,
      Colors.purple,
      Colors.teal,
    ];
    return colors[index % colors.length];
  }
}

/// Punto de datos para el gráfico
class ChartDataPoint {
  final String label;
  final double value;
  final Color? color;
  final double? x; // valor opcional para posicionar en eje X (e.g., día del mes)

  const ChartDataPoint({
    required this.label,
    required this.value,
    this.color,
    this.x,
  });
}

/// Tipos de gráficos soportados
enum ChartType {
  line,
  bar,
  pie,
}
