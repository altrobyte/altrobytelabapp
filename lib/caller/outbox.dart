// Call logs waiting to reach the CRM. A log is written here first, always, and sent from here: so a caller with no
// signal loses nothing, and a log the server already took (the reply was lost on the way back) is recognised there by
// its client id and not saved twice.

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'caller_api.dart';
import 'models.dart';

class FlushResult {
  final int sent;
  final List<String> problems;
  final List<Map<String, dynamic>> leads;
  final bool signedOut;
  const FlushResult({this.sent = 0, this.problems = const [], this.leads = const [], this.signedOut = false});
}

class Outbox {
  Outbox(this._send);

  /// Sends one log; returns the server's answer. Throws CallerError.
  final Future<Map<String, dynamic>> Function(Map<String, dynamic> body) _send;

  static const _key = 'caller_outbox';
  final List<CallLog> _items = [];
  bool _flushing = false;

  List<CallLog> get items => List.unmodifiable(_items);
  int get length => _items.length;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _items
      ..clear()
      ..addAll(((jsonDecode(prefs.getString(_key) ?? '[]') as List))
          .map((e) => CallLog.fromJson((e as Map).cast<String, dynamic>())));
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(_items.map((e) => e.toJson()).toList()));
  }

  Future<void> add(CallLog log) async {
    if (_items.any((e) => e.clientId == log.clientId)) return;
    _items.add(log);
    await _save();
  }

  /// Send everything waiting, oldest call first. Stops at the first failure worth retrying (no signal, server busy)
  /// and keeps the rest for next time; a log the server refused for a reason is dropped and reported in plain words.
  Future<FlushResult> flush() async {
    if (_flushing || _items.isEmpty) return const FlushResult();
    _flushing = true;
    var sent = 0;
    final problems = <String>[];
    final leads = <Map<String, dynamic>>[];
    try {
      _items.sort((a, b) => a.startedAt.compareTo(b.startedAt));
      while (_items.isNotEmpty) {
        final log = _items.first;
        try {
          final r = await _send(log.toJson());
          if (r['lead'] is Map) leads.add((r['lead'] as Map).cast<String, dynamic>());
          sent++;
        } on CallerError catch (e) {
          if (e.signedOut) return FlushResult(sent: sent, problems: problems, leads: leads, signedOut: true);
          if (e.retryable) break;
          problems.add('A call to ${log.phone} could not be saved: ${e.message}');
        } catch (_) {
          break;
        }
        _items.removeAt(0);
        await _save();
      }
      return FlushResult(sent: sent, problems: problems, leads: leads);
    } finally {
      _flushing = false;
    }
  }
}
