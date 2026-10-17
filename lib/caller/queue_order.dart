// The order of the Today queue. The server sorts it (crm_calls.bucket / queue_key) and this is the same rule, so a call
// logged with no signal moves its lead at once instead of waiting for the next sync. Change both together.

import 'models.dart';

const buckets = ['due', 'hot', 'warm', 'new', 'rest', 'later', 'converted'];

const bucketTitles = {
  'due': 'Follow-ups due now',
  'hot': 'Hot',
  'warm': 'Warm',
  'new': 'New, not called yet',
  'rest': 'Everyone else',
  'later': 'Follow-ups later',
  'converted': 'Converted 🎉',
};

String bucketOf(Lead l, DateTime now) {
  final t = l.heat.temperature;
  if (t == 'customer' || l.converted) return 'converted';
  final f = l.nextFollowupAt;
  if (f != null && !f.isAfter(now)) return 'due';
  if (f != null) return 'later';
  if (t == 'hot') return 'hot';
  if (t == 'warm') return 'warm';
  if (l.stage == 'new' && l.lastCalledAt == null) return 'new';
  return 'rest';
}

/// Everyone still worth a call, in order: due follow-ups (oldest first), hot, warm, new and never called, the rest,
/// follow-ups set for later (soonest first), then converted. Hottest first inside each group. Leads who are out (STOP,
/// lost, wrong number) are left out.
List<Lead> sortQueue(Iterable<Lead> leads, DateTime now) {
  final keep = leads.where((l) => l.heat.temperature != 'out').toList();
  int when(Lead l, String b) => (b == 'due' || b == 'later') ? (l.nextFollowupAt?.millisecondsSinceEpoch ?? 0) : 0;
  keep.sort((a, b) {
    final ba = bucketOf(a, now), bb = bucketOf(b, now);
    final c1 = buckets.indexOf(ba).compareTo(buckets.indexOf(bb));
    if (c1 != 0) return c1;
    final c2 = when(a, ba).compareTo(when(b, bb));
    if (c2 != 0) return c2;
    final c3 = b.heat.score.compareTo(a.heat.score);
    if (c3 != 0) return c3;
    return a.phone.compareTo(b.phone);
  });
  return keep;
}
