// The caller app's line to the CRM. Every failure comes back as a CallerError whose message can be shown to a caller as
// it is: no status codes, no stack traces. Whether it is worth trying again is on the error, for the outbox.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../constants/api_constants.dart';

class CallerError implements Exception {
  final String message;
  final int? status;
  const CallerError(this.message, {this.status});

  /// No answer at all, or one that says try later: send again. Anything else the server refused for a reason.
  bool get retryable => status == null || status == 408 || status == 429 || status! >= 500;
  bool get signedOut => status == 401;

  @override
  String toString() => message;
}

class CallerApi {
  CallerApi({http.Client? client, this.token, List<String>? hosts})
      : _client = client ?? http.Client(),
        _hosts = hosts ?? [ApiConstants.baseUrl, ApiConstants.fallbackBaseUrl].where((h) => h.isNotEmpty).toSet().toList();

  final http.Client _client;
  final List<String> _hosts;
  String? token;
  String? _live;

  String get baseUrl => _live ?? _hosts.first;

  static const _timeout = Duration(seconds: 20);

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token != null && token!.isNotEmpty) 'Authorization': 'Bearer $token',
      };

  /// One request, tried on the other host when this one cannot be reached at all, and once more on a timeout.
  Future<dynamic> _send(String method, String path, [Object? body]) async {
    final order = [if (_live != null) _live!, ..._hosts.where((h) => h != _live)];
    CallerError? last;
    for (final host in order) {
      for (var attempt = 0; attempt < 2; attempt++) {
        try {
          final uri = Uri.parse('$host$path');
          final req = http.Request(method, uri)..headers.addAll(_headers);
          if (body != null) req.body = jsonEncode(body);
          final res = await http.Response.fromStream(await _client.send(req).timeout(_timeout));
          _live = host;
          return _read(res);
        } on CallerError {
          rethrow;
        } on TimeoutException {
          last = const CallerError('The network is slow right now. We will keep trying.');
          continue;
        } on SocketException {
          last = const CallerError('No internet right now. Your work is saved on the phone and will sync.');
          break;
        } on http.ClientException {
          last = const CallerError('No internet right now. Your work is saved on the phone and will sync.');
          break;
        } on HandshakeException {
          last = const CallerError('Could not reach the CRM securely. Check the phone\'s date and time.');
          break;
        }
      }
    }
    throw last ?? const CallerError('Could not reach the CRM. We will keep trying.');
  }

  dynamic _read(http.Response res) {
    dynamic body;
    try {
      body = res.body.isEmpty ? null : jsonDecode(res.body);
    } catch (_) {
      body = null;
    }
    if (res.statusCode < 400) return body;
    final detail = body is Map ? body['detail'] : null;
    throw CallerError(plainError(res.statusCode, detail is String ? detail : null), status: res.statusCode);
  }

  /// What to tell a caller when the server says no. The server's own words are used when they are a sentence written
  /// for a person (ours are), never when they are a validation dump.
  static String plainError(int status, String? detail) {
    if (status == 401) return 'Your login has ended. Please sign in again.';
    if (status == 429) return 'Too many tries. Wait a minute and try again.';
    if (status >= 500 && status != 502) return 'The CRM is having a problem. We will keep trying.';
    final d = (detail ?? '').trim();
    final human = d.isNotEmpty && d.length < 200 && !d.contains('{') && !d.contains('one of (');
    if (human) return d;
    if (status == 403) return 'You do not have access to this.';
    if (status == 404) return 'This lead is not in the CRM.';
    return 'That did not go through. Please check and try again.';
  }

  // ── sign in ──
  Future<Map<String, dynamic>> login(String email, String password, {bool admin = false}) async {
    final r = await _send('POST', admin ? '/auth/login' : '/manager/login', {'email': email.trim(), 'password': password});
    return (r as Map).cast<String, dynamic>();
  }

  /// The institute owner's WhatsApp code: sent to the number on the account (auth.py request_otp / verify_otp).
  Future<void> requestOtp(String phone) =>
      _send('POST', '/auth/request-otp?phone=${Uri.encodeQueryComponent(phone.trim())}');

  Future<Map<String, dynamic>> verifyOtp(String phone, String otp) async => ((await _send('POST',
          '/auth/verify-otp?phone=${Uri.encodeQueryComponent(phone.trim())}&otp=${Uri.encodeQueryComponent(otp.trim())}'))
      as Map)
      .cast<String, dynamic>();

  // ── the queue and leads ──
  Future<Map<String, dynamic>> myQueue({String owner = ''}) async =>
      ((await _send('GET', '/crm/my-queue${owner.isEmpty ? '' : '?owner=${Uri.encodeQueryComponent(owner)}'}')) as Map)
          .cast<String, dynamic>();

  Future<Map<String, dynamic>> logCall(Map<String, dynamic> body) async =>
      ((await _send('POST', '/crm/leads/${body['phone']}/calls', body)) as Map).cast<String, dynamic>();

  /// The phone's own calls, sent by themselves (crm_calls.sync_calls).
  Future<Map<String, dynamic>> syncCalls(List<Map<String, dynamic>> calls, {bool addNew = true}) async =>
      ((await _send('POST', '/crm/calls/sync', {'calls': calls, 'add_new': addNew})) as Map).cast<String, dynamic>();

  Future<Map<String, dynamic>> timeline(String phone) async =>
      ((await _send('GET', '/crm/leads/$phone/timeline')) as Map).cast<String, dynamic>();

  Future<Map<String, dynamic>> callerId(String phone) async =>
      ((await _send('GET', '/crm/caller-id/$phone')) as Map).cast<String, dynamic>();

  Future<List<String>> labels() async => _list(await _send('GET', '/crm/labels'), 'labels').map((e) => '$e').toList();

  Future<List<Map<String, dynamic>>> quickMessages() async => _maps(await _send('GET', '/crm/quick-wa'), 'messages');

  static List _list(dynamic body, String key) => body is Map && body[key] is List ? body[key] as List : const [];
  static List<Map<String, dynamic>> _maps(dynamic body, String key) =>
      _list(body, key).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();

  Future<void> quickWa(String phone, String kind) => _send('POST', '/crm/leads/$phone/quick-wa', {'kind': kind});

  // ── team leads ──
  Future<Map<String, dynamic>> teamStats(int days) async =>
      ((await _send('GET', '/crm/team-stats?days=$days')) as Map).cast<String, dynamic>();

  Future<List<Map<String, dynamic>>> team() async => _maps(await _send('GET', '/crm/team'), 'team');

  Future<List<Map<String, dynamic>>> unassigned() async => _maps(await _send('GET', '/crm/unassigned'), 'leads');

  Future<Map<String, dynamic>> assign(List<String> phones, {String? owner, List<String>? roundRobin}) async =>
      ((await _send('PUT', '/crm/assign', {
        'phones': phones,
        if (owner != null) 'owner': owner,
        if (roundRobin != null) 'round_robin': roundRobin,
      })) as Map)
          .cast<String, dynamic>();
}
