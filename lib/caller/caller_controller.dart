// Everything the caller app knows, in one place: who is signed in, their queue (kept on the phone for when there is no
// signal), call logs waiting to be sent, and the call that just ended and is waiting to be logged.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'caller_api.dart';
import 'caller_native.dart';
import 'models.dart';
import 'outbox.dart';
import 'queue_order.dart';

/// A call to log: the lead (or, for a number that is not a lead yet, a bare one) and what the phone saw.
class PendingLog {
  final Lead lead;
  final CallEnded? call;
  final bool isNew;
  const PendingLog(this.lead, {this.call, this.isNew = false});
}

class Me {
  final String login;
  final String name;
  final bool teamLead;
  const Me({required this.login, required this.name, this.teamLead = false});

  factory Me.fromJson(Map<String, dynamic> j) =>
      Me(login: '${j['login'] ?? ''}', name: '${j['name'] ?? ''}', teamLead: j['team_lead'] == true);
  Map<String, dynamic> toJson() => {'login': login, 'name': name, 'team_lead': teamLead};
}

class CallerController extends ChangeNotifier {
  CallerController({CallerApi? api, CallerNative? native, DateTime Function()? clock, this.demo = false})
      : api = api ?? CallerApi(),
        native = native ?? CallerNative.instance,
        _clock = clock ?? DateTime.now {
    outbox = Outbox(this.api.logCall);
  }

  final CallerApi api;
  final CallerNative native;

  /// Sample leads and no server (demo_client.dart): nothing reaches the CRM.
  final bool demo;
  final DateTime Function() _clock;
  late final Outbox outbox;

  bool ready = false;
  Me? me;
  List<Lead> leads = [];
  List<String> labels = [];
  List<Map<String, dynamic>> quickMessages = [];
  bool syncing = false;
  bool offline = false;
  DateTime? lastSync;

  /// A plain sentence for the caller, shown once and then cleared by the screen.
  String? notice;
  PendingLog? pendingLog;
  String? openPhone;

  String? _expected;
  DateTime? _expectedAt;
  Timer? _timer;

