/// ESP32 Arduino sketch that pairs with the OTA Updater tool. Shown in the
/// tool's "Get firmware sketch" dialog so students can copy it straight into
/// the Arduino IDE. Protocol: `<base>/ota/cmd` (JSON in) and
/// `<base>/ota/status` (JSON out) — keep both in sync with
/// ota_updater_screen.dart.
const otaFirmwareSketch = r'''
// Altrobyte OTA client for ESP32 (MQTT-triggered, HTTPS download)
// Libraries: PubSubClient, ArduinoJson (install from Library Manager)
#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <HTTPUpdate.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>

const char* WIFI_SSID = "YOUR_WIFI";
const char* WIFI_PASS = "YOUR_PASSWORD";
const char* MQTT_HOST = "broker.hivemq.com";   // plain TCP port 1883
const int   MQTT_PORT = 1883;
const char* BASE      = "altrobyte/device1";   // same base topic as the web tool
const char* FW_VERSION = "1.0.0";

WiFiClient net;
PubSubClient mqtt(net);
String cmdTopic, statusTopic;

void publishStatus(const char* state, int progress, const char* msg = "") {
  JsonDocument d;
  d["state"] = state;
  d["progress"] = progress;
  d["version"] = FW_VERSION;
  d["msg"] = msg;
  char buf[200];
  serializeJson(d, buf);
  mqtt.publish(statusTopic.c_str(), buf);
}

void doOta(const String& url) {
  publishStatus("downloading", 0);
  WiFiClientSecure secure;
  secure.setInsecure();  // demo only: pin a CA certificate in production
  httpUpdate.rebootOnUpdate(false);
  httpUpdate.onProgress([](int cur, int total) {
    static int last = -1;
    int pct = total ? (cur * 100) / total : 0;
    if (pct != last && pct % 5 == 0) { last = pct; publishStatus("flashing", pct); mqtt.loop(); }
  });
  t_httpUpdate_return r = httpUpdate.update(secure, url);
  if (r == HTTP_UPDATE_OK) {
    publishStatus("done", 100, "rebooting");
    mqtt.loop();
    delay(500);
    ESP.restart();
  } else {
    publishStatus("failed", 0, httpUpdate.getLastErrorString().c_str());
  }
}

void onMessage(char* topic, byte* payload, unsigned int len) {
  JsonDocument d;
  if (deserializeJson(d, payload, len)) { publishStatus("failed", 0, "bad json"); return; }
  String url = d["url"] | "";
  String version = d["version"] | "";
  if (url.isEmpty()) { publishStatus("failed", 0, "no url"); return; }
  if (version == FW_VERSION) { publishStatus("idle", 100, "already on this version"); return; }
  doOta(url);
}

void reconnect() {
  while (!mqtt.connected()) {
    String id = "esp32-" + String((uint32_t)ESP.getEfuseMac(), HEX);
    if (mqtt.connect(id.c_str())) { mqtt.subscribe(cmdTopic.c_str()); publishStatus("idle", 100, "online"); }
    else delay(2000);
  }
}

void setup() {
  Serial.begin(115200);
  WiFi.begin(WIFI_SSID, WIFI_PASS);
  while (WiFi.status() != WL_CONNECTED) delay(300);
  cmdTopic = String(BASE) + "/ota/cmd";
  statusTopic = String(BASE) + "/ota/status";
  mqtt.setServer(MQTT_HOST, MQTT_PORT);
  mqtt.setCallback(onMessage);
  mqtt.setBufferSize(512);
  Serial.printf("Running firmware %s\n", FW_VERSION);
}

void loop() {
  if (!mqtt.connected()) reconnect();
  mqtt.loop();
  // ...your normal application code here...
}
''';
