// Listens on a learner's MQTT topic for a few seconds, from their own computer.
// Desktop-only (native sockets), which is why it is not in connectors.dart.

import 'dart:async';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'connectors.dart';

Future<List<String>> realMqttProbe(MqttSettings s, String topic, Duration listenFor) async {
  final id = 'trainer_${DateTime.now().millisecondsSinceEpoch}';
  final client = MqttServerClient.withPort(s.host, id, s.port)
    ..secure = s.tls
    ..keepAlivePeriod = 20
    ..connectTimeoutPeriod = 8000
    ..logging(on: false);
  var msg = MqttConnectMessage().withClientIdentifier(id).startClean();
  if (s.username.isNotEmpty) msg = msg.authenticateAs(s.username, s.password);
  client.connectionMessage = msg;

  final received = <String>[];
  try {
    await client.connect();
  } catch (e) {
    client.disconnect();
    throw NotAllowed('Could not connect to the MQTT broker (${s.host}:${s.port}): ${e.toString().split('\n').first}');
  }
  if (client.connectionStatus?.state != MqttConnectionState.connected) {
    final code = client.connectionStatus?.returnCode;
    client.disconnect();
    throw NotAllowed('The MQTT broker refused the connection ($code). Check the username and password in Settings.');
  }
  final sub = client.updates?.listen((events) {
    for (final e in events) {
      final p = e.payload as MqttPublishMessage;
      received.add(MqttPublishPayload.bytesToStringAsString(p.payload.message));
    }
  });
  client.subscribe(topic, MqttQos.atLeastOnce);
  await Future<void>.delayed(listenFor);
  await sub?.cancel();
  client.disconnect();
  return received.length > 20 ? received.sublist(received.length - 20) : received;
}
