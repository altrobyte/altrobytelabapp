import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../../constants/app_colors.dart';

/// Public, no-login minimal REST client — method, URL, headers, body,
/// response viewer. A Postman-in-a-tab for quick API/firmware endpoint checks.
class HttpTesterScreen extends StatefulWidget {
  const HttpTesterScreen({super.key});

  @override
  State<HttpTesterScreen> createState() => _HttpTesterScreenState();
}

class _HeaderRow {
  final TextEditingController key = TextEditingController();
  final TextEditingController value = TextEditingController();
}

class _HttpTesterScreenState extends State<HttpTesterScreen> {
  String _method = 'GET';
  final _urlCtrl = TextEditingController(text: 'https://jsonplaceholder.typicode.com/todos/1');
  final _bodyCtrl = TextEditingController();
  final List<_HeaderRow> _headers = [_HeaderRow()];

  bool _sending = false;
  int? _statusCode;
  String? _responseBody;
  Map<String, String>? _responseHeaders;
  String? _error;
  Duration? _elapsed;

  static const _methods = ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'];

  Future<void> _send() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) {
      setState(() => _error = 'Invalid URL');
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
      _statusCode = null;
      _responseBody = null;
      _responseHeaders = null;
    });

    final headers = <String, String>{};
    for (final h in _headers) {
      final k = h.key.text.trim();
      if (k.isNotEmpty) headers[k] = h.value.text;
    }

    final sw = Stopwatch()..start();
    try {
      http.Response res;
      final body = _bodyCtrl.text.isEmpty ? null : _bodyCtrl.text;
      switch (_method) {
        case 'POST':
          res = await http.post(uri, headers: headers, body: body).timeout(const Duration(seconds: 20));
          break;
        case 'PUT':
          res = await http.put(uri, headers: headers, body: body).timeout(const Duration(seconds: 20));
          break;
        case 'PATCH':
          res = await http.patch(uri, headers: headers, body: body).timeout(const Duration(seconds: 20));
          break;
        case 'DELETE':
          res = await http.delete(uri, headers: headers, body: body).timeout(const Duration(seconds: 20));
          break;
        default:
          res = await http.get(uri, headers: headers).timeout(const Duration(seconds: 20));
      }
      sw.stop();
      setState(() {
        _statusCode = res.statusCode;
        _responseHeaders = res.headers;
        _responseBody = _prettyPrint(res.body);
        _elapsed = sw.elapsed;
      });
    } catch (e) {
      sw.stop();
      setState(() => _error = e.toString());
    }
    if (mounted) setState(() => _sending = false);
  }

  String _prettyPrint(String raw) {
    try {
      final decoded = jsonDecode(raw);
      return const JsonEncoder.withIndent('  ').convert(decoded);
    } catch (_) {
      return raw;
    }
  }

  Color _statusColor(int code) {
    if (code < 300) return AppColors.success;
    if (code < 400) return const Color(0xFF1565C0);
    return AppColors.error;
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _bodyCtrl.dispose();
    for (final h in _headers) { h.key.dispose(); h.value.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1B5E),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Row(children: [
          const Icon(Icons.http_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Text('HTTP Tester',
              style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
        ]),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 780),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    DropdownButton<String>(
                      value: _method,
                      items: _methods.map((m) => DropdownMenuItem(value: m, child: Text(m,
                          style: GoogleFonts.robotoMono(fontWeight: FontWeight.w700, fontSize: 13)))).toList(),
                      onChanged: (v) => setState(() => _method = v ?? 'GET'),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _urlCtrl,
                        decoration: InputDecoration(
                          hintText: 'https://api.example.com/endpoint',
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFF7C4DFF)),
                      onPressed: _sending ? null : _send,
                      icon: _sending
                          ? const SizedBox(width: 16, height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.send_rounded, size: 16),
                      label: const Text('Send'),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  Text('Headers', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 8),
                  ..._headers.asMap().entries.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(children: [
                      Expanded(
                        child: TextField(
                          controller: e.value.key,
                          decoration: InputDecoration(
                            hintText: 'Header name', isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: e.value.value,
                          decoration: InputDecoration(
                            hintText: 'Value', isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: _headers.length == 1 ? null : () => setState(() => _headers.removeAt(e.key)),
                      ),
                    ]),
                  )),
                  TextButton.icon(
                    onPressed: () => setState(() => _headers.add(_HeaderRow())),
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Add header'),
                  ),
                  const SizedBox(height: 8),
                  Text('Body', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _bodyCtrl,
                    maxLines: 6,
                    style: GoogleFonts.robotoMono(fontSize: 12.5),
                    decoration: InputDecoration(
                      hintText: '{\n  "key": "value"\n}',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 16),

            if (_error != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                ),
                child: Text(_error!, style: GoogleFonts.inter(color: AppColors.error, fontSize: 13)),
              ),

            if (_statusCode != null) ...[
              Row(children: [
                Text('Response', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor(_statusCode!).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('$_statusCode',
                      style: GoogleFonts.robotoMono(
                          fontWeight: FontWeight.bold, fontSize: 12.5, color: _statusColor(_statusCode!))),
                ),
                if (_elapsed != null) ...[
                  const SizedBox(width: 8),
                  Text('${_elapsed!.inMilliseconds}ms',
                      style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.textSecondary)),
                ],
              ]),
              if (_responseHeaders != null && _responseHeaders!.isNotEmpty) ...[
                const SizedBox(height: 10),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text('Response Headers (${_responseHeaders!.length})',
                      style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600)),
                  children: _responseHeaders!.entries.map((e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('${e.key}: ${e.value}',
                          style: GoogleFonts.robotoMono(fontSize: 11, color: AppColors.textSecondary)),
                    ),
                  )).toList(),
                ),
              ],
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D1B5E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SelectableText(
                  _responseBody ?? '',
                  style: GoogleFonts.robotoMono(fontSize: 12, color: const Color(0xFF00E5A0)),
                ),
              ),
            ],
            const SizedBox(height: 20),
          ]),
        ),
      ),
    );
  }
}
