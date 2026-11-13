// The BLE tool in the phone app (13 Nov 2026, founder: "the mobile app is for the Bluetooth experience in the dev tool").
// Native Bluetooth Low Energy through universal_ble (BSD licence): scan for boards nearby, connect, see every service and
// characteristic, read, write (text or hex), and watch notifications live. The browser's tool (ble_tester_screen.dart,
// Web Bluetooth) stays for the website.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:universal_ble/universal_ble.dart';

import '../../constants/app_colors.dart';

/// Names for the UUIDs a learner meets first, so the list reads like the lesson and not like a row of hex.
const bleNames = <String, String>{
  '1800': 'Generic Access', '1801': 'Generic Attribute', '180a': 'Device Information', '180f': 'Battery',
  '180d': 'Heart Rate', '181a': 'Environmental Sensing', '1809': 'Health Thermometer',
  '2a00': 'Device Name', '2a01': 'Appearance', '2a19': 'Battery Level', '2a29': 'Manufacturer Name',
  '2a24': 'Model Number', '2a26': 'Firmware Revision', '2a6e': 'Temperature', '2a6f': 'Humidity', '2a37': 'Heart Rate Measurement',
  '6e400001-b5a3-f393-e0a9-e50e24dcca9e': 'UART service (Nordic)',
  '6e400002-b5a3-f393-e0a9-e50e24dcca9e': 'UART RX (write here)',
  '6e400003-b5a3-f393-e0a9-e50e24dcca9e': 'UART TX (notifies)',
};

/// "Battery Level" for 00002a19-0000-1000-8000-00805f9b34fb, the short 16-bit form for other standard UUIDs, else the UUID.
String bleLabel(String uuid) {
  final u = uuid.toLowerCase();
  final short = RegExp(r'^0000([0-9a-f]{4})-0000-1000-8000-00805f9b34fb$').firstMatch(u)?.group(1);
  final name = bleNames[short ?? u];
  if (name != null) return name;
  return short != null ? '0x${short.toUpperCase()}' : u;
}

/// Bytes as a learner wants to see them: the text when it is printable, and always the hex.
String bleShow(List<int> bytes) {
  if (bytes.isEmpty) return '(empty)';
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
  final printable = bytes.every((b) => b == 10 || b == 13 || (b >= 32 && b < 127));
  if (!printable) return hex;
  return '"${utf8.decode(bytes, allowMalformed: true).trim()}"  ·  $hex';
}

/// What was typed, as bytes: text as UTF-8, or hex ("0A ff 01", "0x0A,0xFF"). Null when the hex is not valid.
Uint8List? bleBytes(String typed, {required bool hex}) {
  if (!hex) return Uint8List.fromList(utf8.encode(typed));
  final clean = typed.replaceAll(RegExp(r'0x|[\s,:-]', caseSensitive: false), '');
  if (clean.isEmpty || clean.length.isOdd || !RegExp(r'^[0-9a-fA-F]+$').hasMatch(clean)) return null;
  return Uint8List.fromList([for (var i = 0; i < clean.length; i += 2) int.parse(clean.substring(i, i + 2), radix: 16)]);
}

class BleTesterScreen extends StatefulWidget {
  const BleTesterScreen({super.key});
  @override
  State<BleTesterScreen> createState() => _BleTesterScreenState();
}

class _Line {
  final String time, text;
  final bool error;
  _Line(this.text, this.error) : time = TimeOfDay.now().toString().substring(10, 15);
}

class _BleTesterScreenState extends State<BleTesterScreen> {
  final _found = <String, BleDevice>{};
  final _log = <_Line>[];
  final _write = TextEditingController(text: 'ON');
  final _subs = <StreamSubscription>[];
  final _notifying = <String, StreamSubscription>{};
  StreamSubscription? _scanSub, _linkSub;
  Timer? _scanStop;
  bool _scanning = false, _namedOnly = true, _busy = false, _hex = false;
  BleDevice? _device;
  List<BleService> _services = [];
  String? _problem;

  @override
  void dispose() {
    _scanStop?.cancel();
    _scanSub?.cancel();
    _linkSub?.cancel();
    for (final s in [..._subs, ..._notifying.values]) {
      s.cancel();
    }
    final d = _device;
    if (d != null) UniversalBle.disconnect(d.deviceId).catchError((_) {});
    UniversalBle.stopScan().catchError((_) {});
    _write.dispose();
    super.dispose();
  }

