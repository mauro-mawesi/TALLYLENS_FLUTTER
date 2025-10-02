// Configuración simple para el front

// Base URL de la API (incluye prefijo /api)
const String baseApiUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:3000/api');

// No se usa token embebido en dev. El flujo siempre es: login -> refresh tokens.
