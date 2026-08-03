import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mqtt_client/mqtt_browser_client.dart';
import 'package:mqtt_client/mqtt_client.dart';
import '../../constants/app_colors.dart';

/// Public, no-login MQTT client — connect to any broker over secure
/// WebSocket, subscribe/publish, watch messages live. Pre-filled with
/// the topic pattern used in Altrobyte's own ESP32 IoT workshop demo
/// so it's useful the moment it loads.
class MqttTesterScreen extends StatefulWidget {
  final String? initialHost;
  final String? initialTopic;
  const MqttTesterScreen({super.key, this.initialHost, this.initialTopic});

  @override
  State<MqttTesterScreen> createState() => _MqttTesterScreenState();
}

class _MqttTesterScreenState extends State<MqttTesterScreen> {
  late final _hostCtrl =
      TextEditingController(text: widget.initialHost ?? 'wss://broker.hivemq.com/mqtt');
  final _portCtrl = TextEditingController(text: '8884');
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  late final _subTopicCtrl =
      TextEditingController(text: widget.initialTopic ?? 'altrobyte/home/adc/data');
  final _pubTopicCtrl = TextEditingController(text: 'altrobyte/home/led/control');
  final _payloadCtrl = TextEditingController(text: 'ON');

  MqttQos _subQos = MqttQos.atMostOnce;
  MqttQos _pubQos = MqttQos.atLeastOnce;
  bool _retain = false;

  MqttBrowserClient? _client;
  bool _connecting = false;
  bool get _connected => _client?.connectionStatus?.state == MqttConnectionState.connected;
  final List<_MqttLogLine> _log = [];

  static const _presetBrokers = [
    ('HiveMQ (public)', 'wss://broker.hivemq.com/mqtt', '8884'),
    ('Mosquitto (public)', 'wss://test.mosquitto.org', '8081'),
  ];

  void _addLog(String text, {bool isError = false, bool isOutgoing = false}) {
    if (!mounted) return;
    setState(() {
      _log.insert(0, _MqttLogLine(text, DateTime.now(), isError: isError, isOutgoing: isOutgoing));
      if (_log.length > 200) _log.removeLast();
    });
  }

  Future<void> _connect() async {
    if (_connecting || _connected) return;
    final host = _hostCtrl.text.trim();
    final port = int.tryParse(_portCtrl.text.trim()) ?? 8884;
    if (host.isEmpty) return;

    setState(() => _connecting = true);
    final clientId = 'altrobytelab_${DateTime.now().millisecondsSinceEpoch}';
    final client = MqttBrowserClient(host, clientId);
    client.port = port;
    client.logging(on: false);
    client.keepAlivePeriod = 20;
    client.connectTimeoutPeriod = 8000;
    client.onDisconnected = () { _addLog('Disconnected', isError: true); };
    client.onConnected = () { _addLog('Connected to $host:$port'); };
    client.onSubscribed = (topic) { _addLog('Subscribed to "$topic"'); };
    var connMsg = MqttConnectMessage().withClientIdentifier(clientId).startClean();
    final username = _usernameCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (username.isNotEmpty) {
      connMsg = connMsg.authenticateAs(username, password);
    }
    client.connectionMessage = connMsg;

    try {
      await client.connect();
      _client = client;
      client.updates?.listen((events) {
        for (final e in events) {
          final msg = e.payload as MqttPublishMessage;
          final payload = MqttPublishPayload.bytesToStringAsString(msg.payload.message);
          _addLog('${e.topic}  →  $payload');
        }
      });
    } catch (e) {
      _addLog('Connection failed: $e', isError: true);
      client.disconnect();
      _client = null;
    }
    if (mounted) setState(() => _connecting = false);
  }

  void _disconnect() {
    _client?.disconnect();
    setState(() {});
  }

  void _subscribe() {
    final topic = _subTopicCtrl.text.trim();
    if (topic.isEmpty || !_connected) return;
    _client!.subscribe(topic, _subQos);
  }

  void _publish() {
    final topic = _pubTopicCtrl.text.trim();
    final payload = _payloadCtrl.text;
    if (topic.isEmpty || !_connected) return;
    final builder = MqttClientPayloadBuilder()..addString(payload);
    _client!.publishMessage(topic, _pubQos, builder.payload!, retain: _retain);
    _addLog('$topic  ←  $payload  (QoS ${_pubQos.index}${_retain ? ', retained' : ''})', isOutgoing: true);
  }