  void _say(String text, {bool error = false}) {
    if (!mounted) return;
    setState(() {
      _log.insert(0, _Line(text, error));
      if (_log.length > 200) _log.removeLast();
    });
  }

  /// Words a learner can act on, for the errors Bluetooth gives; the technical line still goes to the log.
  String _plain(Object e) {
    final t = e.toString().toLowerCase();
    if (t.contains('permission') || t.contains('unauthor')) return 'Bluetooth permission is needed. Allow "Nearby devices" for this app.';
    if (t.contains('timeout') || t.contains('timed out')) return 'The board did not answer in time. Keep it close and powered, then try again.';
    if (t.contains('not connected') || t.contains('disconnected')) return 'The board is not connected any more.';
    return 'That did not work. Check the board is on and close by.';
  }

  Future<bool> _ready() async {
    try {
      if (!await UniversalBle.hasPermissions()) await UniversalBle.requestPermissions();
      if (!await UniversalBle.hasPermissions()) {
        setState(() => _problem = 'Allow "Nearby devices" (Bluetooth) for this app, then tap Scan again.');
        return false;
      }
      var state = await UniversalBle.getBluetoothAvailabilityState();
      if (state == AvailabilityState.poweredOff) {
        await UniversalBle.enableBluetooth().catchError((_) => false);
        state = await UniversalBle.getBluetoothAvailabilityState();
      }
      if (state == AvailabilityState.unsupported) {
        setState(() => _problem = 'This phone has no Bluetooth Low Energy.');
        return false;
      }
      if (state != AvailabilityState.poweredOn) {
        setState(() => _problem = 'Turn Bluetooth on, then tap Scan again.');
        return false;
      }
      setState(() => _problem = null);
      return true;
    } catch (e) {
      _say('Bluetooth check: $e', error: true);
      setState(() => _problem = _plain(e));
      return false;
    }
  }

  Future<void> _scan() async {
    if (_scanning) return _stopScan();
    if (!await _ready()) return;
    setState(() { _found.clear(); _scanning = true; });
    _scanSub?.cancel();
    _scanSub = UniversalBle.scanStream.listen((d) {
      if (!mounted) return;
      setState(() => _found[d.deviceId] = d);
    });
    try {
      await UniversalBle.startScan();
      _say('Scanning for 12 seconds…');
      _scanStop?.cancel();
      _scanStop = Timer(const Duration(seconds: 12), _stopScan);
    } catch (e) {
      _say('Scan: $e', error: true);
      setState(() { _scanning = false; _problem = _plain(e); });
    }
  }

  Future<void> _stopScan() async {
    _scanStop?.cancel();
    try { await UniversalBle.stopScan(); } catch (_) {}
    if (mounted && _scanning) {
      setState(() => _scanning = false);
      _say('Scan finished: ${_found.length} device${_found.length == 1 ? '' : 's'} seen.');
    }
  }

