import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';
import 'package:web/web.dart' as web;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';

/// Public, no-login Web Bluetooth (BLE) tester — scan for a real nearby
/// device (ESP32 etc.), connect, browse its GATT services/characteristics,
/// read/write/subscribe. Uses the browser's native Web Bluetooth API via
/// modern dart:js_interop (Web Bluetooth isn't part of package:web's
/// typed bindings since it's non-standard, so property/method access is
/// unsafe/dynamic).
class BleTesterScreen extends StatefulWidget {
  final String? initialServiceUuids;
  const BleTesterScreen({super.key, this.initialServiceUuids});

  @override
  State<BleTesterScreen> createState() => _BleTesterScreenState();
}

class _BleLogLine {
  final String text;
  final DateTime time;
  final bool isError;
  _BleLogLine(this.text, this.time, {this.isError = false});
}

class _BleTesterScreenState extends State<BleTesterScreen> {
  // Web Bluetooth only lets a page see services it declared upfront here —
  // there's no way to ask for "all services" (a deliberate browser privacy
  // restriction), so getPrimaryServices() throws "NotFoundError: No
  // Services found" for anything not listed. Defaults cover the most
  // common ESP32 BLE tutorial/example sketches so "Scan & Connect" works
  // out of the box for most workshop firmware without editing this field —
  // 4fafc201... is the single most copy-pasted ESP32 Arduino BLE_server
  // example UUID online, 6e400001... is Nordic UART Service (serial-over-
  // BLE tutorials), 0000ffe0... is the common HM-10 module UUID.
  late final _servicesCtrl = TextEditingController(
      text: widget.initialServiceUuids ??
          '4fafc201-1fb5-459e-8fcc-c5c9c331914b, 6e400001-b5a3-f393-e0a9-e50e24dcca9e, '
              '0000ffe0-0000-1000-8000-00805f9b34fb, battery_service, device_information, '
              'generic_access, generic_attribute');
  final _writeCtrl = TextEditingController(text: 'Hello ESP32');
  String _writeFormat = 'Text (UTF-8)';
  static const _writeFormats = ['Text (UTF-8)', 'Hex', 'Int8', 'Int16', 'Int32', 'Float32'];

  bool get _supported => web.window.navigator.hasProperty('bluetooth'.toJS).toDart;

  JSObject? _device;
  List<JSObject> _services = [];
  JSObject? _selectedService;
  List<JSObject> _characteristics = [];
  JSObject? _selectedCharacteristic;
  bool _notifying = false;
  bool _connecting = false;
  String? _deviceName;
  final List<_BleLogLine> _log = [];

  void _addLog(String text, {bool isError = false}) {
    if (!mounted) return;
    setState(() {
      _log.insert(0, _BleLogLine(text, DateTime.now(), isError: isError));
      if (_log.length > 200) _log.removeLast();
    });
  }

  List<String> _serviceUuids() => _servicesCtrl.text
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  Future<JSAny?> _await(JSAny? promise) => (promise as JSPromise<JSAny?>).toDart;