  bool get signedIn => me != null && (api.token ?? '').isNotEmpty;
  DateTime get now => _clock().toUtc();

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    api.token = prefs.getString('caller_token');
    final meJson = prefs.getString('caller_me');
    me = meJson == null ? null : Me.fromJson((jsonDecode(meJson) as Map).cast<String, dynamic>());
    leads = sortQueue(((jsonDecode(prefs.getString('caller_queue') ?? '[]') as List))
        .map((e) => Lead.fromJson((e as Map).cast<String, dynamic>())), now);
    labels = (jsonDecode(prefs.getString('caller_labels') ?? '[]') as List).map((e) => '$e').toList();
    quickMessages = (jsonDecode(prefs.getString('caller_quick') ?? '[]') as List).map((e) => (e as Map).cast<String, dynamic>()).toList();
    await outbox.load();
    await _loadSyncPrefs();
    native.onCallEnded = (e) async {
      await handleCallEnded(e);
      if (await syncDeviceCalls() > 0) await refresh(quiet: true);
    };
    native.onOpenLead = (phone) {
      openPhone = last10(phone);
      notifyListeners();
    };
    native.listen();
    ready = true;
    notifyListeners();
    if (signedIn) {
      unawaited(refresh());
      unawaited(native.deliverPending());
    }
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _tick());
  }

  int _ticks = 0;
  Future<void> _tick() async {
    if (!signedIn) return;
    _ticks++;
    if (outbox.length > 0) await sync();
    if (_ticks % 5 == 0) {
      await refresh(quiet: true); // sends the phone's new calls first
    } else if (await syncDeviceCalls() > 0) {
      await refresh(quiet: true);
    }
    notifyListeners(); // a follow-up may just have become due
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }

  /// A sync still running when the app closes finishes quietly.
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  // ── signing in ──

  Future<String?> signIn(String email, String password, {bool admin = false}) async =>
      _signInWith(() => api.login(email, password, admin: admin));

  /// Sends the WhatsApp code; returns what to tell the person.
  Future<String> requestOtp(String phone) async {
    try {
      await api.requestOtp(phone);
      return 'If this number is on the account, a code is on its way on WhatsApp.';
    } on CallerError catch (e) {
      return e.message;
    }
  }

  Future<String?> signInWithOtp(String phone, String otp) async {
    final said = await _signInWith(() => api.verifyOtp(phone, otp));
    return said == 'That email or password is not right.' ? 'That code is not right, or it has expired.' : said;
  }

  Future<String?> _signInWith(Future<Map<String, dynamic>> Function() login) async {
    try {
      final r = await login();
      final token = '${r['jwt_token'] ?? r['token'] ?? ''}';
      if (token.isEmpty) return 'That login did not work. Please try again.';
      api.token = token;
      final q = await api.myQueue();
      me = Me.fromJson((q['me'] as Map).cast<String, dynamic>());
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('caller_token', token);
      await prefs.setString('caller_me', jsonEncode(me!.toJson()));
      await _takeQueue(q);
      unawaited(_extras());
      unawaited(native.deliverPending());
      notifyListeners();
      return null;
    } on CallerError catch (e) {
      api.token = null;
      if (e.status == 401) return 'That email or password is not right.';
      if (e.status == 403) return 'This login is not for the calling team. Ask your admin for a team login.';
      return e.message;
    }
  }

  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    for (final k in ['caller_token', 'caller_me', 'caller_queue']) {
      await prefs.remove(k);
    }
    api.token = null;
    me = null;
    leads = [];
    await native.schedule(const []);
    await native.setDirectory(const {});
    notifyListeners();
  }

  // ── the queue ──

  Future<void>? _refreshing;

  /// Sends what is waiting, then fetches the queue. A second call while one is running waits for that one.
  Future<void> refresh({bool quiet = false}) =>
      _refreshing ??= _refresh(quiet).whenComplete(() => _refreshing = null);

  Future<void> _refresh(bool quiet) async {
    if (!signedIn) return;
    syncing = true;
    if (!quiet) notifyListeners();
    try {
      await sync();
      if (!signedIn) return;
      // The leads first, so the screen fills at once; the phone's calls go after and the list is read again only
      // if they changed it.
      await _takeQueue(await api.myQueue());
      offline = false;
      lastSync = now;
      unawaited(_extras());
      notifyListeners();
      if (await syncDeviceCalls() > 0) await _takeQueue(await api.myQueue());
    } on CallerError catch (e) {
      if (e.signedOut) {
        await _expired();
      } else {
        offline = e.retryable;
        if (!quiet && !e.retryable) notice = e.message;
      }
    } finally {
      syncing = false;
      notifyListeners();
    }
  }

  Future<void> _takeQueue(Map<String, dynamic> q) async {
    final fresh = ((q['leads'] as List?) ?? const []).map((e) => Lead.fromJson((e as Map).cast<String, dynamic>()));
    // A log still waiting to be sent has not reached these numbers yet: keep showing it applied.
    final waiting = {for (final l in outbox.items) l.phone: l};
    leads = sortQueue(fresh.map((l) => waiting[l.phone]?.applyTo(l, me: me?.login ?? '') ?? l), now);
    await _saveQueue();
    await _syncPhoneSide();
  }

  Future<void> _extras() async {
    try {
      labels = await api.labels();
      quickMessages = await api.quickMessages();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('caller_labels', jsonEncode(labels));
      await prefs.setString('caller_quick', jsonEncode(quickMessages));
      notifyListeners();
    } catch (_) {
      // The ones saved last time stay in use.
    }
  }

  Future<void> _saveQueue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('caller_queue', jsonEncode(leads.map((l) => l.toJson()).toList()));
  }

  Future<void> _expired() async {
    notice = 'Your login has ended. Please sign in again.';
    me = null;
    api.token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('caller_token');
    await prefs.remove('caller_me');
    notifyListeners();
  }

  /// Reminders for every follow-up still ahead, and what the caller ID overlay should know.
  Future<void> _syncPhoneSide() async {
    final t = now;
    await native.schedule([
      for (final l in leads)
        if (l.nextFollowupAt != null && l.nextFollowupAt!.isAfter(t))
          Reminder(
            id: (int.tryParse(l.phone) ?? 0) % 2147483647,
            at: l.nextFollowupAt!,
            title: 'Follow-up: ${l.displayName}',
            body: [stages[l.stage] ?? l.stage, if (l.lastNote.isNotEmpty) l.lastNote].join(' · '),
            phone: l.phone,
          ),
    ]);
    await native.setDirectory({
      for (final l in leads)
        l.phone: {
          'name': l.displayName,
          'temperature': l.heat.temperature,
          'pct': l.heat.pct,
          'stage': stages[l.stage] ?? l.stage,
          'last_note': l.lastNote,
          'next': l.nextFollowupAt == null ? '' : 'Follow-up ${_short(l.nextFollowupAt!)}',
        },
    }, token: api.token, baseUrl: api.baseUrl);
  }

  // ── calling and logging ──

  Lead? leadFor(String phone) {
    final p = last10(phone);
    for (final l in leads) {
      if (l.phone == p) return l;
    }
    return null;
  }

  Future<void> call(Lead lead) async {
    _expected = lead.phone;
    _expectedAt = now;
    final rang = await native.placeCall(lead.phone);
    if (!rang) {
      // No phone side to watch the call (or it was refused): log it by hand.
      pendingLog = PendingLog(lead);
      notifyListeners();
    }
  }

  void logByHand(Lead lead) {
    pendingLog = PendingLog(lead);
    notifyListeners();
  }

  /// A call just ended on the phone. A call to or from a lead opens the log sheet; a conversation with a number that is
  /// not a lead offers to add it; a missed call, or a dialled number that is nobody, is left alone.
  Future<void> handleCallEnded(CallEnded e) async {
    if (!signedIn || e.type == 'missed') return;
    final p = last10(e.phone);
    if (p.length != 10) return;
    // Delivered late (the app was closed for hours): too stale to log from memory.
    if (now.difference(e.startedAt) > const Duration(hours: 12)) return;
    final expected = e.expected ||
        (_expected == p && _expectedAt != null && now.difference(_expectedAt!) < const Duration(hours: 2));
    var lead = leadFor(p);
    if (lead == null && (e.type == 'in' || expected)) {
      try {
        final who = await api.callerId(p);
        if (who['known'] == true) {
          lead = Lead(
              phone: p,
              name: '${who['name'] ?? ''}',
              stage: '${who['stage'] ?? 'new'}',
              heat: Heat.fromJson((who['heat'] as Map?)?.cast<String, dynamic>()),
              lastNote: '${who['last_note'] ?? ''}');
        }
      } on CallerError {
        // Offline: treat it as someone new; the server matches the number to the lead anyway.
      }
    }
    if (lead == null) {
      final talkedIn = e.type == 'in' && e.connected && now.difference(e.startedAt) <= const Duration(minutes: 30);
      if (!talkedIn && !expected) return;
      pendingLog = PendingLog(Lead(phone: p), call: e, isNew: true);
    } else {
      pendingLog = PendingLog(lead, call: e);
    }
    if (expected) _expected = null;
    _pendingKey = '${e.phone}@${e.startedAt.millisecondsSinceEpoch}';
    notifyListeners();
  }

  PendingLog? takePendingLog() {
    final p = pendingLog;
    pendingLog = null;
    return p;
  }

  CallLog newLog({required String phone, required String outcome, DateTime? startedAt, int durationS = 0,
      String direction = 'out'}) {
    return CallLog(
        clientId: const Uuid().v4(),
        phone: phone,
        startedAt: (startedAt ?? now).toUtc(),
        durationS: durationS,
        direction: direction,
        outcome: outcome);
  }

  /// Keeps the log on the phone, shows its effect at once, and sends it (now if there is signal, later if not).
  Future<void> save(CallLog log) async {
    await outbox.add(log);
    final existing = leadFor(log.phone);
    final updated = log.applyTo(existing ?? Lead(phone: log.phone, owner: me?.login ?? ''), me: me?.login ?? '');
    leads = sortQueue([...leads.where((l) => l.phone != log.phone), updated], now);
    await _saveQueue();
    notifyListeners();
    await sync();
    await _syncPhoneSide();
  }

  Future<void> sync() async {
    if (outbox.length == 0) return;
    final r = await outbox.flush();
    if (r.signedOut) return _expired();
    for (final j in r.leads) {
      final l = Lead.fromJson(j);
      leads = sortQueue([...leads.where((x) => x.phone != l.phone), l], now);
    }
    if (r.leads.isNotEmpty) await _saveQueue();
    if (r.problems.isNotEmpty) notice = r.problems.join('\n');
    offline = outbox.length > 0;
    notifyListeners();
  }

  /// Sends a quick WhatsApp message; returns what to tell the caller.
  Future<String> quickWa(String phone, String kind) async {
    try {
      await api.quickWa(phone, kind);
      return 'Sent on WhatsApp.';
    } on CallerError catch (e) {
      return e.retryable ? 'WhatsApp needs internet. Try again when you have signal.' : e.message;
    }
  }

  Future<String?> speechToText() => native.speechToText();

  // ── the phone's own calls, sent to the CRM by themselves ──

  /// Numbers the caller marked personal: never sent.
  Set<String> ignored = {};

  /// New numbers become leads by themselves (on by default). Off: only calls with existing leads are sent.
  bool autoAdd = true;
  bool _syncingCalls = false;

  Future<void> _loadSyncPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    ignored = (prefs.getStringList('caller_ignored') ?? const []).toSet();
    autoAdd = prefs.getBool('caller_auto_add') ?? true;
  }

  Future<void> setAutoAdd(bool on) async {
    autoAdd = on;
    (await SharedPreferences.getInstance()).setBool('caller_auto_add', on);
    notifyListeners();
  }

  Future<void> setPersonal(String phone, bool personal) async {
    final p = last10(phone);
    personal ? ignored.add(p) : ignored.remove(p);
    (await SharedPreferences.getInstance()).setStringList('caller_ignored', ignored.toList());
    notifyListeners();
  }

  /// Spam: never sent again from this phone, and if it already became a lead, out of the whole team's queue.
  Future<void> markSpam(String phone) async {
    await setPersonal(phone, true);
    if (leadFor(phone) != null) {
      await save(CallLog(
          clientId: const Uuid().v4(),
          phone: last10(phone),
          startedAt: now,
          outcome: 'wrong_number',
          stage: 'lost',
          lostReason: 'Spam',
          note: 'Marked as spam'));
    }
  }

  /// What the last sending of the phone's calls did, in words, for the Today screen.
  String? callSyncSaid;

  /// Sends every call from the phone's call log not sent yet (the first time, the last 7 days). Nothing to tap: who,
  /// which way, how long and missed or not reach the CRM, and new numbers arrive as leads named from the contacts.
  /// Returns how many calls it sent (0 when nothing changed).
  Future<int> syncDeviceCalls() async {
    if (!signedIn || _syncingCalls) return 0;
    _syncingCalls = true;
    var sentCalls = 0, newLeads = 0;
    try {
      final prefs = await SharedPreferences.getInstance();
      final upto = prefs.getInt('caller_synced_upto_ms') ?? now.subtract(const Duration(days: 7)).millisecondsSinceEpoch;
      final calls = await native.recentCalls(limit: 1000);
      if (calls == null) {
        callSyncSaid = 'Allow "Read the call log" (menu > Permissions) so your calls reach the CRM by themselves.';
        return 0;
      }
      final fresh = calls
          .where((d) => d.at.millisecondsSinceEpoch > upto)
          .where((d) => !d.refused && last10(d.phone).length == 10 && !ignored.contains(last10(d.phone)))
          .toList()
        ..sort((a, b) => a.at.compareTo(b.at));
      for (var i = 0; i < fresh.length; i += 50) {
        final batch = fresh.sublist(i, (i + 50).clamp(0, fresh.length));
        final r = await api.syncCalls(batch.map((d) => d.toSync()).toList(), addNew: autoAdd);
        sentCalls += (r['synced'] as num?)?.toInt() ?? 0;
        newLeads += (r['new_leads'] as num?)?.toInt() ?? 0;
        await prefs.setInt('caller_synced_upto_ms', batch.last.at.millisecondsSinceEpoch);
        callSyncSaid = 'Sending your calls… ${i + batch.length} of ${fresh.length}';
        notifyListeners();
      }
      // Everything up to the newest call is now done, personal numbers included.
      if (calls.isNotEmpty && calls.first.at.millisecondsSinceEpoch > upto) {
        await prefs.setInt('caller_synced_upto_ms', calls.first.at.millisecondsSinceEpoch);
      }
      if (fresh.isNotEmpty) {
        callSyncSaid = 'Sent $sentCalls call${sentCalls == 1 ? '' : 's'} from this phone, $newLeads new lead${newLeads == 1 ? '' : 's'}.'
            '${sentCalls < fresh.length ? ' The rest were spam, missed rings or short calls from numbers that are not leads.' : ''}';
      }
      return sentCalls;
    } on CallerError catch (e) {
      callSyncSaid = 'Could not send your calls yet: ${e.message}';
      return sentCalls; // what went is saved; the rest go next time
    } finally {
      _syncingCalls = false;
      notifyListeners();
    }
  }

  // ── the phone's own calls (the Calls tab) ──

  /// Null until read, or when the call log may not be read.
  List<DeviceCall>? deviceCalls;
  bool callLogAllowed = true;
  Set<String> _loggedKeys = {};

  bool isLogged(DeviceCall d) => _loggedKeys.contains(d.key);

  Future<void> loadDeviceCalls() async {
    final prefs = await SharedPreferences.getInstance();
    _loggedKeys = (prefs.getStringList('caller_logged_calls') ?? const []).toSet();
    final calls = await native.recentCalls();
    callLogAllowed = calls != null;
    deviceCalls = calls ?? const [];
    notifyListeners();
  }

  /// Opens the log sheet for a call from the phone's history: on the lead when the number is one, as "Add as a lead?"
  /// when it is not.
  void logDeviceCall(DeviceCall d) {
    final lead = leadFor(d.phone);
    final p = last10(d.phone);
    if (p.length != 10) return;
    _pendingKey = d.key;
    pendingLog = lead == null
        ? PendingLog(Lead(phone: p, name: d.contactName), call: d.toEnded(), isNew: true)
        : PendingLog(lead, call: d.toEnded());
    notifyListeners();
  }

  String? _pendingKey;

  /// Called with the log the sheet produced (or null when it was swiped away).
  Future<void> finishLog(CallLog? log) async {
    final key = _pendingKey;
    _pendingKey = null;
    if (log == null) return;
    await save(log);
    if (key != null) {
      _loggedKeys.add(key);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('caller_logged_calls', _loggedKeys.toList().take(2000).toList());
      notifyListeners();
    }
  }

  static String _short(DateTime d) {
    final l = d.toLocal();
    final h = l.hour % 12 == 0 ? 12 : l.hour % 12;
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${l.day} ${months[l.month - 1]}, $h:${l.minute.toString().padLeft(2, '0')} ${l.hour < 12 ? 'am' : 'pm'}';
  }

  static String when(DateTime d) => _short(d);
}
