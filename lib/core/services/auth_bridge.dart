typedef VoidAsync = Future<void> Function();
typedef TokensUpdated = Future<void> Function(String? accessToken, String? refreshToken);

class AuthBridge {
  static VoidAsync? onUnauthorized;
  static TokensUpdated? onTokensUpdated;
}
