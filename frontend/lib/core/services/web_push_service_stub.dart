/// Stub implementation for non-web platforms
class WebPushService {
  static Future<void> subscribeIfNeeded(String authToken) async {
    // No-op on non-web platforms
  }
}
