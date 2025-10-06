import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:recibos_flutter/core/services/api_service.dart';
import 'package:local_auth/local_auth.dart';
import 'package:recibos_flutter/core/models/user.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:recibos_flutter/core/services/lock_bridge.dart';

class AuthService with ChangeNotifier {
  static const _kAccess = 'accessToken';
  static const _kRefresh = 'refreshToken';

  final ApiService _api;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final LocalAuthentication _localAuth = LocalAuthentication();

  String? _accessToken;
  String? _refreshToken;
  bool _biometricEnabled = false;
  bool _locked = false;
  bool _autoLockEnabled = false;
  int _autoLockGraceMs = 30000; // 30s por defecto
  UserProfile? _profile;
  Timer? _refreshTimer;
  // Contador de 401 consecutivos para evitar loops de biometría si el refresh ya no sirve
  int _unauthCount = 0;
  DateTime? _firstUnauthAt;

  AuthService({required ApiService api}) : _api = api;

  bool get isLoggedIn => (_accessToken != null && _accessToken!.isNotEmpty);
  String? get accessToken => _accessToken;
  bool get biometricEnabled => _biometricEnabled;
  bool get locked => _locked;
  bool get autoLockEnabled => _autoLockEnabled;
  Duration get autoLockGrace => Duration(milliseconds: _autoLockGraceMs);
  UserProfile? get profile => _profile;
  String? get displayName => _profile?.displayName;

  Future<void> init() async {
    // Lee tokens persistidos y sincroniza con ApiService
    _accessToken = await _storage.read(key: _kAccess);
    _refreshToken = await _storage.read(key: _kRefresh);
    _biometricEnabled = (await _storage.read(key: 'biometric_lock')) == '1';
    // Preferencias no sensibles en SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    _autoLockEnabled = prefs.getBool('auto_lock_enabled') ?? false;
    _autoLockGraceMs = prefs.getInt('auto_lock_grace_ms') ?? 30000;
    if (_accessToken != null && _accessToken!.isNotEmpty) {
      _api.setTokens(access: _accessToken, refresh: _refreshToken);
      // Bloqueo al iniciar si el usuario activó biometría
      _locked = _biometricEnabled;
      await _loadProfileSafe();
      _scheduleProactiveRefresh();
      // Refresh silencioso si el token expira pronto (mejora UX al abrir)
      await _maybeRefreshSoon();
    }
    notifyListeners();
  }

  Future<void> login({String? email, String? username, required String password}) async {
    final resp = await _api.login(email: email, username: username, password: password);
    final tokens = resp['data']?['tokens'];
    if (tokens == null) {
      throw Exception('Respuesta de login inválida');
    }
    _accessToken = tokens['accessToken'] as String?;
    _refreshToken = tokens['refreshToken'] as String?;
    // Persistir
    if (_accessToken != null) await _storage.write(key: _kAccess, value: _accessToken);
    if (_refreshToken != null) await _storage.write(key: _kRefresh, value: _refreshToken);
    // Configurar cliente
    _api.setTokens(access: _accessToken, refresh: _refreshToken);
    // No activar ni bloquear automáticamente al iniciar sesión.
    await _loadProfileSafe();
    _scheduleProactiveRefresh();
    notifyListeners();
  }

  Future<void> register({
    required String email,
    required String username,
    required String password,
    String? firstName,
    String? lastName,
  }) async {
    final resp = await _api.register(
      email: email,
      username: username,
      password: password,
      firstName: firstName,
      lastName: lastName,
    );
    final tokens = resp['data']?['tokens'];
    if (tokens == null) {
      throw Exception('Respuesta de registro inválida');
    }
    _accessToken = tokens['accessToken'] as String?;
    _refreshToken = tokens['refreshToken'] as String?;
    if (_accessToken != null) await _storage.write(key: _kAccess, value: _accessToken);
    if (_refreshToken != null) await _storage.write(key: _kRefresh, value: _refreshToken);
    _api.setTokens(access: _accessToken, refresh: _refreshToken);
    // No activar ni bloquear automáticamente al registrar.
    await _loadProfileSafe();
    _scheduleProactiveRefresh();
    notifyListeners();
  }

  Future<void> logout() async {
    final refresh = _refreshToken;
    try {
      if (refresh != null && refresh.isNotEmpty) {
        await _api.revokeRefreshToken(refresh);
      }
    } catch (_) {}
    _accessToken = null;
    _refreshToken = null;
    _locked = false;
    _cancelProactiveRefresh();
    await _storage.delete(key: _kAccess);
    await _storage.delete(key: _kRefresh);
    _api.setAccessToken(null);
    _profile = null;
    notifyListeners();
  }

  Future<void> updateTokens({String? access, String? refresh}) async {
    if (access != null && access.isNotEmpty) {
      _accessToken = access;
      await _storage.write(key: _kAccess, value: _accessToken);
    }
    if (refresh != null && refresh.isNotEmpty) {
      _refreshToken = refresh;
      await _storage.write(key: _kRefresh, value: _refreshToken);
    }
    _api.setTokens(access: _accessToken, refresh: _refreshToken);
    _scheduleProactiveRefresh();
    notifyListeners();
  }

  Future<void> _loadProfileSafe() async {
    try {
      final data = await _api.getMeRaw();
      final user = data['user'] as Map<String, dynamic>?;
      if (user != null) {
        _profile = UserProfile.fromJson(user);
      }
    } catch (_) {
      // ignore
    }
  }

  /// Refresh user profile from server (e.g., after updating profile photo)
  Future<void> refreshProfile() async {
    try {
      final data = await _api.getMeRaw();
      final user = data['user'] as Map<String, dynamic>?;
      if (user != null) {
        _profile = UserProfile.fromJson(user);
        notifyListeners();
      }
    } catch (e) {
      throw Exception('Failed to refresh profile: $e');
    }
  }

