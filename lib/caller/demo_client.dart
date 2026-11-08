// Demo mode (flutter build apk --flavor caller -t lib/caller/caller_main.dart --dart-define=CALLER_DEMO=true): the app
// with no login and no server. It answers the same requests the CRM does, from sample leads kept in memory, so calling,
// the log sheet, reminders and the team screens can be tried on a phone. Nothing reaches the CRM; a restart resets it.
//
// The sample numbers start with 0, which no Indian mobile does, so tapping Call on one never rings a real person.

import 'dart:convert';

import 'package:http/http.dart' as http;

class DemoClient extends http.BaseClient {
  DemoClient({DateTime Function()? clock}) : _clock = clock ?? DateTime.now {
    final now = _clock().toUtc();
    for (final l in [
      _lead('0000000001', 'Meera Sharma', 'hot', 72, stage: 'interested', labels: ['working', 'wants EMI'],
          note: 'Asked about the weekend batch and EMI', follow: now.subtract(const Duration(minutes: 20))),
      _lead('0000000002', 'Rohit Verma', 'hot', 65, note: 'Wrote on WhatsApp: fees kitni hai?'),
      _lead('0000000003', 'Ananya Gupta', 'warm', 30, labels: ['student'], note: 'Took the scholarship test (64%)'),
      _lead('0000000004', 'Karan Mehta', 'warm', 22, stage: 'contacted', called: now.subtract(const Duration(days: 2))),
      _lead('0000000005', 'Sneha Patel', 'cold', 0, labels: ['Indore']),
      _lead('0000000006', 'Vikas Yadav', 'cold', 5, stage: 'contacted', called: now.subtract(const Duration(days: 4)),
          note: 'Busy, call next week'),
      _lead('0000000007', 'Pooja Nair', 'warm', 40, stage: 'demo_booked', follow: now.add(const Duration(days: 1))),
      _lead('0000000008', 'Arjun Singh', 'customer', 0, stage: 'enrolled', converted: true, credited: 'you@demo'),
    ]) {
      _leads[l['phone'] as String] = l;
    }
  }

  final DateTime Function() _clock;
  final Map<String, Map<String, dynamic>> _leads = {};
  final List<Map<String, dynamic>> _calls = [];
  final Set<String> _seen = {};
  final List<Map<String, dynamic>> _unassigned = [
    {'phone': '0000000011', 'name': 'Neha Joshi', 'stage': 'new', 'heat': {'temperature': 'hot', 'score': 55, 'pct': 55}, 'score_pct': 55},
    {'phone': '0000000012', 'name': 'Amit Kumar', 'stage': 'new', 'heat': {'temperature': 'warm', 'score': 25, 'pct': 25}, 'score_pct': 25},
    {'phone': '0000000013', 'name': 'Ritu Das', 'stage': 'new', 'heat': {'temperature': 'cold', 'score': 0, 'pct': 0}, 'score_pct': 0},
  ];
  static const _labels = ['student', 'working', 'parent', 'wants EMI', 'price concern', 'wants offline', 'Indore', 'online'];
  static const _team = [
    {'login': 'you@demo', 'name': 'You', 'team_lead': true, 'open_leads': 7},
    {'login': 'riya@demo', 'name': 'Riya', 'team_lead': false, 'open_leads': 12},
    {'login': 'sahil@demo', 'name': 'Sahil', 'team_lead': false, 'open_leads': 9},
  ];

