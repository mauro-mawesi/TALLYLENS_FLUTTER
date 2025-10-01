import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Un servicio para manejar la autenticación biométrica local (huella, rostro).
class LocalAuthService {
  final LocalAuthentication _auth = LocalAuthentication();

  /// Comprueba si hay sensores biométricos disponibles en el dispositivo.
  Future<bool> isBiometricAvailable() async {
    try {
      // canCheckBiometrics verifica si hay hardware y si se ha configurado.
      return await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
    } on PlatformException catch (e) {
      print('Error al comprobar biometría: $e');
      return false;
    }
  }

  /// Inicia el diálogo de autenticación biométrica.
  /// Devuelve `true` si la autenticación es exitosa.
  Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          // Muestra el diálogo de autenticación tan pronto como sea posible.
          stickyAuth: true,
          // Si se establece en `true`, solo permite la autenticación biométrica.
          // Si es `false`, puede permitir otros métodos como PIN o patrón.
          biometricOnly: false,
        ),
      );
    } on PlatformException catch (e) {
      print('Error durante la autenticación: $e');
      return false;
    }
  }
}
