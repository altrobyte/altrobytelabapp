import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../constants/app_colors.dart';

/// Public, no-login raw WebSocket client — connect, send text, watch
/// incoming messages live. Useful for testing any device/service that
/// exposes a plain WebSocket endpoint (ws:// or wss://).
class WebSocketTesterScreen extends StatefulWidget {
  final String? initialUrl;
  const WebSocketTesterScreen({super.key, this.initialUrl});

  @override
  State<WebSocketTesterScreen> createState() => _WebSocketTesterScreenState();
}

class _WsLogLine {
  final String text;
  final DateTime time;
  final bool isError;
  final bool isOutgoing;
  _WsLogLine(this.text, this.time, {this.isError = false, this.isOutgoing = false});
}

class _WebSocketTesterScreenState extends State<WebSocketTesterScreen> {
  late final _urlCtrl = TextEditingController(text: widget.initialUrl ?? 'wss://echo.websocket.org');
  final _messageCtrl = TextEditingController(text: 'Hello from Altrobyte Lab');

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  bool _connecting = false;
  bool _connected = false;
  final List<_WsLogLine> _log = [];

  void _addLog(String text, {bool isError = false, bool isOutgoing = false}) {
    if (!mounted) return;
    setState(() {
      _log.insert(0, _WsLogLine(text, DateTime.now(), isError: isError, isOutgoing: isOutgoing));
      if (_log.length > 200) _log.removeLast();
    });
  }

  Future<void> _connect() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty || _connecting || _connected) return;
    final uri = Uri.tryParse(url);
    if (uri == null) {
      _addLog('Invalid URL', isError: true);
      return;
    }

    setState(() => _connecting = true);
    try {
      final channel = WebSocketChannel.connect(uri);
      await channel.ready;
      _channel = channel;
      _sub = channel.stream.listen(
        (data) => _addLog('$data'),
        onError: (e) => _addLog('Error: $e', isError: true),
        onDone: () {
          _addLog('Connection closed', isError: true);
          if (mounted) setState(() => _connected = false);
        },
      );
      _addLog('Connected to $url');
      if (mounted) setState(() => _connected = true);
    } catch (e) {
      _addLog('Connection failed: $e', isError: true);
    }
    if (mounted) setState(() => _connecting = false);
  }

  void _disconnect() {
    _sub?.cancel();
    _channel?.sink.close();
    _channel = null;
    setState(() => _connected = false);
  }

  void _send() {
    final msg = _messageCtrl.text;
    if (msg.isEmpty || !_connected) return;
    _channel?.sink.add(msg);
    _addLog(msg, isOutgoing: true);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _channel?.sink.close();
    _urlCtrl.dispose();
    _messageCtrl.dispose();
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
          const Icon(Icons.cable_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Text('WebSocket Tester',
              style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
        ]),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text('Connection', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
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
                  TextField(
                    controller: _urlCtrl,
                    enabled: !_connected,
                    decoration: InputDecoration(
                      labelText: 'WebSocket URL',
                      hintText: 'wss://your-device-or-service.example.com',
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

            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Send Message', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _messageCtrl,
                        decoration: InputDecoration(
                          hintText: 'Message text', isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
                      onPressed: _connected ? _send : null,
                      child: const Text('Send'),
                    ),
                  ]),
                ]),
              ),
            ),
            const SizedBox(height: 14),

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
                  ? Text('Connect and send a message to see activity here…',
                      style: GoogleFonts.inter(color: Colors.white38, fontSize: 12.5))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _log.take(50).map((l) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Text(
                          '[${l.time.hour.toString().padLeft(2, '0')}:${l.time.minute.toString().padLeft(2, '0')}:${l.time.second.toString().padLeft(2, '0')}] ${l.isOutgoing ? '→ ' : ''}${l.text}',
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
