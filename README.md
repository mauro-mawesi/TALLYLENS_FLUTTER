# TallyLens Flutter

Cross-platform mobile application for receipt scanning, expense tracking, and intelligent analytics.

## Features

- **Receipt Scanning**: Capture receipts with camera or upload from gallery
- **OCR Processing**: Automatic text extraction and data parsing
- **AI Categorization**: Intelligent receipt and product categorization
- **Expense Tracking**: Track spending by category, merchant, and date
- **Analytics**: Visualize spending trends and patterns
- **Multi-language**: Support for English, Spanish, and Dutch
- **Offline Support**: Local data caching for offline access
- **Secure Authentication**: JWT-based authentication with refresh tokens

## Tech Stack

- **Framework**: Flutter 3.6+
- **Language**: Dart 3.6+
- **State Management**: BLoC pattern
- **Navigation**: GoRouter
- **Dependency Injection**: GetIt
- **HTTP Client**: Dio
- **Local Storage**: SharedPreferences / Hive
- **Image Handling**: image_picker, cached_network_image
- **Internationalization**: flutter_localizations

## Prerequisites

- Flutter SDK 3.6+ ([Install Guide](https://docs.flutter.dev/get-started/install))
- Dart 3.6+
- Android Studio / Xcode (for mobile development)
- Java 17+ (for Android builds)
- CocoaPods (for iOS builds on macOS)

## Quick Start

### 1. Clone and Install

```bash
git clone git@github.com:mauro-mawesi/TALLYLENS_FLUTTER.git
cd TALLYLENS_FLUTTER
flutter pub get
```

### 2. Configure API Endpoint

The app connects to the TallyLens backend API. Configure the API URL using Dart defines:

```bash
# Option 1: Run with custom API URL
flutter run --dart-define=API_BASE_URL=http://your-api-host:3000/api

# Option 2: Edit default in lib/core/config/app_config.dart
# const String baseApiUrl = String.fromEnvironment('API_BASE_URL',
#   defaultValue: 'http://localhost:3000/api');
```

### 3. Run the App

```bash
# Check available devices
flutter devices

# Run on specific device
flutter run -d <device-id>

# Run on Android emulator
flutter run -d emulator-5554

# Run on iOS simulator
flutter run -d "iPhone 14"

# Run on physical device
flutter run -d <device-id>

# Run in debug mode with API URL
flutter run --dart-define=API_BASE_URL=http://192.168.1.10:3000/api
```

## Development

### Project Structure

```
lib/
├── core/
│   ├── config/          # App configuration
│   ├── constants/       # Constants and enums
│   ├── di/              # Dependency injection
│   ├── router/          # Navigation routing
│   └── theme/           # App themes
├── features/
│   ├── auth/            # Authentication feature
│   ├── receipts/        # Receipt management
│   ├── analytics/       # Analytics and reports
│   └── settings/        # User settings
├── models/              # Data models
├── services/            # API clients and services
├── widgets/             # Reusable widgets
└── main.dart            # App entry point
```

### Running Tests

```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/widget_test.dart

# Run tests with coverage
flutter test --coverage
```

### Build for Production

#### Android APK

```bash
# Build release APK
flutter build apk --release

# Build app bundle for Play Store
flutter build appbundle --release

# Build with custom API URL
flutter build apk --release --dart-define=API_BASE_URL=https://api.tallylens.com/api
```

#### iOS

```bash
# Build iOS app
flutter build ios --release

# Build with custom API URL
flutter build ios --release --dart-define=API_BASE_URL=https://api.tallylens.com/api
```

### Code Generation

If using code generation for models or routes:

```bash
# Generate code
flutter pub run build_runner build

# Watch for changes
flutter pub run build_runner watch

# Clean and rebuild
flutter pub run build_runner build --delete-conflicting-outputs
```

## Configuration

### Environment Variables

Use `--dart-define` flags to configure the app:

```bash
flutter run \
  --dart-define=API_BASE_URL=http://192.168.1.10:3000/api
```

Available variables:
- `API_BASE_URL`: Backend API base URL (default: `http://localhost:3000/api`)

### Platform-Specific Setup

#### Android

1. Update `android/app/src/main/AndroidManifest.xml` with required permissions:
   ```xml
   <uses-permission android:name="android.permission.INTERNET" />
   <uses-permission android:name="android.permission.CAMERA" />
   <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
   ```

2. For Android 12+, update `android/app/build.gradle`:
   ```gradle
   android {
       compileSdkVersion 34
       defaultConfig {
           minSdkVersion 21
           targetSdkVersion 34
       }
   }
   ```

#### iOS

1. Update `ios/Runner/Info.plist` with camera and photo permissions:
   ```xml
   <key>NSCameraUsageDescription</key>
   <string>Camera access is required to scan receipts</string>
   <key>NSPhotoLibraryUsageDescription</key>
   <string>Photo library access is required to select receipt images</string>
   ```

2. Minimum iOS version: 12.0 (configured in `ios/Podfile`)

## Architecture

### BLoC Pattern

The app uses the BLoC (Business Logic Component) pattern for state management:

- **Events**: User actions or system events
- **States**: UI states representing different screens/widgets
- **BLoC**: Business logic processing events and emitting states

Example:
```dart
// Event
class LoginRequested extends AuthEvent {
  final String email;
  final String password;
}

// State
class AuthAuthenticated extends AuthState {
  final User user;
}

// BLoC
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  // Handle events and emit states
}
```

### Dependency Injection

Uses GetIt for service locator pattern:

```dart
// Register services
getIt.registerSingleton<ApiClient>(ApiClient());
getIt.registerFactory<AuthService>(() => AuthService(getIt()));

// Use in widgets
final authService = getIt<AuthService>();
```

## Features Guide

### Receipt Scanning

1. Tap the camera button
2. Take a photo of the receipt or select from gallery
3. Review and confirm the capture
4. OCR processing extracts text automatically
5. AI categorizes the receipt and products
6. Edit details if needed
7. Save to your receipt collection

### Viewing Analytics

1. Navigate to Analytics tab
2. View spending by category
3. See merchant comparisons
4. Track spending trends over time
5. Filter by date range

### Multi-language Support

The app supports multiple languages:
- English (en)
- Spanish (es)
- Dutch (nl)

Language is detected automatically from device settings or can be changed in app settings.

## Troubleshooting

### Common Issues

**Issue**: App can't connect to API
- Verify API URL is correct
- Check network connectivity
- Ensure backend server is running
- For Android emulator, use `10.0.2.2` instead of `localhost`

**Issue**: Camera not working
- Check camera permissions in device settings
- Verify permissions in AndroidManifest.xml / Info.plist

**Issue**: Build errors after `flutter pub get`
- Run `flutter clean`
- Delete `pubspec.lock`
- Run `flutter pub get` again
- Restart IDE

## Performance Tips

- Use `const` constructors where possible
- Implement lazy loading for large lists
- Cache network images
- Use `ListView.builder` for long lists
- Profile with Flutter DevTools

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Follow Flutter style guide
4. Write tests for new features
5. Commit your changes (`git commit -m 'Add amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

## Code Style

- Follow [Effective Dart](https://dart.dev/guides/language/effective-dart) guidelines
- Use meaningful variable names
- Add comments for complex logic
- Keep widgets small and focused
- Extract reusable widgets

## License

MIT

## Support

For issues and feature requests, please use the [GitHub Issues](https://github.com/mauro-mawesi/TALLYLENS_FLUTTER/issues) page.

---

Built with ❤️ using Flutter
