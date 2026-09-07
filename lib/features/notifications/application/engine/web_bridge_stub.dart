// Non-web stub for Web APIs bridge
bool isNotificationSupported() => false;
String getNotificationPermission() => 'denied';
Future<String> requestNotificationPermission() async => 'denied';
bool showNotification(String title, String body, {String? tag, String? icon}) => false;
bool isSpeechSupported() => false;
bool speak(String text, {double rate = 1.0, double pitch = 1.0, double volume = 1.0}) => false;
void stopSpeech() {}
bool downloadFile(String filename, String content, {String mimeType = 'application/json'}) => false;