  @override
  void dispose() {
    _client?.disconnect();
    _hostCtrl.dispose();
    _portCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _subTopicCtrl.dispose();
    _pubTopicCtrl.dispose();
    _payloadCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Row(children: [
          const Icon(Icons.developer_board_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Text('MQTT Tester',
              style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
        ]),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Broker connection
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text('Broker', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: (_connected ? AppColors.success : Colors.grey).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.circle, size: 8, color: _connected ? AppColors.success : Colors.grey),
                        const SizedBox(width: 6),
                        Text(_connected ? 'Connected' : 'Disconnected',
                            style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600,
                                color: _connected ? AppColors.success : Colors.grey.shade700)),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: _presetBrokers.map((b) => ActionChip(
                      label: Text(b.$1, style: GoogleFonts.inter(fontSize: 11.5)),
                      onPressed: _connected ? null : () {
                        setState(() { _hostCtrl.text = b.$2; _portCtrl.text = b.$3; });
                      },
                    )).toList(),
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _hostCtrl,
                        enabled: !_connected,
                        decoration: InputDecoration(
                          labelText: 'WebSocket URL',
                          hintText: 'wss://broker.example.com/mqtt',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _portCtrl,
                        enabled: !_connected,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Port',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          isDense: true,
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _usernameCtrl,
                        enabled: !_connected,
                        decoration: InputDecoration(
                          labelText: 'Username (optional)',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _passwordCtrl,
                        enabled: !_connected,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          isDense: true,
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  Text('Most industrial/production brokers require credentials — public test brokers (HiveMQ/Mosquitto) don\'t.',
                      style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: _connected ? AppColors.error : AppColors.accent,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _connecting ? null : (_connected ? _disconnect : _connect),
                      icon: _connecting
                          ? const SizedBox(width: 16, height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Icon(_connected ? Icons.link_off_rounded : Icons.link_rounded, size: 18),
                      label: Text(_connected ? 'Disconnect' : 'Connect',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 14),

            // Subscribe
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Subscribe', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text('Wildcards work too — e.g. "sensors/+/temperature" or "sensors/#"',
                      style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _subTopicCtrl,
                        decoration: InputDecoration(
                          labelText: 'Topic', isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    DropdownButton<MqttQos>(
                      value: _subQos,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(value: MqttQos.atMostOnce, child: Text('QoS 0')),
                        DropdownMenuItem(value: MqttQos.atLeastOnce, child: Text('QoS 1')),
                        DropdownMenuItem(value: MqttQos.exactlyOnce, child: Text('QoS 2')),
                      ],
                      onChanged: (v) => setState(() => _subQos = v ?? MqttQos.atMostOnce),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                      onPressed: _connected ? _subscribe : null,
                      child: const Text('Subscribe'),
                    ),
                  ]),
                ]),
              ),
            ),
            const SizedBox(height: 14),

            // Publish
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Publish', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _pubTopicCtrl,
                    decoration: InputDecoration(
                      labelText: 'Topic', isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _payloadCtrl,
                        decoration: InputDecoration(
                          labelText: 'Payload', isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    DropdownButton<MqttQos>(
                      value: _pubQos,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(value: MqttQos.atMostOnce, child: Text('QoS 0')),
                        DropdownMenuItem(value: MqttQos.atLeastOnce, child: Text('QoS 1')),
                        DropdownMenuItem(value: MqttQos.exactlyOnce, child: Text('QoS 2')),
                      ],
                      onChanged: (v) => setState(() => _pubQos = v ?? MqttQos.atLeastOnce),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
                      onPressed: _connected ? _publish : null,
                      child: const Text('Publish'),
                    ),
                  ]),
                  Row(children: [
                    Checkbox(value: _retain, onChanged: (v) => setState(() => _retain = v ?? false)),
                    Text('Retain', style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textSecondary)),
                  ]),
                ]),
              ),
            ),
            const SizedBox(height: 14),

            // Live log
            Text('Live Messages', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 160),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: _log.isEmpty
                  ? Text('Connect and subscribe to see messages here…',
                      style: GoogleFonts.inter(color: Colors.white38, fontSize: 12.5))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _log.take(50).map((l) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Text(
                          '[${l.time.hour.toString().padLeft(2, '0')}:${l.time.minute.toString().padLeft(2, '0')}:${l.time.second.toString().padLeft(2, '0')}] ${l.text}',
                          style: GoogleFonts.robotoMono(
                              fontSize: 11.5,
                              color: l.isError
                                  ? AppColors.error
                                  : l.isOutgoing
                                      ? AppColors.accent
                                      : AppColors.success),
                        ),
                      )).toList(),
                    ),
            ),
            const SizedBox(height: 20),
          ]),
        ),
      ),
    );
  }
}

class _MqttLogLine {
  final String text;
  final DateTime time;
  final bool isError;
  final bool isOutgoing;
  _MqttLogLine(this.text, this.time, {this.isError = false, this.isOutgoing = false});
}