  Future<void> _scanAndConnect() async {
    if (!_supported) {
      _addLog('Web Bluetooth not supported in this browser (use Chrome/Edge on desktop or Android).',
          isError: true);
      return;
    }
    setState(() => _connecting = true);
    try {
      final bluetooth = web.window.navigator.getProperty('bluetooth'.toJS) as JSObject;
      final options = {
        'acceptAllDevices': true,
        'optionalServices': _serviceUuids().map((e) => e.toJS).toList().toJS,
      }.jsify() as JSObject;

      final device = await _await(
          bluetooth.callMethod('requestDevice'.toJS, options)) as JSObject;
      _deviceName = (device.getProperty('name'.toJS) as JSString?)?.toDart ?? 'Unknown device';
      _addLog('Selected device: $_deviceName');
      // Without this, walking out of range or the device power-cycling
      // (both common mid-workshop) leaves the UI stuck showing "Connected"
      // forever — reads/writes then fail with a confusing error instead of
      // a clear "device disconnected" state.
      device.callMethod('addEventListener'.toJS, 'gattserverdisconnected'.toJS, _onUnexpectedDisconnect.toJS);

      final gatt = device.getProperty('gatt'.toJS) as JSObject;
      final server = await _await(gatt.callMethod('connect'.toJS)) as JSObject;
      _addLog('Connected to GATT server');

      final servicesJsArray = await _await(server.callMethod('getPrimaryServices'.toJS)) as JSArray;
      final services = servicesJsArray.toDart.cast<JSObject>();

      setState(() {
        _device = device;
        _services = services;
        _selectedService = services.isNotEmpty ? services.first : null;
        _characteristics = [];
        _selectedCharacteristic = null;
      });
      _addLog('Found ${services.length} service(s)');
      if (_selectedService != null) await _loadCharacteristics(_selectedService!);
    } catch (e) {
      if (e.toString().contains('No Services found')) {
        _addLog(
            "No services visible — your device's service UUID isn't in the list above. "
            'Check your firmware code for its exact Service UUID, add it to "Optional Service UUIDs", then Scan & Connect again.',
            isError: true);
      } else {
        _addLog('Connection failed or cancelled: $e', isError: true);
      }
    }
    if (mounted) setState(() => _connecting = false);
  }

  Future<void> _loadCharacteristics(JSObject service) async {
    try {
      final charsJsArray = await _await(service.callMethod('getCharacteristics'.toJS)) as JSArray;
      final chars = charsJsArray.toDart.cast<JSObject>();
      setState(() {
        _selectedService = service;
        _characteristics = chars;
        _selectedCharacteristic = chars.isNotEmpty ? chars.first : null;
        _notifying = false;
      });
      _addLog('Loaded ${chars.length} characteristic(s) for service ${_uuidOf(service)}');
    } catch (e) {
      _addLog('Failed to load characteristics: $e', isError: true);
    }
  }

  String _uuidOf(JSObject obj) => (obj.getProperty('uuid'.toJS) as JSString?)?.toDart ?? '?';

  Future<void> _read() async {
    if (_selectedCharacteristic == null) return;
    try {
      final dataView = await _await(_selectedCharacteristic!.callMethod('readValue'.toJS)) as JSObject;
      final bytes = _dataViewToBytes(dataView);
      _addLog('Read: ${_formatBytes(bytes)}');
    } catch (e) {
      _addLog('Read failed: $e', isError: true);
    }
  }

  /// Encodes the write box's text per the selected format — little-endian
  /// for numeric types, matching the convention almost all embedded/ESP32
  /// firmware uses (ARM Cortex-M, ESP32's Xtensa are both little-endian).
  /// Returns null (with a log line) if the input doesn't parse.
  Uint8List? _encodeWritePayload() {
    final input = _writeCtrl.text.trim();
    try {
      switch (_writeFormat) {
        case 'Hex':
          final clean = input.replaceAll(RegExp(r'[\s,]'), '');
          if (clean.length % 2 != 0) throw const FormatException('Odd number of hex digits');
          final bytes = Uint8List(clean.length ~/ 2);
          for (var i = 0; i < bytes.length; i++) {
            bytes[i] = int.parse(clean.substring(i * 2, i * 2 + 2), radix: 16);
          }
          return bytes;
        case 'Int8':
          final v = int.parse(input);
          return Uint8List(1)..buffer.asByteData().setInt8(0, v);
        case 'Int16':
          final v = int.parse(input);
          final b = Uint8List(2);
          b.buffer.asByteData().setInt16(0, v, Endian.little);
          return b;
        case 'Int32':
          final v = int.parse(input);
          final b = Uint8List(4);
          b.buffer.asByteData().setInt32(0, v, Endian.little);
          return b;
        case 'Float32':
          final v = double.parse(input);
          final b = Uint8List(4);
          b.buffer.asByteData().setFloat32(0, v, Endian.little);
          return b;
        default: // Text (UTF-8)
          return Uint8List.fromList(utf8.encode(input));
      }
    } catch (e) {
      _addLog('Could not encode "$input" as $_writeFormat: $e', isError: true);
      return null;
    }
  }

