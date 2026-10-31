// An MQTT client over WebSockets for the dev tools: the browser's own on the web, a socket one in the Android app
// (31 Oct 2026; mqtt_browser_client needs dart:html).
export 'mqtt_connect_web.dart' if (dart.library.io) 'mqtt_connect_io.dart';
