import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mqtt_client/mqtt_client.dart';
import '../../constants/app_colors.dart';
import 'mqtt_connect.dart';
import 'ota_firmware_sketch.dart';

/// Public, no-login OTA updater — connects to an MQTT broker over secure
/// WebSocket and tells a device to update itself: publishes
/// `{url, version, sha256}` to `<base>/ota/cmd`, then shows the device's
/// progress from `<base>/ota/status` (`{state, progress, version, msg}`).
/// The device downloads the .bin itself over HTTPS, so this works from an
/// https page (a direct browser→device HTTP push would be blocked as mixed
/// content). Alternatively the .bin can be uploaded straight from the browser:
/// it is streamed to the device in acknowledged chunks over MQTT
/// (`<base>/ota/data` out, `<base>/ota/ack` back), so nothing needs hosting.
/// Pair it with the sketch from [otaFirmwareSketch].
class OtaUpdaterScreen extends StatefulWidget {
  const OtaUpdaterScreen({super.key});

  @override
  State<OtaUpdaterScreen> createState() => _OtaUpdaterScreenState();
}

class _OtaLogLine {
  final String text;
  final DateTime time;
  final bool isError;
  final bool isOutgoing;
  _OtaLogLine(this.text, this.time, {this.isError = false, this.isOutgoing = false});
}

class _OtaUpdaterScreenState extends State<OtaUpdaterScreen> {
  static const _presetBrokers = [
    ('HiveMQ (public)', 'wss://broker.hivemq.com/mqtt', '8884'),
    ('Mosquitto (public)', 'wss://test.mosquitto.org', '8081'),
    ('EMQX (public)', 'wss://broker.emqx.io/mqtt', '8084'),
  ];

  final _hostCtrl = TextEditingController(text: 'wss://broker.hivemq.com/mqtt');
  final _portCtrl = TextEditingController(text: '8884');
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _baseCtrl = TextEditingController(text: 'altrobyte/device1');
  final _urlCtrl = TextEditingController();
  final _versionCtrl = TextEditingController();
  final _shaCtrl = TextEditingController();

  MqttClient? _client;
  bool _connecting = false;
  bool get _connected => _client?.connectionStatus?.state == MqttConnectionState.connected;
  final List<_OtaLogLine> _log = [];

  // Firmware source: a hosted https URL the device downloads, or a file
  // picked here and streamed to the device over MQTT.
  bool _uploadMode = true;
  String? _fileName;
  Uint8List? _fileBytes;
  bool _uploading = false;
  bool _cancelUpload = false;
  Completer<String>? _ackWaiter;
  static const _chunkSize = 8192;

  String _state = 'unknown';
  int _progress = 0;
  String _deviceVersion = '—';
  String _deviceMsg = '';

  static String _normalizeHost(String raw) {
    final host = raw.trim();
    if (host.isEmpty) return 'wss://broker.hivemq.com/mqtt';
    if (host.startsWith('ws://') || host.startsWith('wss://')) return host;
    return 'wss://$host';
  }

  String get _base => _baseCtrl.text.trim().replaceAll(RegExp(r'/+$'), '');
  String get _cmdTopic => '$_base/ota/cmd';
  String get _statusTopic => '$_base/ota/status';
  String get _dataTopic => '$_base/ota/data';
  String get _ackTopic => '$_base/ota/ack';

  void _addLog(String text, {bool isError = false, bool isOutgoing = false}) {
    if (!mounted) return;
    setState(() {
      _log.insert(0, _OtaLogLine(text, DateTime.now(), isError: isError, isOutgoing: isOutgoing));
      if (_log.length > 100) _log.removeLast();
    });
  }

