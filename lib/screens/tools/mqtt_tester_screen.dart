import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mqtt_client/mqtt_client.dart';
import '../../constants/app_colors.dart';
import 'mqtt_connect.dart';

/// Public, no-login MQTT client — connect to any broker over secure
/// WebSocket, subscribe/publish, watch messages live. Pre-filled with
/// the topic pattern used in Altrobyte's own ESP32 IoT workshop demo
/// so it's useful the moment it loads. Lays out as a single column on
/// phones and a two-pane dashboard (controls | live feed) on desktop.
class MqttTesterScreen extends StatefulWidget {
  final String? initialHost;
  final int? initialPort;
  final String? initialUsername;
  final String? initialPassword;
  final String? initialTopic;
  final String? initialPubTopic;
  final String? initialPayload;
  final int? initialSubQos;
  final int? initialPubQos;
  final bool? initialRetain;
  const MqttTesterScreen({
    super.key,
    this.initialHost,
    this.initialPort,
    this.initialUsername,
    this.initialPassword,
    this.initialTopic,
    this.initialPubTopic,
    this.initialPayload,
    this.initialSubQos,
    this.initialPubQos,
    this.initialRetain,
  });

  /// Accepts either a bare hostname (legacy experiment configs) or a full
  /// `ws(s)://host[:port]/path` URL and always returns something a browser
  /// MQTT client can dial straight into. Never throws on bad input.
  static String normalizeHost(String raw) {
    final host = raw.trim();
    if (host.isEmpty) return 'wss://broker.hivemq.com/mqtt';
    if (host.startsWith('ws://') || host.startsWith('wss://')) return host;
    return 'wss://$host';
  }

  /// Best-guess default port for a bare hostname saved before the port
  /// field existed. Falls back to HiveMQ's.
  static int guessPort(String host) {
    final h = host.toLowerCase();
    if (h.contains('mosquitto')) return 8081;
    if (h.contains('emqx')) return 8084;
    return 8884;
  }

  static MqttQos qosFromInt(int? v) => switch (v) {
        1 => MqttQos.atLeastOnce,
        2 => MqttQos.exactlyOnce,
        _ => MqttQos.atMostOnce,
      };

  @override
  State<MqttTesterScreen> createState() => _MqttTesterScreenState();
}

class _MqttTesterScreenState extends State<MqttTesterScreen> {
  static const _wideBreakpoint = 900.0;

  late final _hostCtrl = TextEditingController(
      text: MqttTesterScreen.normalizeHost(widget.initialHost ?? 'wss://broker.hivemq.com/mqtt'));
  late final _portCtrl = TextEditingController(
      text: '${widget.initialPort ?? MqttTesterScreen.guessPort(widget.initialHost ?? '')}');
  late final _usernameCtrl = TextEditingController(text: widget.initialUsername ?? '');
  late final _passwordCtrl = TextEditingController(text: widget.initialPassword ?? '');
  late final _subTopicCtrl =
      TextEditingController(text: widget.initialTopic ?? 'altrobyte/home/adc/data');
  late final _pubTopicCtrl = TextEditingController(
      text: widget.initialPubTopic ?? widget.initialTopic ?? 'altrobyte/home/led/control');
  late final _payloadCtrl = TextEditingController(text: widget.initialPayload ?? 'ON');

  late MqttQos _subQos = MqttTesterScreen.qosFromInt(widget.initialSubQos);
  late MqttQos _pubQos = widget.initialPubQos != null
      ? MqttTesterScreen.qosFromInt(widget.initialPubQos)
      : MqttQos.atLeastOnce;
  late bool _retain = widget.initialRetain ?? false;

  MqttClient? _client;
  bool _connecting = false;
  bool get _connected => _client?.connectionStatus?.state == MqttConnectionState.connected;
  final List<_MqttLogLine> _log = [];
  final Set<String> _subscribedTopics = {};

  /// True when opened from an experiment with its own broker config — in
  /// that case connect (and subscribe) immediately so the student doesn't
  /// have to know what a broker even is to see live data.
  bool get _isPreconfigured => widget.initialHost != null;

