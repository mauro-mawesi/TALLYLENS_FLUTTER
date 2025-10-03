import 'dart:io';
import 'api_service.dart';
import 'package:image/image.dart' as img;
import 'package:recibos_flutter/core/services/receipts_cache.dart';
import 'package:recibos_flutter/core/models/page_result.dart';
import 'dart:convert';

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
  Future<Map<String, dynamic>> createNewReceipt(
    File imageFile, { bool processedByMLKit = false, String? source, bool? forceDuplicate }
  ) async {
    try {
      // 1. Preparar (comprimir/redimensionar) y subir la imagen
      final prepared = await _prepareImageForUpload(imageFile);
      final imageUrl = await _apiService.uploadImage(prepared);

      // 2. Crear el recibo con la URL obtenida
      final newReceipt = await _apiService.createReceipt(
        imageUrl,
        processedByMLKit: processedByMLKit,
        source: source,
        forceDuplicate: forceDuplicate,
      );

      return newReceipt;
    } catch (e) {
      // Aquí se podría añadir un manejo de errores más específico si fuera necesario.
      print('Error en createNewReceipt: $e');
      rethrow;
    }
  }

  /// Redimensiona y comprime la imagen antes de subir para reducir tamaño
  /// - Máximo de lado: 2000px
  /// - Calidad JPEG: 85
  /// Si ocurre algún error, devuelve el archivo original.
  Future<File> _prepareImageForUpload(File input) async {
    try {
      final bytes = await input.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return input;
      final int maxSide = 2000;
      img.Image processed = decoded;
      if (decoded.width > maxSide || decoded.height > maxSide) {
        final scale = decoded.width > decoded.height
            ? maxSide / decoded.width
            : maxSide / decoded.height;
        final newW = (decoded.width * scale).round();
        final newH = (decoded.height * scale).round();
        processed = img.copyResize(decoded, width: newW, height: newH, interpolation: img.Interpolation.average);
      }
      final jpg = img.encodeJpg(processed, quality: 85);
      final tempDir = Directory.systemTemp;
      final outPath = '${tempDir.path}/receipt_upload_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final outFile = File(outPath);
      await outFile.writeAsBytes(jpg, flush: true);
      return outFile;
    } catch (_) {
      return input;
    }
  }

  /// Paginación con cache (TTL 10 min). Si la API soporta page/limit, se usa; si no,
  /// igualmente cacheamos la lista completa y servimos páginas locales.
  Future<PageResult> getReceiptsPaged({
    String? category,
    String? merchant,
    DateTime? dateFrom,
    DateTime? dateTo,
    double? minAmount,
    double? maxAmount,
    required int page,
    int pageSize = 20,
  }) async {
    final key = _cacheKey(
      category: category,
      merchant: merchant,
      dateFrom: dateFrom,
      dateTo: dateTo,
      minAmount: minAmount,
      maxAmount: maxAmount,
    );

    // 1) Intentar usar caché solo para la primera página
    if (page == 1) {
      final cached = await ReceiptsCache.get(key, ttl: const Duration(minutes: 10));
      if (cached != null && cached.items.isNotEmpty) {
        final slice = _slice(cached.items, page, pageSize);
        final hasMore = page * pageSize < cached.items.length;
        return PageResult(items: slice, hasMore: hasMore, page: page, pageSize: pageSize, total: cached.total);
      }
    }

    // 2) Llamar API con hint de page/limit (el backend puede ignorarlo sin romper)
    final items = await _apiService.getReceipts(
      category: category,
      merchant: merchant,
      dateFrom: dateFrom,
      dateTo: dateTo,
      minAmount: minAmount,
      maxAmount: maxAmount,
      page: page,
      limit: pageSize,
    );
    // El backend devuelve una página (limit/offset): hasMore por longitud
    bool hasMore = items.length == pageSize;

    // 3) Cachear acumulado (para navegación fluida)
    // 3) Cachear solo la primera página para mejorar UX de pull-to-refresh
    try {
      if (page == 1) {
        await ReceiptsCache.put(key, ReceiptsCacheEntry(
          timestamp: DateTime.now(),
          items: items,
          total: items.length,
        ));
      }
    } catch (_) {}

    // Devolver directamente la página recibida
    return PageResult(items: items, hasMore: hasMore, page: page, pageSize: pageSize, total: null);
  }

  List<dynamic> _slice(List<dynamic> list, int page, int pageSize) {
    final start = (page - 1) * pageSize;
    if (start >= list.length) return const [];
    final end = (start + pageSize).clamp(0, list.length);
    return list.sublist(start, end);
  }

  String _cacheKey({
    String? category,
    String? merchant,
    DateTime? dateFrom,
    DateTime? dateTo,
    double? minAmount,
    double? maxAmount,
  }) {
    final map = {
      'category': category,
      'merchant': merchant,
      'dateFrom': dateFrom?.toIso8601String(),
      'dateTo': dateTo?.toIso8601String(),
      'minAmount': minAmount,
      'maxAmount': maxAmount,
    };
    return base64Url.encode(utf8.encode(json.encode(map)));
  }
}