  Future<void> _connect() async {
    if (_connecting || _connected) return;
    final host = _normalizeHost(_hostCtrl.text);
    final port = int.tryParse(_portCtrl.text.trim()) ?? 8884;
    if (_base.isEmpty) {
      _addLog('Enter a base topic first', isError: true);
      return;
    }
    setState(() => _connecting = true);
    final clientId = 'altrobytelab_ota_${DateTime.now().millisecondsSinceEpoch}';
    final client = wsMqttClient(host, clientId)
      ..port = port
      ..keepAlivePeriod = 20
      ..connectTimeoutPeriod = 8000
      ..logging(on: false);
    client.onDisconnected = () {
      _addLog('Disconnected', isError: true);
      if (mounted) setState(() {});
    };
    var msg = MqttConnectMessage().withClientIdentifier(clientId).startClean();
    if (_userCtrl.text.trim().isNotEmpty) {
      msg = msg.authenticateAs(_userCtrl.text.trim(), _passCtrl.text);
    }
    client.connectionMessage = msg;
    try {
      await client.connect();
      _client = client;
      client.updates?.listen(_onMessage);
      client.subscribe(_statusTopic, MqttQos.atLeastOnce);
      client.subscribe(_ackTopic, MqttQos.atLeastOnce);
      _addLog('Connected to $host:$port — listening on $_statusTopic');
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

  void _onMessage(List<MqttReceivedMessage<MqttMessage?>> events) {
    for (final e in events) {
      final pub = e.payload as MqttPublishMessage;
      final raw = MqttPublishPayload.bytesToStringAsString(pub.payload.message);
      if (e.topic == _ackTopic) {
        final w = _ackWaiter;
        if (w != null && !w.isCompleted) w.complete(raw.trim());
        continue;
      }
      try {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        setState(() {
          _state = '${j['state'] ?? 'unknown'}';
          _progress = ((j['progress'] as num?) ?? _progress).toInt().clamp(0, 100);
          _deviceVersion = '${j['version'] ?? _deviceVersion}';
          _deviceMsg = '${j['msg'] ?? ''}';
        });
        _addLog('Device: $_state $_progress%${_deviceMsg.isEmpty ? '' : ' — $_deviceMsg'}',
            isError: _state == 'failed');
      } catch (_) {
        _addLog('${e.topic}  →  $raw');
      }
    }
  }

  Future<void> _pickFile() async {
    final res = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['bin'],
      withData: true,
    );
    final f = res?.files.single;
    if (f == null || f.bytes == null) return;
    setState(() {
      _fileName = f.name;
      _fileBytes = f.bytes;
    });
    _addLog('Selected ${f.name} (${(f.bytes!.length / 1024).toStringAsFixed(1)} KB)');
  }

  /// Waits for the next message on the ack topic; null on timeout.
  Future<String?> _nextAck(Duration timeout) async {
    final waiter = _ackWaiter = Completer<String>();
    try {
      return await waiter.future.timeout(timeout);
    } on TimeoutException {
      return null;
    }
  }

  void _publishBytes(String topic, Uint8List bytes) {
    final b = MqttClientPayloadBuilder();
    for (final v in bytes) {
      b.addByte(v);
    }
    _client!.publishMessage(topic, MqttQos.atLeastOnce, b.payload!);
  }

  void _failUpload(String msg) {
    _addLog(msg, isError: true);
    if (mounted) {
      setState(() {
        _uploading = false;
        _state = 'failed';
        _deviceMsg = msg;
      });
    }
  }

  Future<void> _sendUpload() async {
    final bytes = _fileBytes;
    if (!_connected || bytes == null || _uploading) return;
    setState(() {
      _uploading = true;
      _cancelUpload = false;
      _state = 'sent';
      _progress = 0;
      _deviceMsg = '';
    });
    final cmd = jsonEncode({
      'mode': 'mqtt',
      'size': bytes.length,
      'version': _versionCtrl.text.trim(),
    });
    final ready = _nextAck(const Duration(seconds: 15));
    _client!.publishMessage(_cmdTopic, MqttQos.atLeastOnce, (MqttClientPayloadBuilder()..addString(cmd)).payload!);
    _addLog('$_cmdTopic  ←  $cmd', isOutgoing: true);
    if (await ready != 'ready') {
      return _failUpload('Device did not answer — is it online and running the OTA sketch on this topic?');
    }
    final total = (bytes.length / _chunkSize).ceil();
    for (var seq = 0; seq < total; seq++) {
      if (_cancelUpload) return _failUpload('Cancelled');
      final start = seq * _chunkSize;
      final end = (start + _chunkSize).clamp(0, bytes.length);
      final chunk = Uint8List(4 + end - start)
        ..[0] = (seq >> 24) & 0xff
        ..[1] = (seq >> 16) & 0xff
        ..[2] = (seq >> 8) & 0xff
        ..[3] = seq & 0xff
        ..setRange(4, 4 + end - start, bytes, start);
      var acked = false;
      for (var attempt = 0; attempt < 5 && !acked; attempt++) {
        if (!_connected) return _failUpload('Connection lost during upload');
        final ack = _nextAck(const Duration(seconds: 4));
        _publishBytes(_dataTopic, chunk);
        final v = int.tryParse(await ack ?? '');
        acked = v != null && v >= seq;
      }
      if (!acked) return _failUpload('Device stopped acknowledging at chunk ${seq + 1}/$total');
      if (mounted) {
        setState(() {
          _state = 'uploading';
          _progress = ((seq + 1) * 100 / total).floor();
        });
      }
    }
    _addLog('All $total chunks sent — device is verifying and flashing');
    if (mounted) setState(() => _uploading = false);
  }

  void _sendUpdate() {
    final url = _urlCtrl.text.trim();
    if (!_connected) return;
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      _addLog('Firmware URL must be a valid https:// link to a .bin file', isError: true);
      return;
    }
    final payload = jsonEncode({
      'url': url,
      'version': _versionCtrl.text.trim(),
      if (_shaCtrl.text.trim().isNotEmpty) 'sha256': _shaCtrl.text.trim().toLowerCase(),
    });
    final builder = MqttClientPayloadBuilder()..addString(payload);
    _client!.publishMessage(_cmdTopic, MqttQos.atLeastOnce, builder.payload!);
    setState(() {
      _state = 'sent';
      _progress = 0;
    });
    _addLog('$_cmdTopic  ←  $payload', isOutgoing: true);
  }

