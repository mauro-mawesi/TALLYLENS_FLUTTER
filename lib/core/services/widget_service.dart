import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import 'package:recibos_flutter/core/services/api_service.dart';

/// Servicio para gestionar widgets de iOS y Android
class WidgetService {
  final ApiService _api;

  WidgetService({required ApiService api}) : _api = api;

  /// Actualiza todos los widgets con los datos más recientes
  Future<void> updateWidgets() async {
    try {
      // Obtener estadísticas del mes actual
      final stats = await _api.getReceiptStats(days: 30);

      // Datos para el widget
      final monthlyTotal = stats['monthlyTotal'] ?? 0.0;
      final receiptCount = stats['totalReceipts'] ?? 0;
      final currency = stats['currency'] ?? 'USD';
      final lastReceipt = stats['lastReceipt'] as Map<String, dynamic>?;

      // Guardar datos en el storage compartido
      await HomeWidget.saveWidgetData<String>('monthly_total', _formatAmount(monthlyTotal));
      await HomeWidget.saveWidgetData<String>('currency', currency);
      await HomeWidget.saveWidgetData<int>('receipt_count', receiptCount);
      await HomeWidget.saveWidgetData<String>('last_updated', DateTime.now().toIso8601String());

      if (lastReceipt != null) {
        await HomeWidget.saveWidgetData<String>('last_merchant', lastReceipt['merchantName'] ?? 'Unknown');
        await HomeWidget.saveWidgetData<String>('last_amount', _formatAmount(lastReceipt['amount'] ?? 0.0));
        await HomeWidget.saveWidgetData<String>('last_date', _formatDate(lastReceipt['purchaseDate']));
      }

      // Actualizar widgets en ambas plataformas
      await HomeWidget.updateWidget(
        name: 'ReceiptsWidget',
        iOSName: 'ReceiptsWidget',
        androidName: 'ReceiptsWidgetProvider',
      );
    } catch (e) {
      // Ignorar errores silenciosamente (widget puede estar desinstalado)
    }
  }

  /// Registra callbacks para acciones del widget
  void registerCallbacks() {
    HomeWidget.setAppGroupId('group.com.recibos.app');

    // Callback cuando se toca el widget
    HomeWidget.widgetClicked.listen((uri) {
      if (uri != null) {
        _handleWidgetAction(uri);
      }
    });
  }

  /// Maneja las acciones del widget
  void _handleWidgetAction(Uri uri) {
    // Las acciones se manejarán desde main.dart usando GoRouter
    // Este método es un placeholder para futuras extensiones
  }

  String _formatAmount(dynamic amount) {
    final value = double.tryParse(amount.toString()) ?? 0.0;
    final formatter = NumberFormat.currency(symbol: '', decimalDigits: 2);
    return formatter.format(value);
  }

  String _formatDate(dynamic date) {
    if (date == null) return '';
    try {
      final dateTime = DateTime.parse(date.toString());
      return DateFormat('MMM dd').format(dateTime);
    } catch (_) {
      return '';
    }
  }
}
