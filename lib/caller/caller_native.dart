// The Android side of the caller app (android/app/src/caller): placing the call, hearing when it ends, follow-up
// reminders, the caller ID overlay and speech-to-text. Everything here quietly does nothing where that code is absent
// (tests, or a build without it), so the screens never have to ask.

import 'dart:convert';

import 'package:flutter/services.dart';

/// A call that just ended, read from the phone's call log.
class CallEnded {
  final String phone;
  final int durationS;
  final String type; // out | in | missed
  final DateTime startedAt;
  final bool expected; // the app dialled it
  final bool known; // read from the call log; without it the phone cannot tell a ring-out from a conversation

  const CallEnded(
      {required this.phone,
      required this.durationS,
      required this.type,
      required this.startedAt,
      this.expected = false,
      this.known = true});

  bool get connected => durationS > 0;

  factory CallEnded.fromMap(Map m) => CallEnded(
        phone: '${m['phone'] ?? ''}',
        durationS: (m['duration_s'] as num?)?.toInt() ?? 0,
        type: '${m['type'] ?? 'out'}',
        startedAt: DateTime.fromMillisecondsSinceEpoch((m['started_at_ms'] as num?)?.toInt() ?? 0, isUtc: true),
        expected: m['expected'] == true,
        known: m['known'] != false,
      );
}

class Reminder {
  final int id;
  final DateTime at;
  final String title;
  final String body;
  final String phone;
  const Reminder({required this.id, required this.at, required this.title, required this.body, required this.phone});

  Map<String, dynamic> toMap() =>
      {'id': id, 'at_ms': at.millisecondsSinceEpoch, 'title': title, 'body': body, 'phone': phone};
}

class CallerNative {
  CallerNative._();
  static final instance = CallerNative._();

  static const _ch = MethodChannel('altrobyte.caller/native');

  void Function(CallEnded call)? onCallEnded;
  void Function(String phone)? onOpenLead;

  void listen() {
    _ch.setMethodCallHandler((call) async {
      final args = call.arguments;
      if (call.method == 'callEnded' && args is Map) onCallEnded?.call(CallEnded.fromMap(args));
      if (call.method == 'openLead' && args is String) onOpenLead?.call(args);
      return null;
    });
  }

  Future<T?> _call<T>(String method, [Object? args]) async {
    try {
      return await _ch.invokeMethod<T>(method, args);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  /// Rings the number straight away (or opens the dialler with it, if calling was not allowed).
  Future<bool> placeCall(String phone) async => await _call<bool>('placeCall', {'phone': phone}) ?? false;

  /// Which permissions the app has: call_phone, phone_state, call_log, notifications, overlay, exact_alarm.
  Future<Map<String, bool>> permissions() async =>
      (await _call<Map>('permissions'))?.map((k, v) => MapEntry('$k', v == true)) ?? const {};

  Future<bool> requestPermission(String name) async => await _call<bool>('requestPermission', {'name': name}) ?? false;

  /// Things that happened while the app was not listening: a call that ended, a reminder that was tapped.
  Future<void> deliverPending() => _call('deliverPending');

  /// Replaces every scheduled follow-up reminder with these.
  Future<void> schedule(List<Reminder> reminders) =>
      _call('schedule', {'reminders': jsonEncode(reminders.map((r) => r.toMap()).toList())});

  /// What the caller ID overlay shows for each lead, plus how to look up a number it does not have.
  Future<void> setDirectory(Map<String, Map<String, dynamic>> byPhone, {String? token, String? baseUrl}) =>
      _call('setDirectory', {'directory': jsonEncode(byPhone), 'token': token ?? '', 'base_url': baseUrl ?? ''});

  Future<String?> speechToText() => _call<String>('speechToText');

  /// The phone's recent calls, newest first; null when the call log may not be read.
  Future<List<DeviceCall>?> recentCalls({int limit = 300}) async {
    final rows = await _call<List>('recentCalls', {'limit': limit});
    return rows?.whereType<Map>().map(DeviceCall.fromMap).toList();
  }
}

/// One call from the phone's own call history.
class DeviceCall {
  final String phone;
  final String contactName;
  final String type; // out | in | missed | rejected | blocked
  final int durationS;
  final DateTime at;

  /// A call the phone's owner turned down or the phone blocked: almost always spam, never sent to the CRM.
  bool get refused => type == 'rejected' || type == 'blocked';

  const DeviceCall({required this.phone, required this.type, required this.at, this.contactName = '', this.durationS = 0});

  factory DeviceCall.fromMap(Map m) => DeviceCall(
        phone: '${m['phone'] ?? ''}',
        contactName: '${m['name'] ?? ''}',
        type: '${m['type'] ?? 'out'}',
        durationS: (m['duration_s'] as num?)?.toInt() ?? 0,
        at: DateTime.fromMillisecondsSinceEpoch((m['started_at_ms'] as num?)?.toInt() ?? 0, isUtc: true),
      );

  /// Which call this is, so the app can remember it was logged.
  String get key => '$phone@${at.millisecondsSinceEpoch}';

  /// As the CRM's sync takes it.
  Map<String, dynamic> toSync() => {
        'phone': phone,
        'direction': type == 'out' ? 'out' : 'in',
        'missed': type != 'out' && type != 'in',
        'started_at': at.toUtc().toIso8601String(),
        'duration_s': type == 'out' || type == 'in' ? durationS : 0,
        'contact_name': contactName,
      };

  /// As the log sheet takes it. A missed call has no length to read, so the sheet asks rather than guesses.
  CallEnded toEnded() => CallEnded(
      phone: phone, durationS: durationS, type: type == 'out' ? 'out' : 'in', startedAt: at, known: type == 'out' || type == 'in');
}
