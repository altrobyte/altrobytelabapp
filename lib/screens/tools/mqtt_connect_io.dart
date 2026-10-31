import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

MqttClient wsMqttClient(String host, String clientId) => MqttServerClient(host, clientId)..useWebSocket = true;
