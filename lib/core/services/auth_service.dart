import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:recibos_flutter/core/services/api_service.dart';
import 'package:local_auth/local_auth.dart';
import 'package:recibos_flutter/core/models/user.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    notifyListeners();
  }

  Future<void> logout() async {
    _accessToken = null;
    _refreshToken = null;
    _locked = false;
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
}
