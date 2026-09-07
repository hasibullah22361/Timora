import 'web_bridge_stub.dart'
    if (dart.library.js_interop) 'web_bridge_web.dart' as bridge;

/// WebBridge — Facade for web browser APIs using conditional imports.
class WebBridge {
  static bool isNotificationSupported() => bridge.isNotificationSupported();
  
  static String getNotificationPermission() => bridge.getNotificationPermission();
  
  static Future<String> requestNotificationPermission() =>
      bridge.requestNotificationPermission();
      
  static bool showNotification(
    String title,
    String body, {
    String? tag,
    String? icon,
  }) =>
      bridge.showNotification(title, body, tag: tag, icon: icon);
      
  static bool isSpeechSupported() => bridge.isSpeechSupported();
  
  static bool speak(
    String text, {
    double rate = 1.0,
    double pitch = 1.0,
    double volume = 1.0,
  }) =>
      bridge.speak(text, rate: rate, pitch: pitch, volume: volume);
      
  static void stopSpeech() => bridge.stopSpeech();
  
  static bool downloadFile(
    String filename,
    String content, {
    String mimeType = 'application/json',
  }) =>
      bridge.downloadFile(filename, content, mimeType: mimeType);
}
