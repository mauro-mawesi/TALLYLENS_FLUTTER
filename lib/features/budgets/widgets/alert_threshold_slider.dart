import 'package:flutter/material.dart';

/// Widget interactivo para configurar umbrales de alerta de presupuesto.
/// Permite seleccionar múltiples umbrales entre 0 y 200%.
class AlertThresholdSlider extends StatefulWidget {
  final List<int> initialThresholds;
  final ValueChanged<List<int>> onChanged;
  final int minThreshold;
  final int maxThreshold;

  const AlertThresholdSlider({
    super.key,
    required this.initialThresholds,
    required this.onChanged,
    this.minThreshold = 50,
    this.maxThreshold = 200,
  });

  @override
  State<AlertThresholdSlider> createState() => _AlertThresholdSliderState();
}

class _AlertThresholdSliderState extends State<AlertThresholdSlider> {
  late List<int> _thresholds;

  @override
  void initState() {
    super.initState();
    _thresholds = List.from(widget.initialThresholds);
    _thresholds.sort();
  }

  @override
  void didUpdateWidget(AlertThresholdSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialThresholds != widget.initialThresholds) {
      setState(() {
        _thresholds = List.from(widget.initialThresholds);
        _thresholds.sort();
      });
    }
  }

  void _addThreshold(int value) {
    if (!_thresholds.contains(value)) {
      setState(() {
        _thresholds.add(value);
        _thresholds.sort();
      });
      widget.onChanged(_thresholds);
    }
  }

  void _removeThreshold(int value) {
    setState(() {
      _thresholds.remove(value);
    });
    widget.onChanged(_thresholds);
  }

  void _showAddThresholdDialog() {
    int selectedValue = 80;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Alert Threshold'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Alert at ${selectedValue}% of budget',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  Slider(
                    value: selectedValue.toDouble(),
                    min: widget.minThreshold.toDouble(),
                    max: widget.maxThreshold.toDouble(),
                    divisions: (widget.maxThreshold - widget.minThreshold) ~/ 5,
                    label: '$selectedValue%',
                    onChanged: (value) {
                      setDialogState(() {
                        selectedValue = value.round();
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    _addThreshold(selectedValue);
                    Navigator.pop(context);
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Alert Thresholds',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: _showAddThresholdDialog,
                  tooltip: 'Add threshold',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Get notified when your spending reaches these percentages',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),

            // Visual representation
            if (_thresholds.isNotEmpty) ...[
              SizedBox(
                height: 60,
                child: CustomPaint(
                  painter: _ThresholdPainter(
                    thresholds: _thresholds,
                    colorScheme: colorScheme,
                  ),
                  child: const SizedBox(width: double.infinity),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Threshold chips
            if (_thresholds.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Icon(
                        Icons.notifications_off_outlined,
                        size: 48,
                        color: colorScheme.onSurfaceVariant.withOpacity(0.5),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No thresholds configured',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap + to add an alert threshold',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _thresholds.map((threshold) {
                  return Chip(
                    label: Text('$threshold%'),
                    deleteIcon: const Icon(Icons.close, size: 18),
                    onDeleted: () => _removeThreshold(threshold),
                    backgroundColor: _getColorForThreshold(threshold, colorScheme).withOpacity(0.1),
                    labelStyle: TextStyle(
                      color: _getColorForThreshold(threshold, colorScheme),
                      fontWeight: FontWeight.w600,
                    ),
                  );
                }).toList(),
              ),

            const SizedBox(height: 8),

            // Suggested thresholds
            if (_thresholds.isEmpty || _thresholds.length < 3) ...[
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'Suggested thresholds:',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [50, 75, 90, 100].where((t) => !_thresholds.contains(t)).map((threshold) {
                  return ActionChip(
                    label: Text('$threshold%'),
                    onPressed: () => _addThreshold(threshold),
                    avatar: const Icon(Icons.add, size: 16),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getColorForThreshold(int threshold, ColorScheme colorScheme) {
    if (threshold < 70) {
      return colorScheme.primary;
    } else if (threshold < 90) {
      return Colors.amber;
    } else if (threshold <= 100) {
      return Colors.orange;
    } else {
      return colorScheme.error;
    }
  }
}

/// Custom painter para visualizar los umbrales en una línea
class _ThresholdPainter extends CustomPainter {
  final List<int> thresholds;
  final ColorScheme colorScheme;

  _ThresholdPainter({
    required this.thresholds,
    required this.colorScheme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill;

    // Dibujar línea base
    final basePaint = Paint()
      ..color = colorScheme.surfaceContainerHighest
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, size.height / 2 - 4, size.width, 8),
        const Radius.circular(4),
      ),
      basePaint,
    );

    // Dibujar marcadores de umbrales
    for (final threshold in thresholds) {
      final x = (threshold / 100) * size.width;

      // Color según el threshold
      Color color;
      if (threshold < 70) {
        color = colorScheme.primary;
      } else if (threshold < 90) {
        color = Colors.amber;
      } else if (threshold <= 100) {
        color = Colors.orange;
      } else {
        color = colorScheme.error;
      }

      paint.color = color;

      // Dibujar línea vertical
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - 2, 0, 4, size.height),
          const Radius.circular(2),
        ),
        paint,
      );

      // Dibujar círculo en la parte superior
      canvas.drawCircle(
        Offset(x, size.height / 2),
        8,
        paint,
      );

      // Dibujar borde blanco
      paint.color = Colors.white;
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = 2;
      canvas.drawCircle(
        Offset(x, size.height / 2),
        8,
        paint,
      );
      paint.style = PaintingStyle.fill;
    }
  }

  @override
  bool shouldRepaint(_ThresholdPainter oldDelegate) {
    return oldDelegate.thresholds != thresholds;
  }
}