  Future<void> _write() async {
    if (_selectedCharacteristic == null) return;
    final bytes = _encodeWritePayload();
    if (bytes == null) return;
    try {
      await _await(_selectedCharacteristic!.callMethod('writeValue'.toJS, bytes.toJS));
      _addLog('Wrote ($_writeFormat): ${_formatBytes(bytes)}');
    } catch (e) {
      _addLog('Write failed: $e', isError: true);
    }
  }

  Future<void> _toggleNotify() async {
    if (_selectedCharacteristic == null) return;
    try {
      if (!_notifying) {
        await _await(_selectedCharacteristic!.callMethod('startNotifications'.toJS));
        _selectedCharacteristic!.callMethod(
            'addEventListener'.toJS, 'characteristicvaluechanged'.toJS, _onNotify.toJS);
        _addLog('Subscribed to notifications');
      } else {
        await _await(_selectedCharacteristic!.callMethod('stopNotifications'.toJS));
        // Without this, re-subscribing later stacks a second listener on top
        // of this one instead of replacing it — every notification after
        // that fires _onNotify twice, then three times, and so on.
        _selectedCharacteristic!.callMethod(
            'removeEventListener'.toJS, 'characteristicvaluechanged'.toJS, _onNotify.toJS);
        _addLog('Unsubscribed');
      }
      setState(() => _notifying = !_notifying);
    } catch (e) {
      _addLog('Notify toggle failed: $e', isError: true);
    }
  }

  void _onUnexpectedDisconnect(JSAny event) {
    // Manual _disconnect() already clears this and removes this listener
    // first, so if it still fires afterward this is a no-op instead of
    // double-resetting state or logging a duplicate message.
    if (!mounted || _device == null) return;
    setState(() {
      _device = null;
      _services = [];
      _selectedService = null;
      _characteristics = [];
      _selectedCharacteristic = null;
      _notifying = false;
    });
    _addLog('Device disconnected unexpectedly — out of range or powered off?', isError: true);
    _deviceName = null;
  }

  void _onNotify(JSAny event) {
    try {
      final target = (event as JSObject).getProperty('target'.toJS) as JSObject;
      final dataView = target.getProperty('value'.toJS) as JSObject;
      final bytes = _dataViewToBytes(dataView);
      _addLog('Notify: ${_formatBytes(bytes)}');
    } catch (e) {
      _addLog('Notify parse error: $e', isError: true);
    }
  }

  Uint8List _dataViewToBytes(JSObject dataView) {
    final buffer = dataView.getProperty('buffer'.toJS) as JSArrayBuffer;
    return buffer.toDart.asUint8List();
  }

  String _formatBytes(Uint8List bytes) {
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
    String text;
    try {
      text = utf8.decode(bytes);
    } catch (_) {
      text = '(binary)';
    }
    final parts = ['$text  [$hex]'];
    // Also show numeric interpretations when the length matches a common
    // sensor/actuator encoding — most industrial BLE payloads are packed
    // binary (a raw int16 ADC reading, a float32 temperature), not text.
    final bd = bytes.buffer.asByteData();
    if (bytes.length == 2) {
      parts.add('int16=${bd.getInt16(0, Endian.little)}');
    } else if (bytes.length == 4) {
      parts.add('int32=${bd.getInt32(0, Endian.little)} float32=${bd.getFloat32(0, Endian.little).toStringAsFixed(4)}');
    }
    return parts.join('  ');
  }

  void _disconnect() {
    try {
      if (_device != null) {
        _device!.callMethod(
            'removeEventListener'.toJS, 'gattserverdisconnected'.toJS, _onUnexpectedDisconnect.toJS);
        final gatt = _device!.getProperty('gatt'.toJS) as JSObject;
        gatt.callMethod('disconnect'.toJS);
      }
    } catch (_) {}
    setState(() {
      _device = null;
      _services = [];
      _selectedService = null;
      _characteristics = [];
      _selectedCharacteristic = null;
      _notifying = false;
      _deviceName = null;
    });
    _addLog('Disconnected');
  }

  @override
  void dispose() {
    _servicesCtrl.dispose();
    _writeCtrl.dispose();
    super.dispose();
  }

