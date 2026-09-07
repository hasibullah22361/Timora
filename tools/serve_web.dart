import 'dart:io';

void main() async {
  final dir = Directory('build/web');
  if (!await dir.exists()) {
    stderr.writeln('build/web directory does not exist.');
    exit(1);
  }

  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8088);
  stdout.writeln('Timora Web server listening on http://localhost:${server.port}');

  await for (HttpRequest req in server) {
    req.response.headers.set('Access-Control-Allow-Origin', '*');
    
    var path = req.uri.path;
    if (path == '/' || path.isEmpty) {
      path = '/index.html';
    }

    var file = File('build/web$path');
    if (!await file.exists()) {
      // SPA fallback
      file = File('build/web/index.html');
    }

    final ext = file.path.split('.').last.toLowerCase();
    ContentType type;
    switch (ext) {
      case 'html':
        type = ContentType.html;
        break;
      case 'js':
        type = ContentType('application', 'javascript', charset: 'utf-8');
        break;
      case 'css':
        type = ContentType('text', 'css', charset: 'utf-8');
        break;
      case 'json':
        type = ContentType.json;
        break;
      case 'png':
        type = ContentType('image', 'png');
        break;
      case 'wasm':
        type = ContentType('application', 'wasm');
        break;
      default:
        type = ContentType.binary;
    }

    req.response.headers.contentType = type;
    try {
      await req.response.addStream(file.openRead());
    } catch (_) {}
    await req.response.close();
  }
}