  void _showSketch() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('ESP32 OTA sketch', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: SizedBox(
          width: 640,
          child: SingleChildScrollView(
            child: SelectableText(otaFirmwareSketch.trim(),
                style: GoogleFonts.robotoMono(fontSize: 11.5)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: otaFirmwareSketch.trim()));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sketch copied')));
            },
            child: const Text('Copy'),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _cancelUpload = true;
    _client?.disconnect();
    for (final c in [_hostCtrl, _portCtrl, _userCtrl, _passCtrl, _baseCtrl, _urlCtrl, _versionCtrl, _shaCtrl]) {
      c.dispose();
    }
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

  InputDecoration _dec(String label, {String? hint}) => InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        isDense: true,
      );

  Widget _title(String t) => Text(t, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14));

  Widget _brokerCard() => _card(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            _title('Broker'),
            const Spacer(),
            Icon(Icons.circle, size: 8, color: _connected ? AppColors.success : Colors.grey),
            const SizedBox(width: 6),
            Text(_connected ? 'Connected' : 'Disconnected',
                style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _presetBrokers
                .map((b) => ActionChip(
                      label: Text(b.$1, style: GoogleFonts.inter(fontSize: 11.5)),
                      onPressed: _connected
                          ? null
                          : () => setState(() {
                                _hostCtrl.text = b.$2;
                                _portCtrl.text = b.$3;
                              }),
                    ))
                .toList(),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                flex: 3,
                child: TextField(controller: _hostCtrl, enabled: !_connected, decoration: _dec('WebSocket URL'))),
            const SizedBox(width: 10),
            Expanded(
                child: TextField(
                    controller: _portCtrl,
                    enabled: !_connected,
                    keyboardType: TextInputType.number,
                    decoration: _dec('Port'))),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(controller: _userCtrl, enabled: !_connected, decoration: _dec('Username (optional)'))),
            const SizedBox(width: 10),
            Expanded(
                child: TextField(
                    controller: _passCtrl, enabled: !_connected, obscureText: true, decoration: _dec('Password'))),
          ]),
          const SizedBox(height: 10),
          TextField(
            controller: _baseCtrl,
            enabled: !_connected,
            decoration: _dec('Device base topic', hint: 'altrobyte/device1'),
          ),
          const SizedBox(height: 4),
          Text('Commands go to <base>/ota/cmd, status comes from <base>/ota/status.',
              style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: _connected
                ? OutlinedButton(onPressed: _disconnect, child: const Text('Disconnect'))
                : ElevatedButton(
                    onPressed: _connecting ? null : _connect,
                    child: Text(_connecting ? 'Connecting…' : 'Connect'),
                  ),
          ),
        ]),
      );

  Widget _updateCard() => _card(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _title('Firmware'),
          const SizedBox(height: 12),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('Upload .bin'), icon: Icon(Icons.upload_file_rounded, size: 18)),
              ButtonSegment(value: false, label: Text('From URL'), icon: Icon(Icons.link_rounded, size: 18)),
            ],
            selected: {_uploadMode},
            onSelectionChanged: _uploading ? null : (v) => setState(() => _uploadMode = v.first),
          ),
          const SizedBox(height: 12),
          if (_uploadMode) ...[
            OutlinedButton.icon(
              onPressed: _uploading ? null : _pickFile,
              icon: const Icon(Icons.folder_open_rounded, size: 18),
              label: Text(_fileName == null
                  ? 'Choose firmware .bin'
                  : '$_fileName  (${(_fileBytes!.length / 1024).toStringAsFixed(1)} KB)'),
            ),
            const SizedBox(height: 4),
            Text(
                'Streamed to the device in ${_chunkSize ~/ 1024} KB chunks over MQTT — no hosting needed. Use the app binary from '
                '"Export Compiled Binary" (not the bootloader/merged file). Takes about a minute for 1 MB.',
                style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
            const SizedBox(height: 10),
            TextField(controller: _versionCtrl, decoration: _dec('Version', hint: '1.1.0')),
          ] else ...[
            TextField(
                controller: _urlCtrl,
                decoration: _dec('Firmware .bin URL (https)', hint: 'https://example.com/firmware-1.1.0.bin')),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextField(controller: _versionCtrl, decoration: _dec('Version', hint: '1.1.0'))),
              const SizedBox(width: 10),
              Expanded(flex: 2, child: TextField(controller: _shaCtrl, decoration: _dec('SHA256 (optional)'))),
            ]),
            const SizedBox(height: 4),
            Text('The URL must be https and allow direct download. The device fetches it — this page never uploads the file.',
                style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
          ],
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: _uploading
                  ? OutlinedButton.icon(
                      onPressed: () => setState(() => _cancelUpload = true),
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: const Text('Cancel upload'),
                    )
                  : ElevatedButton.icon(
                      onPressed: !_connected || (_uploadMode && _fileBytes == null)
                          ? null
                          : (_uploadMode ? _sendUpload : _sendUpdate),
                      icon: const Icon(Icons.system_update_alt_rounded, size: 18),
                      label: Text(_uploadMode ? 'Upload & update' : 'Send update'),
                    ),
            ),
            const SizedBox(width: 10),
            OutlinedButton.icon(
              onPressed: _showSketch,
              icon: const Icon(Icons.code_rounded, size: 18),
              label: const Text('Get firmware sketch'),
            ),
          ]),
        ]),
      );

  Widget _statusCard() {
    final failed = _state == 'failed';
    final done = _state == 'done';
    final color = failed ? AppColors.error : (done ? AppColors.success : AppColors.primary);
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _title('Device status'),
          const Spacer(),
          Text('v$_deviceVersion', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
        ]),
        const SizedBox(height: 12),
        Text(_state.toUpperCase(),
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16, color: color)),
        if (_deviceMsg.isNotEmpty)
          Text(_deviceMsg, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
              value: _progress / 100, minHeight: 10, color: color, backgroundColor: color.withValues(alpha: 0.12)),
        ),
        const SizedBox(height: 4),
        Text('$_progress%', style: GoogleFonts.inter(fontSize: 11.5)),
      ]),
    );
  }

  Widget _logCard() => _card(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _title('Log'),
          const SizedBox(height: 8),
          SizedBox(
            height: 240,
            child: _log.isEmpty
                ? Center(
                    child: Text('Connect, then send an update.',
                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)))
                : ListView.builder(
                    itemCount: _log.length,
                    itemBuilder: (_, i) {
                      final l = _log[i];
                      final t = l.time;
                      String two(int n) => n.toString().padLeft(2, '0');
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: SelectableText(
                          '${two(t.hour)}:${two(t.minute)}:${two(t.second)}  ${l.text}',
                          style: GoogleFonts.robotoMono(
                            fontSize: 11.5,
                            color: l.isError
                                ? AppColors.error
                                : (l.isOutgoing ? AppColors.primary : AppColors.textPrimary),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 900;
    final left = Column(children: [_brokerCard(), const SizedBox(height: 12), _updateCard()]);
    final right = Column(children: [_statusCard(), const SizedBox(height: 12), _logCard()]);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text('OTA Updater',
            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: wide
            ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: left),
                const SizedBox(width: 16),
                Expanded(child: right),
              ])
            : Column(children: [left, const SizedBox(height: 12), right]),
      ),
    );
  }
}
