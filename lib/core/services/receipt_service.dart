import 'dart:io';
import 'api_service.dart';

/// Clase que maneja la lógica de negocio relacionada con los recibos.
/// Orquesta las operaciones utilizando otros servicios de más bajo nivel.
class ReceiptService {
  final ApiService _apiService;

  ReceiptService({required ApiService apiService}) : _apiService = apiService;

  /// Obtiene la lista de recibos desde la API.
  Future<List<dynamic>> getReceipts({
    String? category,
    String? merchant,
    DateTime? dateFrom,
    DateTime? dateTo,
    double? minAmount,
    double? maxAmount,
  }) {
    return _apiService.getReceipts(
      category: category,
      merchant: merchant,
      dateFrom: dateFrom,
      dateTo: dateTo,
      minAmount: minAmount,
      maxAmount: maxAmount,
    );
  }

  /// Proceso completo para crear un nuevo recibo.
  /// 1. Sube el archivo de la imagen.
  /// 2. Crea el registro del recibo con la URL de la imagen.
  Future<Map<String, dynamic>> createNewReceipt(File imageFile) async {
    try {
      // 1. Subir la imagen
      final imageUrl = await _apiService.uploadImage(imageFile);

      // 2. Crear el recibo con la URL obtenida
      final newReceipt = await _apiService.createReceipt(imageUrl);

      return newReceipt;
    } catch (e) {
      // Aquí se podría añadir un manejo de errores más específico si fuera necesario.
      print('Error en createNewReceipt: $e');
      rethrow;
    }
  }
}
