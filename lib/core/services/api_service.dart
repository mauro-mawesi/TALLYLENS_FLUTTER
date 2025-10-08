import 'dart:io';
// http replaced by Dio for all requests
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:recibos_flutter/core/config/app_config.dart';
import 'package:recibos_flutter/core/services/errors.dart';
import 'package:recibos_flutter/core/services/auth_bridge.dart';
import 'package:recibos_flutter/core/models/budget.dart';

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

  late final Dio _dio;

  // Request deduplication cache to prevent duplicate concurrent requests
  final Map<String, Future<Response<dynamic>>> _pendingRequests = {};

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_accessToken != null && _accessToken!.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $_accessToken';
        }
        options.headers['X-Locale'] = _localeCode;
        handler.next(options);
      },
      onError: (err, handler) async {
        // Evitar ciclo con el endpoint de refresh
        final isRefresh = err.requestOptions.path.endsWith('/auth/refresh');
        if (err.response?.statusCode == 401 && !isRefresh && _refreshToken != null && _refreshToken!.isNotEmpty) {
          final ok = await _refresh();
          if (ok) {
            try {
              final res = await _dio.fetch(err.requestOptions);
              return handler.resolve(res);
            } catch (_) {}
          } else {
            // Distinguir entre refresh token inválido vs errores transitorios
            final statusCode = err.response?.statusCode;

            // Solo llamar onRefreshFailed si es definitivamente un token inválido
            // (400 Bad Request o 401 Unauthorized en el propio refresh)
            if (statusCode == 400 || statusCode == 401) {
              final cb = AuthBridge.onRefreshFailed;
              if (cb != null) await cb();
            }
            // Para errores 5xx o de red, NO cerrar sesión
            // El usuario puede reintentar la operación manualmente
          }
        }
        handler.next(err);
      },
    ));
    // Logging de red (solo en no-release), sin cuerpos ni headers sensibles
    if (!kReleaseMode) {
      _dio.interceptors.add(LogInterceptor(
        request: true,
        requestHeader: false,
        requestBody: false,
        responseHeader: false,
        responseBody: false,
      ));
    }
  }

  /// Generate a unique key for request deduplication
  String _getRequestKey(String method, String path, [Map<String, dynamic>? queryParams]) {
    final query = queryParams?.entries.map((e) => '${e.key}=${e.value}').join('&') ?? '';
    return '$method:$path${query.isNotEmpty ? "?$query" : ""}';
  }

  /// Execute request with deduplication to prevent concurrent duplicate calls
  Future<Response<dynamic>> _request(
    Future<Response<dynamic>> Function() fn, {
    String? method,
    String? path,
    Map<String, dynamic>? queryParams,
    bool skipDeduplication = false,
  }) async {
    // Skip deduplication for POST/PUT/DELETE (mutation operations)
    if (skipDeduplication || method == 'POST' || method == 'PUT' || method == 'DELETE' || method == 'PATCH') {
      try {
        return await fn();
      } on DioException catch (e) {
        final code = e.response?.statusCode;
        if (code == 401) {
          final cb = AuthBridge.onUnauthorized;
          if (cb != null) await cb();
          throw UnauthorizedException('Sesión expirada');
        }
        throw Exception(e.message);
      }
    }

    // For GET requests, use deduplication
    final key = _getRequestKey(method ?? 'GET', path ?? '', queryParams);

    // If there's already a pending request for this key, return it
    if (_pendingRequests.containsKey(key)) {
      debugPrint('⚡ Deduplicating request: $key');
      return _pendingRequests[key]!;
    }

    // Create and cache the request
    final requestFuture = _executeRequest(fn, key);
    _pendingRequests[key] = requestFuture;

    return requestFuture;
  }

  Future<Response<dynamic>> _executeRequest(
    Future<Response<dynamic>> Function() fn,
    String key,
  ) async {
    try {
      final response = await fn();
      return response;
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 401) {
        final cb = AuthBridge.onUnauthorized;
        if (cb != null) await cb();
        throw UnauthorizedException('Sesión expirada');
      }
      throw Exception(e.message);
    } finally {
      // Remove from cache when done (success or error)
      _pendingRequests.remove(key);
    }
  }

  void setAccessToken(String? token) { _accessToken = token; }
  void setRefreshToken(String? token) { _refreshToken = token; }
  void setTokens({String? access, String? refresh}) { _accessToken = access; _refreshToken = refresh; }
  void setLocaleCode(String? code) { if (code != null && code.isNotEmpty) _localeCode = code; }

  // Expose Dio instance for services that need direct access
  Dio get dio => _dio;

  Map<String, String> _headers({Map<String, String>? extra}) {
    // Conservado por compatibilidad en _refresh anterior; el resto usa interceptores.
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (_accessToken != null && _accessToken!.isNotEmpty)
        'Authorization': 'Bearer $_accessToken',
      'X-Locale': _localeCode,
    };
    if (extra != null) headers.addAll(extra);
    return headers;
  }

  // _localeCode se gestiona externamente a través de setLocaleCode

  // Todas las llamadas pasan por Dio + interceptor; _authorized ya no es necesario.

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
      Response r;
      try {
        r = await _dio.post('/auth/refresh',
            data: {'refreshToken': _refreshToken},
            options: Options(validateStatus: (code) => true));
      } on DioException {
        // Error de red (timeout, conexión, etc.): aplicar backoff exponencial pero NO cerrar sesión
        // El refresh token sigue siendo válido, solo hay problemas de conectividad
        _consecutiveRefreshFailures += 1;
        // Backoff más generoso para errores de red: 10s, 20s, 40s, 60s max
        final backoff = Duration(seconds: 10 * (1 << (_consecutiveRefreshFailures - 1)).clamp(1, 6));
        _refreshCooldownUntil = DateTime.now().toUtc().add(backoff);
        // NO llamar onRefreshFailed para errores de red
        return false;
      }
      if (r.statusCode == 200) {
        final data = r.data;
        final tokens = data['data']?['tokens'];
        final newAccess = tokens?['accessToken'] as String?;
        final newRefresh = tokens?['refreshToken'] as String?;

        if (kDebugMode) {
          print('[ApiService] Refresh successful - Access: ${newAccess?.substring(0, 10)}..., Refresh: ${newRefresh?.substring(0, 10)}...');
        }

        if (newAccess != null && newAccess.isNotEmpty) {
          // IMPORTANTE: Persistir tokens ANTES de actualizar estado local
          // para evitar race conditions
          final onUpd = AuthBridge.onTokensUpdated;
          if (onUpd != null) {
            await onUpd(newAccess, newRefresh);
            if (kDebugMode) {
              print('[ApiService] Tokens persisted to secure storage');
            }
          }

          // Ahora actualizar estado local
          setAccessToken(newAccess);
          if (newRefresh != null && newRefresh.isNotEmpty) {
            setRefreshToken(newRefresh);
          }

          _consecutiveRefreshFailures = 0;
          _refreshCooldownUntil = null;

          if (kDebugMode) {
            print('[ApiService] Refresh complete - failures reset');
          }
          return true;
        } else {
          if (kDebugMode) {
            print('[ApiService] Refresh response missing tokens');
          }
        }
      }
      // Non-200 or missing tokens: set cooldown/backoff
      _consecutiveRefreshFailures += 1;
      Duration backoff;

      if (kDebugMode) {
        print('[ApiService] Refresh failed - Status: ${r.statusCode}, Failures: $_consecutiveRefreshFailures');
        print('[ApiService] Response: ${r.data}');
      }

      if (r.statusCode == 429) {
        backoff = Duration(seconds: 30 * (1 << (_consecutiveRefreshFailures - 1)).clamp(1, 8));
      } else if (r.statusCode == 401 || r.statusCode == 400) {
        // Refresh token definitivamente inválido: backoff corto antes de logout
        backoff = const Duration(seconds: 2);
        if (kDebugMode) {
          print('[ApiService] Refresh token invalid - will trigger logout');
        }
      } else {
        // Error 5xx o de red: backoff exponencial para reintentos
        backoff = Duration(seconds: 10 * (1 << (_consecutiveRefreshFailures - 1)).clamp(1, 6));
      }
      _refreshCooldownUntil = DateTime.now().toUtc().add(backoff);

      // Solo disparar política de logout si el refresh token es definitivamente inválido (400/401)
      // NO para errores 5xx del servidor o problemas de red
      if (r.statusCode == 401 || r.statusCode == 400) {
        final cb = AuthBridge.onRefreshFailed;
        if (cb != null) await cb();
      }
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
    int? page,
    int? limit,
  }) async {
    int? offset;
    if (page != null && limit != null) {
      offset = ((page - 1) * limit).clamp(0, 1 << 31);
    }
    final qp = <String, String>{
      if (category != null && category.isNotEmpty) 'category': category,
      if (merchant != null && merchant.isNotEmpty) 'merchant': merchant,
      if (dateFrom != null) 'dateFrom': dateFrom.toUtc().toIso8601String(),
      if (dateTo != null) 'dateTo': dateTo.toUtc().toIso8601String(),
      if (minAmount != null) 'minAmount': minAmount.toString(),
      if (maxAmount != null) 'maxAmount': maxAmount.toString(),
      if (limit != null) 'limit': limit.toString(),
      if (offset != null) 'offset': offset.toString(),
    };
    final response = await _request(() => _dio.get('/receipts', queryParameters: qp.isEmpty ? null : qp));
    if (response.statusCode == 200) {
      final data = response.data;
      // Backend responde { status, data: { receipts, total, ... } }
      final list = (data["data"]?["receipts"]) as List<dynamic>?;
      if (list == null) {
        throw Exception("Formato inesperado en /receipts");
      }
      return list;
    }
    throw Exception("Error al obtener recibos: ${response.statusCode}");
  }

  // Receipt detail and items
  Future<Map<String, dynamic>> getReceiptById(String id) async {
    final response = await _request(() => _dio.get('/receipts/$id'));
    if (response.statusCode == 200) {
      return response.data['data'] as Map<String, dynamic>;
    }
    if (response.statusCode == 404) {
      throw NotFoundException('Receipt not found');
    }
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
    final response = await _request(() => _dio.patch('/receipts/$id', data: payload));
    if (response.statusCode == 200) {
      return response.data['data'] as Map<String, dynamic>;
    }
    throw Exception('Error al actualizar recibo: ${response.data}');
  }

  Future<List<dynamic>> getReceiptItems(String id) async {
    final response = await _request(() => _dio.get('/receipts/$id/items'));
    if (response.statusCode == 200) {
      return (response.data['data'] as List<dynamic>);
    }
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
    final response = await _request(() => _dio.patch('/receipts/$receiptId/items/$itemId', data: payload));
    if (response.statusCode == 200) {
      return response.data['data'] as Map<String, dynamic>;
    }
    throw Exception('Error al actualizar item: ${response.data}');
  }

  /// Crea un nuevo registro de recibo a partir de una URL de imagen.
  /// Opcionalmente puede indicar si la imagen ya fue procesada por ML Kit y su origen.
  Future<Map<String, dynamic>> createReceipt(
    String imageUrl, { bool? processedByMLKit, String? source, bool? forceDuplicate }
  ) async {
    final payload = <String, dynamic>{
      "imageUrl": imageUrl,
      if (processedByMLKit != null) "processedByMLKit": processedByMLKit,
      if (source != null) "source": source,
      if (forceDuplicate != null) "forceDuplicate": forceDuplicate,
    };
    try {
      final response = await _dio.post('/receipts', data: payload);
      if (response.statusCode == 201) {
        return response.data;
      }
      throw Exception("Error al crear recibo: ${response.statusCode}");
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 409) {
        final data = e.response?.data;
        String message = 'Duplicate receipt';
        String? duplicateType;
        Map<String, dynamic>? existingReceipt;
        if (data is Map) {
          final msg = data['message'];
          if (msg is String) message = msg;
          final inner = data['data'];
          if (inner is Map) {
            final dt = inner['duplicateType'];
            if (dt is String) duplicateType = dt;
            final er = inner['existingReceipt'];
            if (er is Map) {
              existingReceipt = er.cast<String, dynamic>();
            }
          }
        }
        throw DuplicateReceiptException(
          message: message,
          duplicateType: duplicateType,
          existingReceipt: existingReceipt,
        );
      }
      if (code == 401) {
        final cb = AuthBridge.onUnauthorized;
        if (cb != null) await cb();
        throw UnauthorizedException('Sesión expirada');
      }
      throw Exception(e.message);
    }
  }

  /// Sube un archivo de imagen y devuelve la URL pública.
  Future<String> uploadImage(File imageFile) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(imageFile.path),
    });
    final resp = await _request(() => _dio.post('/upload', data: form));
    if (resp.statusCode == 200) {
      return (resp.data['image_url'] as String);
    }
    if (resp.statusCode == 401) throw UnauthorizedException('Sesión expirada');
    throw Exception('Error en la subida de imagen: ${resp.statusCode}');
  }

  /// Upload image and return full response (including imageUrl)
  Future<Map<String, dynamic>> uploadImageWithResponse(File imageFile) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(imageFile.path),
    });
    final resp = await _request(() => _dio.post('/upload', data: form));
    if (resp.statusCode == 200) {
      return resp.data as Map<String, dynamic>;
    }
    if (resp.statusCode == 401) throw UnauthorizedException('Sesión expirada');
    throw Exception('Error en la subida de imagen: ${resp.statusCode}');
  }

  /// Upload profile photo to dedicated endpoint
  Future<Map<String, dynamic>> uploadProfileImage(File imageFile) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(imageFile.path),
    });
    final resp = await _request(() => _dio.post('/upload/profile', data: form));
    if (resp.statusCode == 200) {
      return resp.data as Map<String, dynamic>;
    }
    if (resp.statusCode == 401) throw UnauthorizedException('Sesión expirada');
    throw Exception('Error en la subida de foto de perfil: ${resp.statusCode}');
  }

  /// Update user profile photo
  Future<void> updateProfilePhoto(String imageUrl) async {
    final resp = await _request(() => _dio.put(
      '/auth/profile/photo',
      data: {'imageUrl': imageUrl},
    ));
    if (resp.statusCode != 200) {
      throw Exception('Error updating profile photo: ${resp.statusCode}');
    }
  }

  /// Delete user profile photo
  Future<void> deleteProfilePhoto() async {
    final resp = await _request(() => _dio.delete('/auth/profile/photo'));
    if (resp.statusCode != 200) {
      throw Exception('Error deleting profile photo: ${resp.statusCode}');
    }
  }

  /// Persistir preferencia de idioma en backend (silencioso en caso de error)
  Future<void> updatePreferredLanguage(String code) async {
    try {
      await _dio.put('/auth/language', data: {'language': code});
    } catch (_) {}
  }

  /// Revocar refresh token en backend al hacer logout
  Future<void> revokeRefreshToken(String refreshToken) async {
    try {
      await _dio.post('/auth/logout', data: {'refreshToken': refreshToken});
    } catch (_) {}
  }

  // --- Auth endpoints (opcional) ---
  Future<Map<String, dynamic>> login({String? email, String? username, required String password}) async {
    final payload = {
      if (email != null) 'email': email,
      if (username != null) 'username': username,
      'password': password,
    };
    final resp = await _request(() => _dio.post('/auth/login', data: payload));
    if (resp.statusCode == 200) {
      final data = resp.data;
      final tokens = data['data']?['tokens'];
      if (tokens != null) {
        setTokens(access: tokens['accessToken'] as String?, refresh: tokens['refreshToken'] as String?);
      }
      return data;
    }
    throw Exception('Login failed: ${resp.data}');
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
    final resp = await _request(() => _dio.post('/auth/register', data: payload));
    if (resp.statusCode == 201) {
      final data = resp.data;
      final tokens = data['data']?['tokens'];
      if (tokens != null) {
        setTokens(access: tokens['accessToken'] as String?, refresh: tokens['refreshToken'] as String?);
      }
      return data;
    }
    throw Exception('Register failed: ${resp.data}');
  }

  Future<Map<String, dynamic>> getMeRaw() async {
    final resp = await _request(() => _dio.get('/auth/me'));
    if (resp.statusCode == 200) {
      return resp.data['data'] as Map<String, dynamic>;
    }
    throw Exception('Error perfil: ${resp.statusCode}');
  }

  Future<Map<String, dynamic>> getReceiptImageInfo(String receiptId) async {
    final response = await _request(() => _dio.get('/images/receipt/$receiptId/info'));
    if (response.statusCode == 200) {
      return response.data['data'] as Map<String, dynamic>;
    }
    throw Exception('Error imagen info: ${response.statusCode}');
  }

  Future<Map<String, dynamic>> getReceiptStats({int days = 365}) async {
    final response = await _request(() => _dio.get('/receipts/stats', queryParameters: {'days': days}));
    if (response.statusCode == 200) {
      return response.data['data'] as Map<String, dynamic>;
    }
    throw Exception('Error receipt stats: ${response.statusCode}');
  }

  // --- Analytics endpoints ---
  Future<Map<String, dynamic>> getSmartAlerts() async {
    final response = await _request(() => _dio.get('/analytics/smart-alerts'));
    if (response.statusCode == 200) {
      return response.data['data'] as Map<String, dynamic>;
    }
    throw Exception('Error smart alerts: ${response.statusCode}');
  }

  Future<Map<String, dynamic>> getSpendingAnalysis({int months = 6}) async {
    final response = await _request(
      () => _dio.get('/analytics/spending-analysis', queryParameters: {'months': months}),
      method: 'GET',
      path: '/analytics/spending-analysis',
      queryParams: {'months': months},
    );
    if (response.statusCode == 200) {
      return response.data['data'] as Map<String, dynamic>;
    }
    throw Exception('Error spending analysis: ${response.statusCode}');
  }

  Future<List<Map<String, dynamic>>> getMonthlyTotals({int months = 4}) async {
    final response = await _request(
      () => _dio.get('/analytics/monthly-totals', queryParameters: {'months': months}),
      method: 'GET',
      path: '/analytics/monthly-totals',
      queryParams: {'months': months},
    );
    if (response.statusCode == 200) {
      final data = response.data['data'];
      final list = (data['monthlyTotals'] as List?) ?? const [];
      return list.cast<Map<String, dynamic>>();
    }
    throw Exception('Error monthly totals: ${response.statusCode}');
  }

  // --- Product analytics ---
  Future<Map<String, dynamic>> getProductMonthlyStats(String productId, {int months = 12}) async {
    final response = await _request(() => _dio.get('/analytics/products/$productId/monthly-stats', queryParameters: {'months': months}));
    if (response.statusCode == 200) {
      return response.data['data'] as Map<String, dynamic>;
    }
    throw Exception('Error product monthly stats: ${response.statusCode}');
  }

  Future<Map<String, dynamic>> getProductPriceComparison(String productId, {int days = 90}) async {
    final response = await _request(() => _dio.get('/analytics/products/$productId/price-comparison', queryParameters: {'days': days}));
    if (response.statusCode == 200) {
      return response.data['data'] as Map<String, dynamic>;
    }
    throw Exception('Error product price comparison: ${response.statusCode}');
  }

  Future<Map<String, dynamic>> getProductFrequencyAnalysis(String productId) async {
    final response = await _request(() => _dio.get('/analytics/products/$productId/frequency-analysis'));
    if (response.statusCode == 200) {
      return response.data['data'] as Map<String, dynamic>;
    }
    throw Exception('Error product frequency: ${response.statusCode}');
  }

  // ============================================================================
  // BUDGETS ENDPOINTS
  // ============================================================================

  /// Get all budgets for the authenticated user
  Future<List<dynamic>> getBudgets({String? category, bool? isActive, String? period}) async {
    final qp = <String, String>{
      if (category != null && category.isNotEmpty) 'category': category,
      // Backend expects 'active' query param, not 'isActive'
      if (isActive != null) 'active': isActive.toString(),
      if (period != null && period.isNotEmpty) 'period': period,
    };
    final response = await _request(() => _dio.get('/budgets', queryParameters: qp.isEmpty ? null : qp));
    if (response.statusCode == 200) {
      // Backend returns: { data: { budgets: [...], count: 123 } }
      final data = response.data['data']['budgets'] as List<dynamic>?;
      return data ?? [];
    }
    throw Exception('Error getting budgets: ${response.statusCode}');
  }

  /// Get specific budget by ID
  Future<Budget> getBudget(String id) async {
    final response = await _request(
      () => _dio.get('/budgets/$id'),
      method: 'GET',
      path: '/budgets/$id',
    );
    if (response.statusCode == 200) {
      final data = response.data['data'] as Map<String, dynamic>;
      final budgetJson = data['budget'] as Map<String, dynamic>;
      return Budget.fromJson(budgetJson);
    }
    throw Exception('Error getting budget: ${response.statusCode}');
  }

  /// Create a new budget
  Future<Budget> createBudget(Map<String, dynamic> budgetData) async {
    final response = await _request(() => _dio.post('/budgets', data: budgetData));
    if (response.statusCode == 201) {
      final data = response.data['data']['budget'] as Map<String, dynamic>;
      return Budget.fromJson(data);
    }
    throw Exception('Error creating budget: ${response.statusCode}');
  }

  /// Update existing budget
  Future<Budget> updateBudget(String id, Map<String, dynamic> budgetData) async {
    final response = await _request(() => _dio.put('/budgets/$id', data: budgetData));
    if (response.statusCode == 200) {
      final data = response.data['data']['budget'] as Map<String, dynamic>;
      return Budget.fromJson(data);
    }
    throw Exception('Error updating budget: ${response.statusCode}');
  }

  /// Delete budget
  Future<void> deleteBudget(String id) async {
    final response = await _request(() => _dio.delete('/budgets/$id'));
    if (response.statusCode != 200) {
      throw Exception('Error deleting budget: ${response.statusCode}');
    }
  }

  /// Duplicate budget
  Future<Map<String, dynamic>> duplicateBudget({
    required String id,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final payload = {
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
    };
    final response = await _request(() => _dio.post('/budgets/$id/duplicate', data: payload));
    if (response.statusCode == 201) {
      return response.data['data'] as Map<String, dynamic>;
    }
    throw Exception('Error duplicating budget: ${response.statusCode}');
  }

  /// Get budget progress
  Future<Map<String, dynamic>> getBudgetProgress(String id) async {
    final response = await _request(
      () => _dio.get('/budgets/$id/progress'),
      method: 'GET',
      path: '/budgets/$id/progress',
    );
    if (response.statusCode == 200) {
      return response.data['data'] as Map<String, dynamic>;
    }
    throw Exception('Error getting budget progress: ${response.statusCode}');
  }

  /// Get budgets summary
  Future<Map<String, dynamic>> getBudgetsSummary() async {
    final response = await _request(
      () => _dio.get('/budgets/summary'),
      method: 'GET',
      path: '/budgets/summary',
    );
    if (response.statusCode == 200) {
      return response.data['data'] as Map<String, dynamic>;
    }
    throw Exception('Error getting budgets summary: ${response.statusCode}');
  }

  /// Get budget insights
  Future<List<dynamic>> getBudgetInsights(String id) async {
    final response = await _request(
      () => _dio.get('/budgets/$id/insights'),
      method: 'GET',
      path: '/budgets/$id/insights',
    );
    if (response.statusCode == 200) {
      // Backend returns a list of insight objects in data
      return response.data['data'] as List<dynamic>;
    }
    throw Exception('Error getting budget insights: ${response.statusCode}');
  }

  /// Get budget predictions
  Future<Map<String, dynamic>> getBudgetPredictions(String id) async {
    final response = await _request(
      () => _dio.get('/budgets/$id/predictions'),
      method: 'GET',
      path: '/budgets/$id/predictions',
    );
    if (response.statusCode == 200) {
      return response.data['data'] as Map<String, dynamic>;
    }
    throw Exception('Error getting budget predictions: ${response.statusCode}');
  }

  /// Get budget spending trend (historical + projection)
  /// Supports query params:
  /// - months: number of past months to include (default 6)
  /// - mode: 'cumulative' (default) to return month-to-date cumulative series
  /// - sparse: if true, return only days with receipts in current month
  Future<Map<String, dynamic>> getBudgetSpendingTrend(
    String id, {
    int months = 6,
    String mode = 'cumulative',
    bool sparse = true,
  }) async {
    final qp = <String, dynamic>{
      'months': months.toString(),
      'mode': mode,
      'sparse': sparse.toString(),
    };
    final response = await _request(
      () => _dio.get('/budgets/$id/spending-trend', queryParameters: qp),
      method: 'GET',
      path: '/budgets/$id/spending-trend',
    );
    if (response.statusCode == 200) {
      return response.data['data'] as Map<String, dynamic>;
    }
    throw Exception('Error getting budget spending trend: ${response.statusCode}');
  }

  /// Get budget alerts
  Future<Map<String, dynamic>> getBudgetAlerts({
    String? budgetId,
    bool? unreadOnly,
    int? limit,
  }) async {
    final qp = <String, String>{
      if (budgetId != null) 'budgetId': budgetId,
      if (unreadOnly != null) 'unreadOnly': unreadOnly.toString(),
      if (limit != null) 'limit': limit.toString(),
    };
    final response = await _request(() => _dio.get('/budgets/alerts', queryParameters: qp.isEmpty ? null : qp));
    if (response.statusCode == 200) {
      return response.data['data'] as Map<String, dynamic>;
    }
    throw Exception('Error getting budget alerts: ${response.statusCode}');
  }

  /// Mark alert as read
  Future<void> markAlertAsRead(String alertId) async {
    final response = await _request(() => _dio.put('/budgets/alerts/$alertId/read'));
    if (response.statusCode != 200) {
      throw Exception('Error marking alert as read: ${response.statusCode}');
    }
  }

  /// Mark all alerts as read
  Future<void> markAllAlertsAsRead() async {
    // Backend route is /budgets/alerts/mark-all-read
    final response = await _request(() => _dio.put('/budgets/alerts/mark-all-read'));
    if (response.statusCode != 200) {
      throw Exception('Error marking all alerts as read: ${response.statusCode}');
    }
  }

  /// Get alert statistics
  Future<Map<String, dynamic>> getAlertStats() async {
    final response = await _request(() => _dio.get('/budgets/alerts/stats'));
    if (response.statusCode == 200) {
      return response.data['data'] as Map<String, dynamic>;
    }
    throw Exception('Error getting alert stats: ${response.statusCode}');
  }

  // ============================================================================
  // NOTIFICATIONS ENDPOINTS
  // ============================================================================

  /// Get notification preferences
  Future<Map<String, dynamic>> getNotificationPreferences() async {
    final response = await _request(() => _dio.get('/notifications/preferences'));
    if (response.statusCode == 200) {
      return response.data['data'] as Map<String, dynamic>;
    }
    throw Exception('Error getting notification preferences: ${response.statusCode}');
  }

  /// Update notification preferences
  Future<Map<String, dynamic>> updateNotificationPreferences({
    bool? budgetAlerts,
    bool? receiptProcessing,
    bool? weeklyDigest,
    bool? monthlyDigest,
    bool? priceAlerts,
    bool? productRecommendations,
  }) async {
    final payload = <String, dynamic>{
      if (budgetAlerts != null) 'budgetAlerts': budgetAlerts,
      if (receiptProcessing != null) 'receiptProcessing': receiptProcessing,
      if (weeklyDigest != null) 'weeklyDigest': weeklyDigest,
      if (monthlyDigest != null) 'monthlyDigest': monthlyDigest,
      if (priceAlerts != null) 'priceAlerts': priceAlerts,
      if (productRecommendations != null) 'productRecommendations': productRecommendations,
    };
    final response = await _request(() => _dio.put('/notifications/preferences', data: payload));
    if (response.statusCode == 200) {
      return response.data['data'] as Map<String, dynamic>;
    }
    throw Exception('Error updating notification preferences: ${response.statusCode}');
  }

  /// Register FCM token for push notifications
  Future<void> registerFCMToken({
    required String fcmToken,
    Map<String, dynamic>? deviceInfo,
  }) async {
    final payload = <String, dynamic>{
      'fcmToken': fcmToken,
      if (deviceInfo != null) 'deviceInfo': deviceInfo,
    };
    final response = await _request(() => _dio.post('/notifications/fcm-token', data: payload));
    if (response.statusCode != 200) {
      throw Exception('Error registering FCM token: ${response.statusCode}');
    }
  }

  /// Remove FCM token (disable push notifications)
  Future<void> removeFCMToken() async {
    final response = await _request(() => _dio.delete('/notifications/fcm-token'));
    if (response.statusCode != 200) {
      throw Exception('Error removing FCM token: ${response.statusCode}');
    }
  }

  /// Update notification channels
  Future<void> updateNotificationChannels({
    required Map<String, bool> channels,
  }) async {
    final payload = {'channels': channels};
    final response = await _request(() => _dio.put('/notifications/channels', data: payload));
    if (response.statusCode != 200) {
      throw Exception('Error updating notification channels: ${response.statusCode}');
    }
  }

  /// Set quiet hours (do not disturb)
  Future<void> setQuietHours({
    required bool enabled,
    int? start,
    int? end,
  }) async {
    final payload = <String, dynamic>{
      'enabled': enabled,
      if (start != null) 'start': start,
      if (end != null) 'end': end,
    };
    final response = await _request(() => _dio.put('/notifications/quiet-hours', data: payload));
    if (response.statusCode != 200) {
      throw Exception('Error setting quiet hours: ${response.statusCode}');
    }
  }

  /// Update digest settings
  Future<void> updateDigestSettings({
    String? frequency,
    int? day,
    int? hour,
    bool? weeklyEnabled,
    bool? monthlyEnabled,
  }) async {
    final payload = <String, dynamic>{
      if (frequency != null) 'frequency': frequency,
      if (day != null) 'day': day,
      if (hour != null) 'hour': hour,
      if (weeklyEnabled != null) 'weeklyEnabled': weeklyEnabled,
      if (monthlyEnabled != null) 'monthlyEnabled': monthlyEnabled,
    };
    final response = await _request(() => _dio.put('/notifications/digest', data: payload));
    if (response.statusCode != 200) {
      throw Exception('Error updating digest settings: ${response.statusCode}');
    }
  }

  /// Send test notification
  Future<void> sendTestNotification({String? channel}) async {
    final payload = <String, dynamic>{
      if (channel != null) 'channel': channel,
    };
    final response = await _request(() => _dio.post('/notifications/test', data: payload));
    if (response.statusCode != 200) {
      throw Exception('Error sending test notification: ${response.statusCode}');
    }
  }

  /// Get FCM service status
  Future<Map<String, dynamic>> getFCMStatus() async {
    final response = await _request(() => _dio.get('/notifications/fcm/status'));
    if (response.statusCode == 200) {
      return response.data['data'] as Map<String, dynamic>;
    }
    throw Exception('Error getting FCM status: ${response.statusCode}');
  }
}
