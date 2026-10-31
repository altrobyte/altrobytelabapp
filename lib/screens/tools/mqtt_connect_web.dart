import 'package:mqtt_client/mqtt_browser_client.dart';
import 'package:mqtt_client/mqtt_client.dart';

MqttClient wsMqttClient(String host, String clientId) => MqttBrowserClient(host, clientId);
