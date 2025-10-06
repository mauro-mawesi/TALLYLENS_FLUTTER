# Firebase Cloud Messaging (FCM) Setup Guide

Esta guía explica cómo configurar Firebase Cloud Messaging para recibir notificaciones push en la aplicación TallyLens.

## Tabla de Contenidos

1. [Crear Proyecto Firebase](#1-crear-proyecto-firebase)
2. [Configurar Android](#2-configurar-android)
3. [Configurar iOS](#3-configurar-ios)
4. [Inicializar Firebase en la App](#4-inicializar-firebase-en-la-app)
5. [Testing](#5-testing)
6. [Troubleshooting](#6-troubleshooting)

---

## 1. Crear Proyecto Firebase

### 1.1 Crear el Proyecto

1. Ve a [Firebase Console](https://console.firebase.google.com/)
2. Click en "Add project" o "Agregar proyecto"
3. Nombra el proyecto: `TallyLens` (o el nombre que prefieras)
4. Deshabilita Google Analytics si no lo necesitas (opcional)
5. Click en "Create project"

### 1.2 Habilitar Cloud Messaging

1. En el menú lateral, ve a **Build > Cloud Messaging**
2. Click en "Get started" si es la primera vez
3. No necesitas configurar nada adicional aquí por ahora

---

## 2. Configurar Android

### 2.1 Registrar App en Firebase

1. En Firebase Console, click en el ícono de Android ⚙️
2. Ingresa el **Android package name**: `com.yourdomain.recibos_flutter`
   - **IMPORTANTE**: Este debe coincidir exactamente con `applicationId` en `android/app/build.gradle`
3. App nickname (opcional): `TallyLens Android`
4. SHA-1 certificate (opcional pero recomendado para Auth):
   ```bash
   cd android
   ./gradlew signingReport
   ```
   - Copia el SHA-1 del debug keystore
5. Click "Register app"

### 2.2 Descargar google-services.json

1. Descarga el archivo `google-services.json`
2. Colócalo en: `android/app/google-services.json`
3. **IMPORTANTE**: Agrega `google-services.json` al `.gitignore` si contiene información sensible

### 2.3 Configurar build.gradle (Project level)

Edita `android/build.gradle`:

```gradle
buildscript {
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath 'com.android.tools.build:gradle:8.1.0'
        classpath 'com.google.gms:google-services:4.4.0'  // ADD THIS LINE
        classpath "org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlin_version"
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}
```

### 2.4 Configurar build.gradle (App level)

Edita `android/app/build.gradle`:

```gradle
apply plugin: 'com.android.application'
apply plugin: 'kotlin-android'
apply plugin: 'com.google.gms.google-services'  // ADD THIS LINE (at the bottom)

android {
    // ... existing config
}

dependencies {
    // ... existing dependencies

    // Firebase (if not added automatically)
    implementation platform('com.google.firebase:firebase-bom:32.7.0')
    implementation 'com.google.firebase:firebase-messaging'
}
```

**Al final del archivo**, asegúrate que esté esta línea:
```gradle
apply plugin: 'com.google.gms.google-services'
```

### 2.5 Configurar AndroidManifest.xml

Edita `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <!-- Permisos para notificaciones -->
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.VIBRATE"/>
    <uses-permission android:name="android.permission.WAKE_LOCK"/>

    <!-- Android 13+ (API 33) - Notificaciones explícitas -->
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>

    <application
        android:name="${applicationName}"
        android:label="TallyLens"
        android:icon="@mipmap/ic_launcher">

        <!-- ... existing activity config ... -->

        <!-- Firebase Messaging Service -->
        <service
            android:name="io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingService"
            android:exported="false">
            <intent-filter>
                <action android:name="com.google.firebase.MESSAGING_EVENT"/>
            </intent-filter>
        </service>

        <!-- Default notification channel (Android 8+) -->
        <meta-data
            android:name="com.google.firebase.messaging.default_notification_channel_id"
            android:value="budget_alerts"/>

        <!-- Notification icon -->
        <meta-data
            android:name="com.google.firebase.messaging.default_notification_icon"
            android:resource="@drawable/ic_notification"/>

        <!-- Notification color -->
        <meta-data
            android:name="com.google.firebase.messaging.default_notification_color"
            android:resource="@color/notification_color"/>

    </application>
</manifest>
```

### 2.6 Agregar íconos de notificación

Crea un ícono para notificaciones en:
- `android/app/src/main/res/drawable/ic_notification.xml`

```xml
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="24dp"
    android:height="24dp"
    android:viewportWidth="24"
    android:viewportHeight="24">
    <path
        android:fillColor="#FFFFFF"
        android:pathData="M12,2C6.48,2 2,6.48 2,12s4.48,10 10,10 10,-4.48 10,-10S17.52,2 12,2zM13,17h-2v-2h2v2zM13,13h-2L11,7h2v6z"/>
</vector>
```

Crea un color en `android/app/src/main/res/values/colors.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="notification_color">#0175C2</color>
</resources>
```

---

## 3. Configurar iOS

### 3.1 Registrar App en Firebase

1. En Firebase Console, click en el ícono de iOS
2. Ingresa el **iOS bundle ID**: `com.yourdomain.recibosFlutter`
   - **IMPORTANTE**: Este debe coincidir con el Bundle Identifier en Xcode
3. App nickname (opcional): `TallyLens iOS`
4. App Store ID (opcional, para después)
5. Click "Register app"

### 3.2 Descargar GoogleService-Info.plist

1. Descarga el archivo `GoogleService-Info.plist`
2. Abre el proyecto iOS en Xcode:
   ```bash
   open ios/Runner.xcworkspace
   ```
3. Arrastra `GoogleService-Info.plist` al proyecto en la carpeta `Runner`
4. **IMPORTANTE**: Marca "Copy items if needed"
5. Verifica que esté en el target `Runner`

### 3.3 Configurar Capabilities

En Xcode:

1. Selecciona el proyecto `Runner`
2. Ve a la pestaña "Signing & Capabilities"
3. Click en "+ Capability"
4. Agrega:
   - **Push Notifications**
   - **Background Modes** y marca:
     - ✅ Remote notifications
     - ✅ Background fetch (opcional)

### 3.4 Configurar AppDelegate.swift

Edita `ios/Runner/AppDelegate.swift`:

```swift
import UIKit
import Flutter
import Firebase  // ADD THIS

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    FirebaseApp.configure()  // ADD THIS LINE

    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Handle notifications
  override func application(_ application: UIApplication,
                           didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    print("APNs token: \(deviceToken)")
  }

  override func application(_ application: UIApplication,
                           didFailToRegisterForRemoteNotificationsWithError error: Error) {
    print("Failed to register for remote notifications: \(error)")
  }
}
```

### 3.5 Subir APNs Authentication Key

Para enviar notificaciones, necesitas una APNs key:

1. Ve a [Apple Developer Console](https://developer.apple.com/account/resources/authkeys/list)
2. Click en "+" para crear una nueva key
3. Selecciona **Apple Push Notifications service (APNs)**
4. Descarga el archivo `.p8`
5. En Firebase Console:
   - Ve a **Project Settings > Cloud Messaging**
   - En la sección **Apple app configuration**, sube el archivo `.p8`
   - Ingresa el **Key ID** y **Team ID**

---

## 4. Inicializar Firebase en la App

### 4.1 Actualizar main.dart

Edita `lib/main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:recibos_flutter/core/services/fcm_service.dart';

// Background message handler (debe ser top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await firebaseMessagingBackgroundHandler(message);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar Firebase
  await Firebase.initializeApp();

  // Configurar background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(const MyApp());
}
```

### 4.2 Inicializar FCMService

En tu setup de dependencias (donde usas GetIt), agrega:

```dart
// En lib/core/di/service_locator.dart

import 'package:recibos_flutter/core/services/fcm_service.dart';

void setupServices() {
  // ... existing services ...

  // Budget Service
  getIt.registerLazySingleton<BudgetService>(
    () => BudgetService(apiService: getIt<ApiService>()),
  );

  // FCM Service
  getIt.registerLazySingleton<FCMService>(
    () => FCMService(budgetService: getIt<BudgetService>()),
  );
}

// Inicializar FCM después del login
Future<void> initializeFCM() async {
  final fcmService = getIt<FCMService>();
  await fcmService.initialize();
}
```

### 4.3 Solicitar permisos

Después del login, inicializa FCM:

```dart
// Ejemplo en tu pantalla de inicio o después del login
@override
void initState() {
  super.initState();
  _initializeFCM();
}

Future<void> _initializeFCM() async {
  final fcmService = getIt<FCMService>();
  await fcmService.initialize();

  // Escuchar mensajes en foreground
  fcmService.onMessage.listen((message) {
    // Mostrar notificación local o snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message.notification?.body ?? '')),
    );
  });
}
```

---

## 5. Testing

### 5.1 Probar con Firebase Console

1. Ve a **Cloud Messaging** en Firebase Console
2. Click en "Send your first message"
3. Ingresa:
   - **Notification title**: "Test Budget Alert"
   - **Notification text**: "You've spent 80% of your monthly budget"
4. Click "Send test message"
5. Ingresa el FCM token de tu dispositivo (lo puedes ver en los logs)
6. Click "Test"

### 5.2 Probar con el Backend

Una vez configurado el backend, usa el endpoint de test:

```bash
curl -X POST http://localhost:3000/api/notifications/test \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json"
```

### 5.3 Verificar en diferentes estados

Prueba la app en:
- ✅ **Foreground** (app abierta)
- ✅ **Background** (app minimizada)
- ✅ **Terminated** (app cerrada)

---

## 6. Troubleshooting

### Android

**Error: "google-services.json not found"**
- Verifica que el archivo esté en `android/app/google-services.json`
- Ejecuta `flutter clean` y vuelve a compilar

**Error: "Failed to get FCM token"**
- Verifica que Google Play Services esté instalado en el emulador/dispositivo
- Usa un emulador con Google APIs (no AOSP)

**Notificaciones no llegan en foreground**
- Las notificaciones en foreground requieren configuración adicional
- Considera usar `flutter_local_notifications` para mostrarlas

### iOS

**Error: "APNs device token not set"**
- Verifica que las Capabilities estén correctamente configuradas
- Solo funciona en dispositivos reales, no en simulador

**Notificaciones no llegan**
- Verifica que hayas subido el APNs key en Firebase Console
- Revisa que el Bundle ID coincida exactamente
- Prueba en un dispositivo físico (no simulador)

### General

**Token no se registra en el backend**
- Verifica los logs de `fcm_service.dart`
- Asegúrate que el usuario esté autenticado
- Revisa que el endpoint `/api/notifications/fcm-token` esté funcionando

**Mensajes no llegan**
- Verifica que el token sea válido
- Revisa los logs del backend
- Usa Firebase Console para enviar mensajes de prueba

---

## Configuración del Backend

El backend ya está configurado para enviar notificaciones FCM. Asegúrate de configurar las credenciales:

### Variables de Entorno

Agrega al `.env` del backend:

```bash
# Firebase Admin SDK
GOOGLE_APPLICATION_CREDENTIALS=path/to/firebase-admin-sdk.json
```

### Descargar Firebase Admin SDK

1. En Firebase Console, ve a **Project Settings** ⚙️
2. Pestaña **Service Accounts**
3. Click en "Generate new private key"
4. Guarda el archivo JSON descargado
5. Apunta la variable `GOOGLE_APPLICATION_CREDENTIALS` a este archivo

---

## Recursos Adicionales

- [FlutterFire Documentation](https://firebase.flutter.dev/)
- [Firebase Cloud Messaging](https://firebase.google.com/docs/cloud-messaging)
- [Firebase Admin SDK](https://firebase.google.com/docs/admin/setup)
- [APNs Setup Guide](https://developer.apple.com/documentation/usernotifications)

---

## Notas de Seguridad

⚠️ **IMPORTANTE**:

- **NO** commitees `google-services.json` o `GoogleService-Info.plist` al repositorio público
- **NO** commitees el archivo de credenciales del Admin SDK
- Agrega estos archivos al `.gitignore`:
  ```
  # Firebase
  android/app/google-services.json
  ios/Runner/GoogleService-Info.plist
  firebase-admin-sdk*.json
  ```
- Usa Firebase App Check para proteger tus APIs de abuso
- Rota las APNs keys periódicamente
- Revoca tokens FCM cuando el usuario cierre sesión

---

## Siguiente Paso

Después de configurar Firebase, continúa con la implementación de los BLoCs y Screens para la funcionalidad completa de presupuestos.