  Future<bool> unlock({String? localizedReason}) async {
    if (!_biometricEnabled) {
      _locked = false;
      notifyListeners();
      return true;
    }
    try {
      final supported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;
      final bioms = await _localAuth.getAvailableBiometrics();
      if (!supported || (!canCheck && bioms.isEmpty)) {
        // No hay biometría disponible: no bloqueamos
        _locked = false;
        _biometricEnabled = false;
        await _storage.write(key: 'biometric_lock', value: '0');
        notifyListeners();
        return true;
      }
      // Evita relock inmediato por eventos de ciclo de vida causados por el diálogo biométrico
      LockBridge.suppressOnce();
      final did = await _localAuth.authenticate(
        localizedReason: localizedReason ?? 'Unlock to continue',
        options: const AuthenticationOptions(
          biometricOnly: false, // permite PIN/Patrón del SO
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
      if (did) {
        _locked = false;
        // Intentar refrescar si el access está por expirar pronto; respeta cooldown interno.
        await _maybeRefreshSoon();
        notifyListeners();
      }
      return did;
    } catch (_) {
      return false;
    }
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    if (enabled) {
      final supported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;
      final bioms = await _localAuth.getAvailableBiometrics();
      if (!supported || (!canCheck && bioms.isEmpty)) {
        _biometricEnabled = false;
        await _storage.write(key: 'biometric_lock', value: '0');
        notifyListeners();
        return;
      }
    }
    _biometricEnabled = enabled;
    await _storage.write(key: 'biometric_lock', value: enabled ? '1' : '0');
    // No bloquear en el momento de activar; se bloqueará al reabrir
    notifyListeners();
  }

  Future<void> setAutoLockEnabled(bool enabled) async {
    _autoLockEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_lock_enabled', enabled);
    notifyListeners();
  }

  Future<void> setAutoLockGrace(Duration d) async {
    _autoLockGraceMs = d.inMilliseconds;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('auto_lock_grace_ms', _autoLockGraceMs);
    notifyListeners();
  }

  void forceLock() {
    if (_biometricEnabled && isLoggedIn) {
      _locked = true;
      notifyListeners();
    }
  }

  bool get hasRefreshToken => _refreshToken != null && _refreshToken!.isNotEmpty;

  /// Maneja 401 globales distinguiendo casos sin refresh y loops.
  /// Política tolerante: mantener sesión como Instagram (solo logout manual o refresh inválido)
  Future<void> handleUnauthorized() async {
    if (!isLoggedIn) return;
    if (!hasRefreshToken) {
      await logout();
      return;
    }

    // Intentar refresh silencioso primero (sin forzar lock)
    final now = DateTime.now();

    // Ventana ampliada a 60 segundos y umbral aumentado a 5 intentos
    // para tolerar errores de red transitorios
    if (_firstUnauthAt == null || now.difference(_firstUnauthAt!) > const Duration(seconds: 60)) {
      _firstUnauthAt = now;
      _unauthCount = 1;
    } else {
      _unauthCount++;

      // Solo hacer logout si es claramente un refresh token inválido
      // NO por errores de red transitorios o problemas temporales del servidor
      if (_unauthCount >= 5) {
        await logout();
        _unauthCount = 0;
        _firstUnauthAt = null;
      }
    }
  }
}

extension on AuthService {
  // Decodifica el 'exp' del JWT de acceso y programa un refresh proactivo ~60s antes.
  DateTime? _accessExp() {
    final token = _accessToken;
    if (token == null || token.isEmpty) return null;
    final parts = token.split('.');
    if (parts.length < 2) return null;
    try {
      String normalized = parts[1].replaceAll('-', '+').replaceAll('_', '/');
      while (normalized.length % 4 != 0) {
        normalized += '=';
      }
      final payload = json.decode(utf8.decode(base64.decode(normalized))) as Map<String, dynamic>;
      final exp = payload['exp'];
      if (exp is int) {
        return DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true);
      }
    } catch (_) {
      // ignore malformed tokens
    }
    return null;
  }

  void _scheduleProactiveRefresh() {
    _cancelProactiveRefresh();
    final exp = _accessExp();
    if (exp == null) return;
    final now = DateTime.now().toUtc();
    final when = exp.subtract(const Duration(seconds: 60));
    final delay = when.isAfter(now) ? when.difference(now) : const Duration(seconds: 1);
    _refreshTimer = Timer(delay, _refreshAccessToken);
  }

  void _cancelProactiveRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  Future<void> _refreshAccessToken() async {
    try {
      final ok = await _api.refreshNow();
      if (!ok) {
        final until = _api.refreshCooldownUntil;
        if (until != null && DateTime.now().toUtc().isBefore(until)) {
          // Reprogramar para el fin del cooldown con pequeño margen
          _cancelProactiveRefresh();
          final delay = until.difference(DateTime.now().toUtc()) + const Duration(seconds: 1);
          _refreshTimer = Timer(delay, _refreshAccessToken);
          return;
        }
      }
    } catch (_) {
      // Ignorar
    } finally {
      // Reprogramar siguiente intento usando el nuevo access (si lo hay)
      _scheduleProactiveRefresh();
    }
  }

  Future<void> _maybeRefreshSoon() async {
    final exp = _accessExp();
    if (exp == null) return;
    final now = DateTime.now().toUtc();
    if (!exp.isAfter(now.add(const Duration(seconds: 60)))) {
      try {
        final ok = await _api.refreshNow();
        if (!ok) {
          final until = _api.refreshCooldownUntil;
          if (until != null && now.isBefore(until)) {
            // Evita reintentos inmediatos durante cooldown
            return;
          }
        }
      } catch (_) {}
    }
  }
}