  Future<void> _connect(BleDevice d) async {
    if (_busy) return;
    await _stopScan();
    final name = _nameOf(d);
    setState(() { _busy = true; _problem = null; });
    _say('Connecting to $name…');
    try {
      await UniversalBle.connect(d.deviceId, timeout: const Duration(seconds: 20));
      final services = await UniversalBle.discoverServices(d.deviceId);
      _linkSub?.cancel();
      _linkSub = UniversalBle.connectionStream(d.deviceId).listen((on) {
        if (!on && mounted && _device?.deviceId == d.deviceId) {
          _say('$name disconnected.', error: true);
          _forget();
        }
      });
      if (!mounted) return;
      setState(() { _device = d; _services = services; });
      final chars = services.fold<int>(0, (n, s) => n + s.characteristics.length);
      _say('Connected. ${services.length} services, $chars characteristics.');
    } catch (e) {
      _say('Connect: $e', error: true);
      if (mounted) setState(() => _problem = _plain(e));
      UniversalBle.disconnect(d.deviceId).catchError((_) {});
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _forget() {
    for (final s in _notifying.values) {
      s.cancel();
    }
    _notifying.clear();
    if (mounted) setState(() { _device = null; _services = []; });
  }

  Future<void> _disconnect() async {
    final d = _device;
    if (d == null) return;
    _linkSub?.cancel();
    try { await UniversalBle.disconnect(d.deviceId); } catch (_) {}
    _say('Disconnected from ${_nameOf(d)}.');
    _forget();
  }

  Future<void> _read(BleService s, BleCharacteristic c) async {
    try {
      final v = await UniversalBle.read(_device!.deviceId, s.uuid, c.uuid);
      _say('READ ${bleLabel(c.uuid)}: ${bleShow(v)}');
    } catch (e) {
      _say('Read ${bleLabel(c.uuid)}: ${_plain(e)}  [$e]', error: true);
    }
  }

  Future<void> _send(BleService s, BleCharacteristic c) async {
    final bytes = bleBytes(_write.text, hex: _hex);
    if (bytes == null) return _say('That is not valid hex. Write pairs like 0A FF 01.', error: true);
    try {
      final noAnswer = !c.properties.contains(CharacteristicProperty.write) && c.properties.contains(CharacteristicProperty.writeWithoutResponse);
      await UniversalBle.write(_device!.deviceId, s.uuid, c.uuid, bytes, withoutResponse: noAnswer);
      _say('WRITE ${bleLabel(c.uuid)}: ${bleShow(bytes)}');
    } catch (e) {
      _say('Write ${bleLabel(c.uuid)}: ${_plain(e)}  [$e]', error: true);
    }
  }

  Future<void> _notify(BleService s, BleCharacteristic c) async {
    final id = _device!.deviceId, key = '${s.uuid}/${c.uuid}';
    try {
      if (_notifying.containsKey(key)) {
        await UniversalBle.unsubscribe(id, s.uuid, c.uuid);
        _notifying.remove(key)?.cancel();
        _say('Stopped listening to ${bleLabel(c.uuid)}.');
      } else {
        _notifying[key] = UniversalBle.characteristicValueStream(id, c.uuid).listen((v) => _say('NOTIFY ${bleLabel(c.uuid)}: ${bleShow(v)}'));
        if (c.properties.contains(CharacteristicProperty.notify)) {
          await UniversalBle.subscribeNotifications(id, s.uuid, c.uuid);
        } else {
          await UniversalBle.subscribeIndications(id, s.uuid, c.uuid);
        }
        _say('Listening to ${bleLabel(c.uuid)}. New values appear here.');
      }
      if (mounted) setState(() {});
    } catch (e) {
      _notifying.remove(key)?.cancel();
      _say('Notify ${bleLabel(c.uuid)}: ${_plain(e)}  [$e]', error: true);
    }
  }

  String _nameOf(BleDevice d) => (d.name ?? '').trim().isEmpty ? 'Unnamed device' : d.name!.trim();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Text(_device == null ? 'BLE Tester' : _nameOf(_device!), style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
        actions: [
          if (_device != null) TextButton(onPressed: _disconnect, child: const Text('Disconnect', style: TextStyle(color: Colors.white))),
        ],
      ),
      body: Column(children: [
        if (_problem != null)
          Container(
            width: double.infinity, color: const Color(0xFFFFF3E0), padding: const EdgeInsets.all(12),
            child: Text(_problem!, style: GoogleFonts.inter(fontSize: 13.5, color: const Color(0xFF8A4B00))),
          ),
        Expanded(flex: 3, child: _device == null ? _scanList() : _serviceList()),
        _console(),
      ]),
    );
  }