  @override
  void initState() {
    super.initState();
    // Re-render on every keystroke so the Subscribe button can reflect
    // whether the topic currently typed is already subscribed.
    _subTopicCtrl.addListener(_onSubTopicChanged);
    if (_isPreconfigured) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _connect());
    }
  }

  void _onSubTopicChanged() {
    if (mounted) setState(() {});
  }

  static const _presetBrokers = [
    ('HiveMQ (public)', 'wss://broker.hivemq.com/mqtt', '8884'),
    ('Mosquitto (public)', 'wss://test.mosquitto.org', '8081'),
    ('EMQX (public)', 'wss://broker.emqx.io/mqtt', '8084'),
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
    final client = wsMqttClient(host, clientId);
    client.port = port;
    client.logging(on: false);
    client.keepAlivePeriod = 20;
    client.connectTimeoutPeriod = 8000;
    client.onDisconnected = () {
      _subscribedTopics.clear();
      _addLog('Disconnected', isError: true);
    };
    client.onConnected = () { _addLog('Connected to $host:$port'); };
    client.onSubscribed = (topic) {
      _subscribedTopics.add(topic);
      _addLog('Subscribed to "$topic"');
    };
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
      if (_isPreconfigured) _subscribe();
    } catch (e) {
      _addLog('Connection failed: $e', isError: true);
      client.disconnect();
      _client = null;
    }
    if (mounted) setState(() => _connecting = false);
  }

  void _disconnect() {
    _client?.disconnect();
    setState(() => _subscribedTopics.clear());
  }

  void _subscribe() {
    final topic = _subTopicCtrl.text.trim();
    if (topic.isEmpty || !_connected) return;
    _client!.subscribe(topic, _subQos);
  }

  void _unsubscribe(String topic) {
    if (!_connected) return;
    _client!.unsubscribe(topic);
    setState(() => _subscribedTopics.remove(topic));
    _addLog('Unsubscribed from "$topic"');
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
    _subTopicCtrl.removeListener(_onSubTopicChanged);
    _hostCtrl.dispose();
    _portCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _subTopicCtrl.dispose();
    _pubTopicCtrl.dispose();
    _payloadCtrl.dispose();
    super.dispose();
  }

  Widget _card({required Widget child}) => Card(
        elevation: 0,
        color: AppColors.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
        ),
        child: Padding(padding: const EdgeInsets.all(16), child: child),
      );

  Widget _sectionTitle(String text) =>
      Text(text, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14));

  Widget _qosDropdown(MqttQos value, ValueChanged<MqttQos?> onChanged) => DropdownButton<MqttQos>(
        value: value,
        underline: const SizedBox(),
        items: const [
          DropdownMenuItem(value: MqttQos.atMostOnce, child: Text('QoS 0')),
          DropdownMenuItem(value: MqttQos.atLeastOnce, child: Text('QoS 1')),
          DropdownMenuItem(value: MqttQos.exactlyOnce, child: Text('QoS 2')),
        ],
        onChanged: onChanged,
      );

  Widget _brokerCard() {
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _sectionTitle('Broker'),
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
          runSpacing: 8,
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
        Text('Most industrial/production brokers require credentials — public test brokers (HiveMQ/Mosquitto/EMQX) don\'t.',
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
    );
  }

  Widget _subscribeCard() {
    final currentTopic = _subTopicCtrl.text.trim();
    final alreadySubscribed = _subscribedTopics.contains(currentTopic);
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionTitle('Subscribe'),
        const SizedBox(height: 4),
        Text('Wildcards work too — e.g. "sensors/+/temperature" or "sensors/#"',
            style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
        const SizedBox(height: 10),
        TextField(
          controller: _subTopicCtrl,
          decoration: InputDecoration(
            labelText: 'Topic', isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(height: 10),
        Row(children: [
          _qosDropdown(_subQos, (v) => setState(() => _subQos = v ?? MqttQos.atMostOnce)),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: alreadySubscribed ? AppColors.success : AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
              onPressed: (_connected && currentTopic.isNotEmpty && !alreadySubscribed) ? _subscribe : null,
              icon: Icon(alreadySubscribed ? Icons.check_rounded : Icons.add_rounded, size: 16),
              label: Text(alreadySubscribed ? 'Subscribed' : 'Subscribe'),
            ),
          ),
        ]),
        if (_subscribedTopics.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Active subscriptions', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _subscribedTopics.map((t) => Chip(
              avatar: const Icon(Icons.check_circle, size: 16, color: AppColors.success),
              label: Text(t, style: GoogleFonts.robotoMono(fontSize: 11.5)),
              backgroundColor: AppColors.success.withValues(alpha: 0.08),
              side: BorderSide(color: AppColors.success.withValues(alpha: 0.25)),
              deleteIcon: const Icon(Icons.close_rounded, size: 15),
              onDeleted: () => _unsubscribe(t),
            )).toList(),
          ),
        ],
      ]),
    );
  }

  Widget _publishCard() {
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionTitle('Publish'),
        const SizedBox(height: 10),
        TextField(
          controller: _pubTopicCtrl,
          decoration: InputDecoration(
            labelText: 'Topic', isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _payloadCtrl,
          decoration: InputDecoration(
            labelText: 'Payload', isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(height: 10),
        Row(children: [
          _qosDropdown(_pubQos, (v) => setState(() => _pubQos = v ?? MqttQos.atLeastOnce)),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
              onPressed: _connected ? _publish : null,
              child: const Text('Publish'),
            ),
          ),
        ]),
        Row(children: [
          Checkbox(value: _retain, onChanged: (v) => setState(() => _retain = v ?? false)),
          Text('Retain', style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textSecondary)),
        ]),
      ]),
    );
  }

  Widget _logRow(_MqttLogLine l) {
    final dotColor = l.isError ? AppColors.error : (l.isOutgoing ? AppColors.accent : AppColors.success);
    final h = l.time.hour.toString().padLeft(2, '0');
    final m = l.time.minute.toString().padLeft(2, '0');
    final s = l.time.second.toString().padLeft(2, '0');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.black.withValues(alpha: 0.05))),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 8, height: 8,
          margin: const EdgeInsets.only(top: 5),
          decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(l.text,
              style: GoogleFonts.robotoMono(fontSize: 12.5, height: 1.4, color: AppColors.textPrimary)),
        ),
        const SizedBox(width: 8),
        Text('$h:$m:$s', style: GoogleFonts.inter(fontSize: 10.5, color: AppColors.textSecondary)),
      ]),
    );
  }

  Widget _liveMessagesHeader() {
    return Row(children: [
      _sectionTitle('Live Messages'),
      const SizedBox(width: 8),
      if (_log.isNotEmpty)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text('${_log.length}',
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary)),
        ),
      const Spacer(),
      if (_log.isNotEmpty)
        TextButton.icon(
          onPressed: () => setState(() => _log.clear()),
          icon: const Icon(Icons.delete_outline_rounded, size: 16),
          label: const Text('Clear'),
          style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
        ),
    ]);
  }

  Widget _liveMessagesBody() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      clipBehavior: Clip.antiAlias,
      child: _log.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(20),
              child: Text('Connect and subscribe to see messages here…',
                  style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12.5)),
            )
          : ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: _log.length,
              itemBuilder: (context, i) => _logRow(_log[i]),
            ),
    );
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
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= _wideBreakpoint;
          final controls = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _brokerCard(),
            const SizedBox(height: 14),
            _subscribeCard(),
            const SizedBox(height: 14),
            _publishCard(),
          ]);

          if (isWide) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(
                  width: 420,
                  height: constraints.maxHeight - 40,
                  child: SingleChildScrollView(child: controls),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: SizedBox(
                    height: constraints.maxHeight - 40,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _liveMessagesHeader(),
                      const SizedBox(height: 8),
                      Expanded(child: _liveMessagesBody()),
                    ]),
                  ),
                ),
              ]),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              controls,
              const SizedBox(height: 14),
              _liveMessagesHeader(),
              const SizedBox(height: 8),
              SizedBox(height: 340, child: _liveMessagesBody()),
              const SizedBox(height: 20),
            ]),
          );
        },
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