  static Map<String, dynamic> _lead(String phone, String name, String temp, int score,
          {String stage = 'new',
          List<String> labels = const [],
          String note = '',
          DateTime? follow,
          DateTime? called,
          bool converted = false,
          String credited = ''}) =>
      {
        'phone': phone,
        'name': name,
        'stage': stage,
        'owner': 'you@demo',
        'labels': labels,
        'heat': {'temperature': temp, 'score': score, 'pct': temp == 'customer' ? 100 : score.clamp(0, 100), 'reasons': <String>[]},
        'score_pct': temp == 'customer' ? 100 : score.clamp(0, 100),
        'last_note': note,
        'next_followup_at': follow?.toIso8601String(),
        'last_called_at': called?.toIso8601String(),
        'last_called_by': called == null ? '' : 'you@demo',
        'converted': converted,
        'credited_to': credited,
      };

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final raw = request is http.Request ? request.body : '';
    final body = raw.isEmpty ? null : jsonDecode(raw);
    final out = _answer(request.method, request.url.path, request.url.queryParameters, body);
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return http.StreamedResponse(Stream.value(utf8.encode(jsonEncode(out))), 200,
        headers: {'content-type': 'application/json'});
  }

  static const _me = {'login': 'you@demo', 'name': 'You (demo)', 'role': 'manager', 'team_lead': true};

  dynamic _answer(String method, String path, Map<String, String> query, dynamic body) {
    final parts = path.split('/').where((s) => s.isNotEmpty).toList();
    if (path == '/manager/login' || path == '/auth/login') return {'token': 'demo', 'jwt_token': 'demo'};
    if (path == '/crm/my-queue') return {'me': _me, 'leads': _leads.values.where((l) => l['heat']['temperature'] != 'out').toList()};
    if (path == '/crm/labels') return {'labels': _labels};
    if (path == '/crm/messages') {
      final now = DateTime.now();
      String ago(int m) => now.subtract(Duration(minutes: m)).toIso8601String();
      return {
        'totals': {'sent': 3, 'received': 1, 'replied_people': 1, 'failed': 1},
        'messages': [
          {'phone': '0900000001', 'name': 'Riya (sample)', 'direction': 'in', 'status': 'received', 'by': '', 'body': 'Haan, Saturday demo mein aaungi', 'at': ago(5)},
          {'phone': '0900000001', 'name': 'Riya (sample)', 'direction': 'out', 'status': 'sent', 'by': 'Jarvis', 'body': 'Hi Riya, Saturday 6 pm ki free demo class mein aaoge?', 'at': ago(40)},
          {'phone': '0900000002', 'name': 'Aman (sample)', 'direction': 'out', 'status': 'sent', 'by': 'Follow-up automation', 'body': 'Your seat for the ESP32 batch is still open.', 'at': ago(90)},
          {'phone': '0900000003', 'name': '', 'direction': 'out', 'status': 'failed', 'by': 'Bulk message', 'body': 'New batch starts Monday.', 'at': ago(120)},
          {'phone': '0900000002', 'name': 'Aman (sample)', 'direction': 'out', 'status': 'sent', 'by': 'WhatsApp AI', 'body': 'Fees ke liye hamari team aapko call karegi.', 'at': ago(200)},
        ],
      };
    }
    if (path == '/crm/quick-wa') {
      return {
        'messages': [
          {'kind': 'missed_call', 'text': 'We tried calling you but could not get through.'},
          {'kind': 'roadmap', 'text': 'As promised on the call, here is the programme roadmap.'},
          {'kind': 'thanks', 'text': 'Thank you for your time on the call today.'},
        ]
      };
    }
    if (path == '/crm/team') return {'team': _team};
    if (path == '/crm/unassigned') return {'leads': _unassigned};
    if (path == '/crm/assign') {
      final phones = ((body?['phones'] as List?) ?? const []).map((e) => '$e').toSet();
      _unassigned.removeWhere((l) => phones.contains(l['phone']));
      return {'assigned': phones.length, 'by_owner': {}};
    }
    if (path == '/crm/team-stats') return _stats();
    if (path == '/crm/calls/sync') return _sync((body as Map).cast<String, dynamic>());
    if (parts.length >= 3 && parts[0] == 'crm' && parts[1] == 'caller-id') {
      final l = _leads[parts[2]];
      return l == null
          ? {'known': false, 'phone': parts[2]}
          : {'known': true, ...l, 'next_step': l['next_followup_at'] == null ? '' : 'Follow-up due', 'mine': true};
    }
    if (parts.length == 4 && parts[1] == 'leads') {
      final phone = parts[2];
      if (parts[3] == 'calls') return _log(phone, (body as Map).cast<String, dynamic>());
      if (parts[3] == 'timeline') return _timeline(phone);
      if (parts[3] == 'quick-wa') return {'sent': true};
    }
    return {};
  }

  Map<String, dynamic> _log(String phone, Map<String, dynamic> b) {
    final id = '${b['client_id']}';
    final dup = !_seen.add(id);
    final lead = _leads.putIfAbsent(
        phone, () => _lead(phone, '${b['name'] ?? ''}'.isEmpty ? phone : '${b['name']}', 'cold', 0));
    if (!dup) {
      _calls.add({...b, 'by': 'you@demo'});
      final heat = Map<String, dynamic>.from(lead['heat'] as Map);
      var score = (heat['score'] as num).toInt();
      score += const {'hot': 35, 'warm': 15, 'cold': -10, 'not_interested': -40}[b['interest']] ?? 0;
      if (b['outcome'] == 'connected') score += 10;
      if (const {'no_answer', 'busy', 'switched_off'}.contains(b['outcome'])) score -= 10;
      final stage = '${b['stage'] ?? ''}'.isNotEmpty
          ? '${b['stage']}'
          : (b['outcome'] == 'connected' && lead['stage'] == 'new' ? 'contacted' : lead['stage']);
      final out = b['outcome'] == 'wrong_number' || stage == 'lost';
      final customer = stage == 'enrolled';
      final temp = out ? 'out' : customer ? 'customer' : score >= 50 ? 'hot' : score >= 20 ? 'warm' : 'cold';
      final pct = out ? 0 : customer ? 100 : score.clamp(0, 100);
      lead
        ..['stage'] = stage
        ..['heat'] = {'temperature': temp, 'score': score, 'pct': pct, 'reasons': <String>[]}
        ..['score_pct'] = pct
        ..['next_followup_at'] = b['next_followup_at']
        ..['last_called_at'] = b['started_at']
        ..['last_called_by'] = 'you@demo'
        ..['converted'] = customer
        ..['credited_to'] = customer ? 'you@demo' : '';
      if (b['labels'] != null) lead['labels'] = b['labels'];
      final note = stage == 'lost' ? 'Lost: ${b['lost_reason']}' : '${b['note'] ?? ''}';
      if (note.isNotEmpty) lead['last_note'] = note;
    }
    return {'call_id': _calls.length, 'duplicate': dup, 'applied': true, 'lead': lead};
  }

  /// The phone's real calls, as the CRM's sync takes them: each number becomes a lead named from the contacts, and its
  /// heat follows the calls (they rang us, time spent talking, rings nobody answered). Still only in memory.
  Map<String, dynamic> _sync(Map<String, dynamic> b) {
    var synced = 0, made = 0, skipped = 0;
    for (final c in ((b['calls'] as List?) ?? const []).whereType<Map>()) {
      final d = '${c['phone']}'.replaceAll(RegExp(r'[^0-9]'), '');
      final phone = d.length >= 10 ? d.substring(d.length - 10) : '';
      final id = 'dev-$phone-${c['started_at']}';
      if (phone.isEmpty || !_seen.add(id) || (!_leads.containsKey(phone) && b['add_new'] == false)) {
        skipped++;
        continue;
      }
      if (!_leads.containsKey(phone)) {
        final name = '${c['contact_name'] ?? ''}';
        _leads[phone] = _lead(phone, name.isEmpty ? phone : name, 'cold', 0, note: 'Added from a phone call');
        made++;
      }
      final missed = c['missed'] == true;
      final talked = (c['duration_s'] as num?)?.toInt() ?? 0;
      _calls.add({
        'phone': phone,
        'started_at': c['started_at'],
        'direction': c['direction'],
        'duration_s': talked,
        'outcome': missed ? 'missed' : (talked > 0 ? 'connected' : 'no_answer'),
        'by': 'you@demo',
      });
      final lead = _leads[phone]!;
      var score = ((lead['heat'] as Map)['score'] as num).toInt();
      if (c['direction'] == 'in') score += 15;
      if (talked >= 300) score += 10;
      if (talked > 0) score += 10;
      if (talked == 0 && c['direction'] == 'out') score -= 10;
      final temp = score >= 50 ? 'hot' : score >= 20 ? 'warm' : 'cold';
      lead
        ..['heat'] = {'temperature': temp, 'score': score, 'pct': score.clamp(0, 100), 'reasons': <String>[]}
        ..['score_pct'] = score.clamp(0, 100)
        ..['last_called_at'] = c['started_at']
        ..['stage'] = talked > 0 && lead['stage'] == 'new' ? 'contacted' : lead['stage'];
      synced++;
    }
    return {'synced': synced, 'new_leads': made, 'skipped': skipped};
  }

  Map<String, dynamic> _timeline(String phone) {
    final lead = _leads[phone] ?? _lead(phone, phone, 'cold', 0);
    final events = <Map<String, dynamic>>[
      for (final c in _calls.where((c) => c['phone'] == phone))
        {
          'kind': 'call',
          'at': c['started_at'],
          'by': 'You',
          'direction': c['direction'],
          'duration_s': c['duration_s'],
          'outcome': c['outcome'],
          'interest': c['interest'] ?? '',
          'stage_after': c['stage'] ?? '',
          'lost_reason': c['lost_reason'] ?? '',
          'text': c['note'] ?? '',
        },
      if ('${lead['last_note']}'.isNotEmpty && _calls.every((c) => c['phone'] != phone))
        {'kind': 'note', 'at': _clock().toUtc().subtract(const Duration(days: 1)).toIso8601String(), 'by': 'Riya', 'text': lead['last_note']},
      {
        'kind': 'whatsapp',
        'at': _clock().toUtc().subtract(const Duration(days: 2)).toIso8601String(),
        'direction': 'in',
        'text': 'Hi, I saw your post about the embedded systems programme.'
      },
    ]..sort((a, b) => '${b['at']}'.compareTo('${a['at']}'));
    return {'lead': lead, 'events': events, 'next_step': lead['next_followup_at'] == null ? '' : 'Follow-up set'};
  }

  Map<String, dynamic> _stats() {
    final calls = _calls.length;
    final connected = _calls.where((c) => c['outcome'] == 'connected').length;
    final talk = _calls.where((c) => c['outcome'] == 'connected').fold<int>(0, (a, c) => a + ((c['duration_s'] as num?)?.toInt() ?? 0));
    final you = {
      'login': 'you@demo', 'name': 'You', 'calls': calls, 'connected': connected,
      'connected_pct': calls == 0 ? 0 : (100 * connected / calls).round(), 'talk_time_s': talk,
      'followups_done': 0, 'followups_missed': 1, 'interested': _calls.where((c) => c['interest'] == 'hot' || c['interest'] == 'warm').length,
      'conversions': 1,
    };
    final team = [
      {'login': 'riya@demo', 'name': 'Riya', 'calls': 42, 'connected': 25, 'connected_pct': 60, 'talk_time_s': 5400,
        'followups_done': 11, 'followups_missed': 2, 'interested': 7, 'conversions': 2},
      you,
      {'login': 'sahil@demo', 'name': 'Sahil', 'calls': 30, 'connected': 14, 'connected_pct': 47, 'talk_time_s': 3100,
        'followups_done': 6, 'followups_missed': 4, 'interested': 3, 'conversions': 0},
    ];
    return {'days': 1, 'team': team, 'totals': {}};
  }
}