  Widget _scanList() {
    final list = _found.values.where((d) => !_namedOnly || (d.name ?? '').trim().isNotEmpty).toList()
      ..sort((a, b) => (b.rssi ?? -999).compareTo(a.rssi ?? -999));
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
        child: Row(children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: _busy ? null : _scan,
              style: FilledButton.styleFrom(backgroundColor: _scanning ? Colors.grey.shade700 : AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 13)),
              icon: _scanning ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.bluetooth_searching_rounded),
              label: Text(_scanning ? 'Stop scanning' : 'Scan for devices', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(width: 8),
          FilterChip(label: const Text('Named only'), selected: _namedOnly, onSelected: (v) => setState(() => _namedOnly = v)),
        ]),
      ),
      Expanded(
        child: list.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _scanning ? 'Looking for boards nearby…' : 'Power your ESP32 or any BLE board, keep it close, and tap Scan.',
                    textAlign: TextAlign.center, style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 14),
                  ),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final d = list[i], rssi = d.rssi;
                  return Material(
                    color: Colors.white, borderRadius: BorderRadius.circular(14),
                    child: ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: Colors.grey.shade200)),
                      leading: Icon(Icons.bluetooth_rounded, color: AppColors.accent),
                      title: Text(_nameOf(d), style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14.5)),
                      subtitle: Text(d.deviceId, style: GoogleFonts.robotoMono(fontSize: 11.5, color: AppColors.textSecondary)),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        if (rssi != null) Text('$rssi dBm', style: GoogleFonts.inter(fontSize: 12, color: rssi > -65 ? Colors.green.shade700 : rssi > -80 ? Colors.orange.shade800 : Colors.red.shade700)),
                        const SizedBox(width: 8),
                        const Icon(Icons.chevron_right_rounded),
                      ]),
                      onTap: _busy ? null : () => _connect(d),
                    ),
                  );
                },
              ),
      ),
    ]);
  }

  Widget _serviceList() {
    return ListView(padding: const EdgeInsets.fromLTRB(14, 12, 14, 12), children: [
      Row(children: [
        Expanded(
          child: TextField(
            controller: _write,
            style: GoogleFonts.robotoMono(fontSize: 14),
            decoration: InputDecoration(
              isDense: true, filled: true, fillColor: Colors.white, labelText: _hex ? 'Value to write (hex: 0A FF)' : 'Value to write (text)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        ChoiceChip(label: Text(_hex ? 'HEX' : 'TEXT'), selected: _hex, onSelected: (v) => setState(() => _hex = v)),
      ]),
      const SizedBox(height: 10),
      for (final s in _services) ...[
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 6),
          child: Text('SERVICE · ${bleLabel(s.uuid)}', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: .6, color: AppColors.textSecondary)),
        ),
        for (final c in s.characteristics) _charCard(s, c),
      ],
      if (_services.isEmpty) Padding(padding: const EdgeInsets.all(20), child: Text('This device shows no services.', style: GoogleFonts.inter(color: AppColors.textSecondary))),
    ]);
  }

  Widget _charCard(BleService s, BleCharacteristic c) {
    final p = c.properties, on = _notifying.containsKey('${s.uuid}/${c.uuid}');
    final canRead = p.contains(CharacteristicProperty.read);
    final canWrite = p.contains(CharacteristicProperty.write) || p.contains(CharacteristicProperty.writeWithoutResponse);
    final canNotify = p.contains(CharacteristicProperty.notify) || p.contains(CharacteristicProperty.indicate);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.grey.shade200)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(bleLabel(c.uuid), style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
        GestureDetector(
          onLongPress: () { Clipboard.setData(ClipboardData(text: c.uuid)); _say('Copied ${c.uuid}'); },
          child: Text(c.uuid, style: GoogleFonts.robotoMono(fontSize: 10.5, color: AppColors.textSecondary)),
        ),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 4, children: [
          if (canRead) OutlinedButton(onPressed: () => _read(s, c), child: const Text('Read')),
          if (canWrite) OutlinedButton(onPressed: () => _send(s, c), child: const Text('Write')),
          if (canNotify) FilledButton.tonal(onPressed: () => _notify(s, c), child: Text(on ? 'Stop' : 'Notify')),
          if (!canRead && !canWrite && !canNotify) Text('No read, write or notify', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
        ]),
      ]),
    );
  }

  Widget _console() {
    return Container(
      height: 190, width: double.infinity, color: const Color(0xFF0F1B2B),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 4, 0),
          child: Row(children: [
            Text('LOG', style: GoogleFonts.inter(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
            const Spacer(),
            TextButton(onPressed: () => setState(_log.clear), child: const Text('Clear', style: TextStyle(color: Colors.white70, fontSize: 12))),
          ]),
        ),
        Expanded(
          child: _log.isEmpty
              ? Center(child: Text('What you read, write and receive shows here.', style: GoogleFonts.inter(color: Colors.white38, fontSize: 12.5)))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                  itemCount: _log.length,
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text('${_log[i].time}  ${_log[i].text}', style: GoogleFonts.robotoMono(fontSize: 12, height: 1.35, color: _log[i].error ? const Color(0xFFFF9A9A) : const Color(0xFF7EE2A8))),
                  ),
                ),
        ),
      ]),
    );
  }
}
