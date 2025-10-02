import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:recibos_flutter/core/config/app_config.dart';
import 'package:recibos_flutter/core/services/errors.dart';
import 'package:recibos_flutter/core/services/auth_bridge.dart';

/// Clase responsable de toda la comunicación directa con la API del backend.
class ApiService {
  String? _accessToken;
  String? _refreshToken;
  String _localeCode = 'en';
  bool _refreshing = false;
  Future<bool>? _refreshFuture;
  int _consecutiveRefreshFailures = 0;
  DateTime? _lastRefreshAttempt;
  DateTime? _refreshCooldownUntil;

  // Base URL configurable
  static const String _baseUrl = baseApiUrl;

  void setAccessToken(String? token) { _accessToken = token; }
  void setRefreshToken(String? token) { _refreshToken = token; }
  void setTokens({String? access, String? refresh}) { _accessToken = access; _refreshToken = refresh; }
  void setLocaleCode(String? code) { if (code != null && code.isNotEmpty) _localeCode = code; }

  Map<String, String> _headers({Map<String, String>? extra}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (_accessToken != null && _accessToken!.isNotEmpty)
        'Authorization': 'Bearer $_accessToken',
      // Sincroniza idioma con backend
      'X-Locale': _localeCode,
    };
    if (extra != null) headers.addAll(extra);
    return headers;
  }

  // _localeCode se gestiona externamente a través de setLocaleCode

  /// Obtiene la lista de todos los recibos.
  Future<http.Response> _authorized(Future<http.Response> Function() doRequest) async {
    http.Response resp = await doRequest();
    if (resp.statusCode == 401 && _refreshToken != null && _refreshToken!.isNotEmpty) {
      final ok = await _refresh();
      if (ok) {
        resp = await doRequest();
      }
    }
    if (resp.statusCode == 401) {
      // Notificamos globalmente y dejamos que el router redirija
      final cb = AuthBridge.onUnauthorized;
      if (cb != null) {
        await cb();
      }
    }
    return resp;
  }

  Future<bool> _refresh() async {
    final now = DateTime.now().toUtc();
    if (_refreshCooldownUntil != null && now.isBefore(_refreshCooldownUntil!)) {
      return false;
    }
    if (_refreshing && _refreshFuture != null) {
      return await _refreshFuture!;
    }
    Future<bool> doRefresh() async {
      _lastRefreshAttempt = DateTime.now().toUtc();
      final r = await http.post(
        Uri.parse("$_baseUrl/auth/refresh"),
        headers: _headers(),
        body: json.encode({'refreshToken': _refreshToken}),
      );
      if (r.statusCode == 200) {
        final data = json.decode(r.body);
        final tokens = data['data']?['tokens'];
        final newAccess = tokens?['accessToken'] as String?;
        final newRefresh = tokens?['refreshToken'] as String?;
        if (newAccess != null && newAccess.isNotEmpty) {
          setAccessToken(newAccess);
          if (newRefresh != null && newRefresh.isNotEmpty) {
            setRefreshToken(newRefresh);
          }
          final onUpd = AuthBridge.onTokensUpdated;
          if (onUpd != null) {
            await onUpd(newAccess, newRefresh);
          }
          _consecutiveRefreshFailures = 0;
          _refreshCooldownUntil = null;
          return true;
        }
      }
      // Non-200 or missing tokens: set cooldown/backoff
      _consecutiveRefreshFailures += 1;
      Duration backoff;
      if (r.statusCode == 429) {
        // Rate limited: exponential backoff starting at 30s
        backoff = Duration(seconds: 30 * (1 << (_consecutiveRefreshFailures - 1)).clamp(1, 8));
      } else {
        // Other errors: modest backoff to avoid spamming
        backoff = Duration(seconds: 5 * (1 << (_consecutiveRefreshFailures - 1)).clamp(1, 6));
      }
      _refreshCooldownUntil = DateTime.now().toUtc().add(backoff);
      return false;
    }
    try {
      _refreshing = true;
      _refreshFuture = doRefresh();
      return await _refreshFuture!;
    } finally {
      _refreshing = false;
      _refreshFuture = null;
    }
  }

  /// Exposes a public way to refresh tokens proactively.
  /// Returns true if tokens were refreshed successfully.
  Future<bool> refreshNow() => _refresh();

  DateTime? get refreshCooldownUntil => _refreshCooldownUntil;

  Future<List<dynamic>> getReceipts({
    String? category,
    String? merchant,
    DateTime? dateFrom,
    DateTime? dateTo,
    double? minAmount,
    double? maxAmount,
  }) async {
    final qp = <String, String>{
      if (category != null && category.isNotEmpty) 'category': category,
      if (merchant != null && merchant.isNotEmpty) 'merchant': merchant,
      if (dateFrom != null) 'dateFrom': dateFrom.toUtc().toIso8601String(),
      if (dateTo != null) 'dateTo': dateTo.toUtc().toIso8601String(),
      if (minAmount != null) 'minAmount': minAmount.toString(),
      if (maxAmount != null) 'maxAmount': maxAmount.toString(),
    };
    final uri = Uri.parse("$_baseUrl/receipts").replace(queryParameters: qp.isEmpty ? null : qp);
    final response = await _authorized(() => http.get(
      uri,
      headers: _headers(),
    ));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      // Backend responde { status, data: { receipts, total, ... } }
      final list = (data["data"]?["receipts"]) as List<dynamic>?;
      if (list == null) {
        throw Exception("Formato inesperado en /receipts");
      }
      return list;
    }
    if (response.statusCode == 401) throw UnauthorizedException('Sesión expirada');
    throw Exception("Error al obtener recibos: ${response.statusCode}");
  }

  // Receipt detail and items
  Future<Map<String, dynamic>> getReceiptById(String id) async {
    final response = await _authorized(() => http.get(
          Uri.parse("$_baseUrl/receipts/$id"),
          headers: _headers(),
        ));
    if (response.statusCode == 200) {
      return json.decode(response.body)['data'] as Map<String, dynamic>;
    }
    if (response.statusCode == 401) throw UnauthorizedException('Sesión expirada');
    throw Exception('Error al obtener recibo: ${response.statusCode}');
  }

  Future<Map<String, dynamic>> updateReceipt({
    required String id,
    String? merchantName,
    String? category,
    String? notes,
    double? amount,
    DateTime? purchaseDate,
  }) async {
    final payload = <String, dynamic>{
      if (merchantName != null) 'merchantName': merchantName,
      if (category != null) 'category': category,
      if (notes != null) 'notes': notes,
      if (amount != null) 'amount': amount,
      if (purchaseDate != null) 'purchaseDate': purchaseDate.toUtc().toIso8601String(),
    };
    final response = await _authorized(() => http.patch(
          Uri.parse("$_baseUrl/receipts/$id"),
          headers: _headers(),
          body: json.encode(payload),
        ));
    if (response.statusCode == 200) {
      return json.decode(response.body)['data'] as Map<String, dynamic>;
    }
    if (response.statusCode == 401) throw UnauthorizedException('Sesión expirada');
    throw Exception('Error al actualizar recibo: ${response.body}');
  }

  Future<List<dynamic>> getReceiptItems(String id) async {
    final response = await _authorized(() => http.get(
          Uri.parse("$_baseUrl/receipts/$id/items"),
          headers: _headers(),
        ));
    if (response.statusCode == 200) {
      return (json.decode(response.body)['data'] as List<dynamic>);
    }
    if (response.statusCode == 401) throw UnauthorizedException('Sesión expirada');
    throw Exception('Error al obtener items: ${response.statusCode}');
  }

  Future<Map<String, dynamic>> updateReceiptItem({
    required String receiptId,
    required String itemId,
    double? quantity,
    double? unitPrice,
    bool? isVerified,
  }) async {
    final payload = <String, dynamic>{
      if (quantity != null) 'quantity': quantity,
      if (unitPrice != null) 'unitPrice': unitPrice,
      if (isVerified != null) 'isVerified': isVerified,
    };
    final response = await _authorized(() => http.patch(
          Uri.parse("$_baseUrl/receipts/$receiptId/items/$itemId"),
          headers: _headers(),
          body: json.encode(payload),
        ));
    if (response.statusCode == 200) {
      return json.decode(response.body)['data'] as Map<String, dynamic>;
    }
    if (response.statusCode == 401) throw UnauthorizedException('Sesión expirada');
    throw Exception('Error al actualizar item: ${response.body}');
  }

  /// Crea un nuevo registro de recibo a partir de una URL de imagen.
  /// Opcionalmente puede indicar si la imagen ya fue procesada por ML Kit y su origen.
  Future<Map<String, dynamic>> createReceipt(
    String imageUrl, { bool? processedByMLKit, String? source }
  ) async {
    final payload = <String, dynamic>{
      "imageUrl": imageUrl,
      if (processedByMLKit != null) "processedByMLKit": processedByMLKit,
      if (source != null) "source": source,
    };
    final response = await _authorized(() => http.post(
      Uri.parse("$_baseUrl/receipts"),
      headers: _headers(),
      body: json.encode(payload),
    ));

    if (response.statusCode == 201) {
      return json.decode(response.body);
    }
    if (response.statusCode == 401) throw UnauthorizedException('Sesión expirada');
    throw Exception("Error al crear recibo: ${response.body}");
  }

  /// Sube un archivo de imagen y devuelve la URL pública.
  Future<String> uploadImage(File imageFile) async {
    final uri = Uri.parse("$_baseUrl/upload");
    Future<http.StreamedResponse> send() async {
      final req = http.MultipartRequest("POST", uri)
        ..files.add(await http.MultipartFile.fromPath("file", imageFile.path));
      if (_accessToken != null && _accessToken!.isNotEmpty) {
        req.headers['Authorization'] = 'Bearer $_accessToken';
      }
      return req.send();
    }

    var response = await send();
    if (response.statusCode == 401 && await _refresh()) {
      response = await send();
    }
    if (response.statusCode == 401) {
      final cb = AuthBridge.onUnauthorized;
      if (cb != null) await cb();
      throw UnauthorizedException('Sesión expirada');
    }
    final body = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      final data = json.decode(body);
      return data["image_url"] as String;
    } else {
      throw Exception("Error en la subida de imagen: ${response.statusCode} - $body");
    }
  }

  // --- Auth endpoints (opcional) ---
  Future<Map<String, dynamic>> login({String? email, String? username, required String password}) async {
    final payload = {
      if (email != null) 'email': email,
      if (username != null) 'username': username,
      'password': password,
    };
    final resp = await http.post(
      Uri.parse("$_baseUrl/auth/login"),
      headers: _headers(),
      body: json.encode(payload),
    );
    if (resp.statusCode == 200) {
      final data = json.decode(resp.body);
      final tokens = data['data']?['tokens'];
      if (tokens != null) {
        setTokens(access: tokens['accessToken'] as String?, refresh: tokens['refreshToken'] as String?);
      }
      return data;
    }
    throw Exception('Login failed: ${resp.body}');
  }

  Future<Map<String, dynamic>> register({
    required String email,
    required String username,
    required String password,
    String? firstName,
    String? lastName,
  }) async {
    final payload = {
      'email': email,
      'username': username,
      'password': password,
      if (firstName != null && firstName.isNotEmpty) 'firstName': firstName,
      if (lastName != null && lastName.isNotEmpty) 'lastName': lastName,
    };
    final resp = await http.post(
      Uri.parse("$_baseUrl/auth/register"),
      headers: _headers(),
      body: json.encode(payload),
    );
    if (resp.statusCode == 201) {
      final data = json.decode(resp.body);
      final tokens = data['data']?['tokens'];
      if (tokens != null) {
        setTokens(access: tokens['accessToken'] as String?, refresh: tokens['refreshToken'] as String?);
      }
      return data;
    }
    throw Exception('Register failed: ${resp.body}');
  }

  Future<Map<String, dynamic>> getMeRaw() async {
    final resp = await _authorized(() => http.get(
          Uri.parse("$_baseUrl/auth/me"),
          headers: _headers(),
        ));
    if (resp.statusCode == 200) {
      return json.decode(resp.body)['data'] as Map<String, dynamic>;
    }
    if (resp.statusCode == 401) throw UnauthorizedException('Sesión expirada');
    throw Exception('Error perfil: ${resp.statusCode}');
  }

  Future<Map<String, dynamic>> getReceiptImageInfo(String receiptId) async {
    final response = await _authorized(() => http.get(
          Uri.parse("$_baseUrl/images/receipt/$receiptId/info"),
          headers: _headers(),
        ));
    if (response.statusCode == 200) {
      return json.decode(response.body)['data'] as Map<String, dynamic>;
    }
    if (response.statusCode == 401) throw UnauthorizedException('Sesión expirada');
    throw Exception('Error imagen info: ${response.statusCode}');
  }

  // --- Analytics endpoints ---
  Future<Map<String, dynamic>> getSmartAlerts() async {
    final response = await _authorized(() => http.get(
          Uri.parse("$_baseUrl/analytics/smart-alerts"),
          headers: _headers(),
        ));
    if (response.statusCode == 200) {
      return json.decode(response.body)['data'] as Map<String, dynamic>;
    }
    if (response.statusCode == 401) throw UnauthorizedException('Sesión expirada');
    throw Exception('Error smart alerts: ${response.statusCode}');
  }

  Future<Map<String, dynamic>> getSpendingAnalysis({int months = 6}) async {
    final response = await _authorized(() => http.get(
          Uri.parse("$_baseUrl/analytics/spending-analysis?months=$months"),
          headers: _headers(),
        ));
    if (response.statusCode == 200) {
      return json.decode(response.body)['data'] as Map<String, dynamic>;
    }
    if (response.statusCode == 401) throw UnauthorizedException('Sesión expirada');
    throw Exception('Error spending analysis: ${response.statusCode}');
  }

  // --- Product analytics ---
  Future<Map<String, dynamic>> getProductMonthlyStats(String productId, {int months = 12}) async {
    final response = await _authorized(() => http.get(
          Uri.parse("$_baseUrl/analytics/products/$productId/monthly-stats?months=$months"),
          headers: _headers(),
        ));
    if (response.statusCode == 200) {
      return json.decode(response.body)['data'] as Map<String, dynamic>;
    }
    if (response.statusCode == 401) throw UnauthorizedException('Sesión expirada');
    throw Exception('Error product monthly stats: ${response.statusCode}');
  }

  Future<Map<String, dynamic>> getProductPriceComparison(String productId, {int days = 90}) async {
    final response = await _authorized(() => http.get(
          Uri.parse("$_baseUrl/analytics/products/$productId/price-comparison?days=$days"),
          headers: _headers(),
        ));
    if (response.statusCode == 200) {
      return json.decode(response.body)['data'] as Map<String, dynamic>;
    }
    if (response.statusCode == 401) throw UnauthorizedException('Sesión expirada');
    throw Exception('Error product price comparison: ${response.statusCode}');
  }

  Future<Map<String, dynamic>> getProductFrequencyAnalysis(String productId) async {
    final response = await _authorized(() => http.get(
          Uri.parse("$_baseUrl/analytics/products/$productId/frequency-analysis"),
          headers: _headers(),
        ));
    if (response.statusCode == 200) {
      return json.decode(response.body)['data'] as Map<String, dynamic>;
    }
    if (response.statusCode == 401) throw UnauthorizedException('Sesión expirada');
    throw Exception('Error product frequency: ${response.statusCode}');
  }
}