  bool get _connected => _device != null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Row(children: [
          const Icon(Icons.bluetooth_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Text('BLE Tester', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
        ]),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (!_supported)
              Container(
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                child: Text(
                    'Web Bluetooth isn\'t supported in this browser. Use Chrome or Edge (desktop or Android) over HTTPS.',
                    style: GoogleFonts.inter(fontSize: 12.5, color: Colors.orange.shade800)),
              ),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text('Device', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
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
                        Text(_connected ? (_deviceName ?? 'Connected') : 'Not connected',
                            style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600,
                                color: _connected ? AppColors.success : Colors.grey.shade700)),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _servicesCtrl,
                    enabled: !_connected,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Optional Service UUIDs (comma-separated)',
                      hintText: 'battery_service, 0000ffe0-...',
                      helperText: "Add your device's own Service UUID here if it isn't found "
                          '— the browser only shows services listed in this box.',
                      helperMaxLines: 2,
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: _connected ? AppColors.error : AppColors.accent,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _connecting ? null : (_connected ? _disconnect : _scanAndConnect),
                      icon: _connecting
                          ? const SizedBox(width: 16, height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Icon(_connected ? Icons.bluetooth_disabled_rounded : Icons.bluetooth_searching_rounded, size: 18),
                      label: Text(_connected ? 'Disconnect' : 'Scan & Connect',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ]),
              ),
            ),
            if (_connected) ...[
              const SizedBox(height: 14),
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Service', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<JSObject>(
                      isExpanded: true,
                      initialValue: _selectedService,
                      items: _services
                          .map((s) => DropdownMenuItem(value: s, child: Text(_uuidOf(s), overflow: TextOverflow.ellipsis)))
                          .toList(),
                      onChanged: (s) => s == null ? null : _loadCharacteristics(s),
                      decoration: InputDecoration(
                          isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                    ),
                    const SizedBox(height: 14),
                    Text('Characteristic', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<JSObject>(
                      isExpanded: true,
                      initialValue: _selectedCharacteristic,
                      items: _characteristics
                          .map((c) => DropdownMenuItem(value: c, child: Text(_uuidOf(c), overflow: TextOverflow.ellipsis)))
                          .toList(),
                      onChanged: (c) => setState(() { _selectedCharacteristic = c; _notifying = false; }),
                      decoration: InputDecoration(
                          isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                    ),
                    const SizedBox(height: 14),
                    Row(children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _selectedCharacteristic == null ? null : _read,
                          icon: const Icon(Icons.download_rounded, size: 18),
                          label: const Text('Read'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _selectedCharacteristic == null ? null : _toggleNotify,
                          icon: Icon(_notifying ? Icons.notifications_active_rounded : Icons.notifications_none_rounded, size: 18),
                          label: Text(_notifying ? 'Unsubscribe' : 'Subscribe'),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(
                        child: TextField(
                          controller: _writeCtrl,
                          decoration: InputDecoration(
                            hintText: _writeFormat == 'Hex' ? 'e.g. 01 0A FF' : 'Value to write',
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      DropdownButton<String>(
                        value: _writeFormat,
                        underline: const SizedBox(),
                        items: _writeFormats.map((f) => DropdownMenuItem(value: f, child: Text(f, style: const TextStyle(fontSize: 13)))).toList(),
                        onChanged: (v) => setState(() => _writeFormat = v ?? 'Text (UTF-8)'),
                      ),
                      const SizedBox(width: 10),
                      FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
                        onPressed: _selectedCharacteristic == null ? null : _write,
                        child: const Text('Write'),
                      ),
                    ]),
                  ]),
                ),
              ),
            ],
            const SizedBox(height: 14),
            Text('Live Log', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 160),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(12)),
              child: _log.isEmpty
                  ? Text('Scan & connect to a nearby BLE device to see activity here…',
                      style: GoogleFonts.inter(color: Colors.white38, fontSize: 12.5))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _log.take(50).map((l) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Text(
                          '[${l.time.hour.toString().padLeft(2, '0')}:${l.time.minute.toString().padLeft(2, '0')}:${l.time.second.toString().padLeft(2, '0')}] ${l.text}',
                          style: GoogleFonts.robotoMono(fontSize: 11.5,
                              color: l.isError ? AppColors.error : AppColors.success),
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
