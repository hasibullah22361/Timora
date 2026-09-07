import 'dart:async';
import 'dart:js_interop';

@JS('TimoraWeb.isNotificationSupported')
external bool _isNotificationSupported();

@JS('TimoraWeb.getNotificationPermission')
external JSString _getNotificationPermission();

@JS('TimoraWeb.requestNotificationPermission')
external JSPromise<JSString> _requestNotificationPermission();

@JS('TimoraWeb.showNotification')
external bool _showNotification(JSString title, JSString body, JSString? tag, JSString? icon);

@JS('TimoraWeb.isSpeechSupported')
external bool _isSpeechSupported();

@JS('TimoraWeb.speak')
external bool _speak(JSString text, JSNumber rate, JSNumber pitch, JSNumber volume);

@JS('TimoraWeb.stopSpeech')
external void _stopSpeech();

@JS('TimoraWeb.downloadFile')
external bool _downloadFile(JSString filename, JSString content, JSString mimeType);

bool isNotificationSupported() {
  try {
    return _isNotificationSupported();
  } catch (_) {
    return false;
  }
}

String getNotificationPermission() {
  try {
    return _getNotificationPermission().toDart;
  } catch (_) {
    return 'denied';
  }
}

Future<String> requestNotificationPermission() async {
  try {
    final jsPromise = _requestNotificationPermission();
    final jsString = await jsPromise.toDart;
    return jsString.toDart;
  } catch (_) {
    return 'denied';
  }
}

bool showNotification(String title, String body, {String? tag, String? icon}) {
  try {
    return _showNotification(
      title.toJS,
      body.toJS,
      tag?.toJS,
      icon?.toJS,
    );
  } catch (_) {
    return false;
  }
}

bool isSpeechSupported() {
  try {
    return _isSpeechSupported();
  } catch (_) {
    return false;
  }
}

bool speak(String text, {double rate = 1.0, double pitch = 1.0, double volume = 1.0}) {
  try {
    return _speak(
      text.toJS,
      rate.toJS,
      pitch.toJS,
      volume.toJS,
    );
  } catch (_) {
    return false;
  }
}

void stopSpeech() {
  try {
    _stopSpeech();
  } catch (_) {}
}

bool downloadFile(String filename, String content, {String mimeType = 'application/json'}) {
  try {
    return _downloadFile(
      filename.toJS,
      content.toJS,
      mimeType.toJS,
    );
  } catch (_) {
    return false;
  }
}
