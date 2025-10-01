// Configuración simple para el front

// Base URL de la API (incluye prefijo /api)
const String baseApiUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:3000/api');

// Token de acceso para desarrollo (opcional). Pega aquí temporalmente tu token para pruebas.
// En producción, usa un flujo de login y almacenamiento seguro.
const String _tokenEnv = String.fromEnvironment('ACCESS_TOKEN', defaultValue: '');
final String? kDevAccessToken = (_tokenEnv.isEmpty) ? null : _tokenEnv;
