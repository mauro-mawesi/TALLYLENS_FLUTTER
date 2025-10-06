import 'dart:async';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:recibos_flutter/core/services/budget_service.dart';

/// Handler para mensajes en background (debe ser top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Este handler se ejecuta cuando la app está en background o terminada
  debugPrint('Handling a background message: ${message.messageId}');
  debugPrint('Title: ${message.notification?.title}');
  debugPrint('Body: ${message.notification?.body}');
  debugPrint('Data: ${message.data}');
}

/// Servicio para manejar Firebase Cloud Messaging (FCM).
/// Gestiona tokens, permisos, y recepción de notificaciones push.
class FCMService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final BudgetService _budgetService;

  // Stream controllers para notificaciones
  final _messageStreamController = StreamController<RemoteMessage>.broadcast();
  final _tokenStreamController = StreamController<String>.broadcast();

  // Token actual del dispositivo
  String? _currentToken;

  FCMService({
    required BudgetService budgetService,
  }) : _budgetService = budgetService;

  /// Stream de mensajes recibidos cuando la app está en foreground
  Stream<RemoteMessage> get onMessage => _messageStreamController.stream;

  /// Stream de cambios en el FCM token
  Stream<String> get onTokenRefresh => _tokenStreamController.stream;

  /// Token FCM actual del dispositivo
  String? get currentToken => _currentToken;

  /// Inicializa el servicio FCM.
  /// Debe llamarse al inicio de la app, después de Firebase.initializeApp().
  Future<void> initialize() async {
    try {
      // 1. Solicitar permisos de notificaciones
      final settings = await _requestPermission();

      if (settings.authorizationStatus != AuthorizationStatus.authorized) {
        debugPrint('FCM: Permission not granted');
        return;
      }

      // 2. Obtener el token FCM
      _currentToken = await _firebaseMessaging.getToken();
      if (_currentToken != null) {
        debugPrint('FCM Token: $_currentToken');
        await _registerTokenWithBackend(_currentToken!);
        _tokenStreamController.add(_currentToken!);
      }

      // 3. Configurar listener para refresh de token
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        debugPrint('FCM Token refreshed: $newToken');
        _currentToken = newToken;
        _registerTokenWithBackend(newToken);
        _tokenStreamController.add(newToken);
      });

      // 4. Configurar handlers para diferentes estados de la app
      await _setupMessageHandlers();

      // 5. Configurar canales de notificación (Android)
      if (Platform.isAndroid) {
        await _setupAndroidNotificationChannel();
      }

      debugPrint('FCM Service initialized successfully');
    } catch (e) {
      debugPrint('Error initializing FCM: $e');
    }
  }

  /// Solicita permisos de notificaciones al usuario.
  Future<NotificationSettings> _requestPermission() async {
    final settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    debugPrint('FCM Permission status: ${settings.authorizationStatus}');
    return settings;
  }

  /// Registra el token FCM con el backend.
  Future<void> _registerTokenWithBackend(String token) async {
    try {
      await _budgetService.registerFCMToken(token);
      debugPrint('FCM token registered with backend');
    } catch (e) {
      debugPrint('Error registering FCM token with backend: $e');
      // No lanzar error, el token se intentará registrar nuevamente más tarde
    }
  }

  /// Configura los handlers para mensajes en diferentes estados.
  Future<void> _setupMessageHandlers() async {
    // Handler para mensajes cuando la app está en foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Received message in foreground: ${message.messageId}');
      debugPrint('Title: ${message.notification?.title}');
      debugPrint('Body: ${message.notification?.body}');
      debugPrint('Data: ${message.data}');

      // Emitir mensaje al stream para que la UI pueda reaccionar
      _messageStreamController.add(message);

      // Aquí puedes mostrar una notificación local si deseas
      _handleForegroundNotification(message);
    });

    // Handler para cuando el usuario toca una notificación y la app estaba en background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('Message clicked, app opened: ${message.messageId}');
      _handleNotificationClick(message);
    });

    // Verificar si la app fue abierta desde una notificación
    final initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('App opened from terminated state via notification');
      _handleNotificationClick(initialMessage);
    }
  }

  /// Configura el canal de notificaciones para Android.
  /// Requerido para Android 8.0+ (API 26+)
  Future<void> _setupAndroidNotificationChannel() async {
    // Este método requiere el plugin flutter_local_notifications
    // Por ahora solo documentamos la configuración necesaria
    debugPrint('Android notification channel should be configured');

    // TODO: Implementar configuración de canales con flutter_local_notifications
    // Example:
    // const AndroidNotificationChannel channel = AndroidNotificationChannel(
    //   'budget_alerts', // ID
    //   'Budget Alerts', // Nombre
    //   description: 'Notifications for budget alerts and updates',
    //   importance: Importance.high,
    // );
    //
    // final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    //     FlutterLocalNotificationsPlugin();
    //
    // await flutterLocalNotificationsPlugin
    //     .resolvePlatformSpecificImplementation<
    //         AndroidFlutterLocalNotificationsPlugin>()
    //     ?.createNotificationChannel(channel);
  }

  /// Maneja notificaciones recibidas en foreground.
  void _handleForegroundNotification(RemoteMessage message) {
    // Aquí puedes decidir si mostrar una notificación local o no
    // Por defecto, las notificaciones en foreground no se muestran automáticamente

    final notification = message.notification;
    if (notification != null) {
      // TODO: Mostrar notificación local usando flutter_local_notifications
      debugPrint('Foreground notification: ${notification.title}');
    }
  }

  /// Maneja el click en una notificación.
  /// Navega a la pantalla correspondiente según el tipo de notificación.
  void _handleNotificationClick(RemoteMessage message) {
    final data = message.data;

    // Extraer información del payload
    final type = data['type'] as String?;
    final budgetId = data['budgetId'] as String?;
    final alertId = data['alertId'] as String?;

    debugPrint('Notification clicked - Type: $type, BudgetId: $budgetId, AlertId: $alertId');

    // TODO: Implementar navegación usando GoRouter
    // Ejemplo:
    // if (type == 'budget_alert' && budgetId != null) {
    //   context.go('/budgets/$budgetId');
    // } else if (type == 'budget_exceeded') {
    //   context.go('/budgets/$budgetId');
    // } else if (type == 'digest') {
    //   context.go('/budgets');
    // }
  }

  /// Suscribe el dispositivo a un topic específico.
  /// Útil para notificaciones broadcast a grupos de usuarios.
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _firebaseMessaging.subscribeToTopic(topic);
      debugPrint('Subscribed to topic: $topic');
    } catch (e) {
      debugPrint('Error subscribing to topic $topic: $e');
    }
  }

  /// Desuscribe el dispositivo de un topic.
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic(topic);
      debugPrint('Unsubscribed from topic: $topic');
    } catch (e) {
      debugPrint('Error unsubscribing from topic $topic: $e');
    }
  }

  /// Elimina el token FCM actual del backend.
  /// Llamar al cerrar sesión.
  Future<void> deleteToken() async {
    try {
      if (_currentToken != null) {
        await _budgetService.removeFCMToken();
        debugPrint('FCM token removed from backend');
      }

      await _firebaseMessaging.deleteToken();
      _currentToken = null;
      debugPrint('FCM token deleted');
    } catch (e) {
      debugPrint('Error deleting FCM token: $e');
    }
  }

  /// Obtiene el token APNs (Apple Push Notification service) en iOS.
  /// Solo funciona en dispositivos iOS.
  Future<String?> getAPNSToken() async {
    if (Platform.isIOS) {
      return await _firebaseMessaging.getAPNSToken();
    }
    return null;
  }

  /// Configura si la app muestra badge en el icono (iOS).
  Future<void> setAutoInitEnabled(bool enabled) async {
    await _firebaseMessaging.setAutoInitEnabled(enabled);
  }

  /// Verifica el estado actual de los permisos de notificación.
  Future<AuthorizationStatus> checkPermissionStatus() async {
    final settings = await _firebaseMessaging.getNotificationSettings();
    return settings.authorizationStatus;
  }

  /// Solicita permisos nuevamente si fueron denegados.
  Future<bool> requestPermissionAgain() async {
    final settings = await _requestPermission();
    return settings.authorizationStatus == AuthorizationStatus.authorized;
  }

  /// Limpia recursos al destruir el servicio.
  void dispose() {
    _messageStreamController.close();
    _tokenStreamController.close();
  }
}

/// Configuración de notificaciones para diferentes tipos de alertas.
class NotificationConfig {
  /// Configuración para alertas de umbral (threshold alerts)
  static const Map<String, dynamic> thresholdAlert = {
    'channelId': 'budget_alerts',
    'channelName': 'Budget Alerts',
    'priority': 'high',
    'sound': 'default',
  };

  /// Configuración para alertas predictivas
  static const Map<String, dynamic> predictiveAlert = {
    'channelId': 'budget_predictions',
    'channelName': 'Budget Predictions',
    'priority': 'default',
    'sound': 'default',
  };

  /// Configuración para digests (resúmenes)
  static const Map<String, dynamic> digest = {
    'channelId': 'budget_digests',
    'channelName': 'Budget Digests',
    'priority': 'low',
    'sound': 'default',
  };

  /// Configuración para alertas de exceso de presupuesto
  static const Map<String, dynamic> exceededAlert = {
    'channelId': 'budget_exceeded',
    'channelName': 'Budget Exceeded',
    'priority': 'max',
    'sound': 'default',
  };
}
