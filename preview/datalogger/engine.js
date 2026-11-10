// Altrobyte Remote Data Logger: the demo's core logic (10 Nov 2026). Plain JS, no DOM, so node can test it.
// Readings: {seq, ts (device time, epoch s), rx (server receive time), flow (m3/h), total (m3 totalizer)}.
(function (root) {
  'use strict';

  // A small seeded random generator, so the demo's history is the same on every load.
  function rng(seed) {
    return function () {
      seed = (seed + 0x6D2B79F5) | 0;
      var t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
      t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
  }

  // A device's store: readings kept in time order, deduplicated on seq (a back-filled reading sent twice counts once).
  function Store() { this.list = []; this.seen = {}; this.lastRx = 0; this.dupes = 0; }
  Store.prototype.add = function (r) {
    if (this.seen[r.seq]) { this.dupes++; return false; }
    this.seen[r.seq] = true;
    var a = this.list, i = a.length;
    if (!i || a[i - 1].ts <= r.ts) a.push(r);            // the usual case: in order
    else {                                                  // late (back-filled): put it where its time says
      var lo = 0, hi = i;
      while (lo < hi) { var mid = (lo + hi) >> 1; if (a[mid].ts <= r.ts) lo = mid + 1; else hi = mid; }
      a.splice(lo, 0, r);
    }
    if (r.rx > this.lastRx) this.lastRx = r.rx;
    return true;
  };
  Store.prototype.between = function (from, to) {
    return this.list.filter(function (r) { return r.ts >= from && r.ts < to; });
  };
  Store.prototype.last = function () { return this.list[this.list.length - 1] || null; };

  // Data availability for [from, to): the share of expected slots (one per interval) that hold a reading, and the gaps.
  // `to` should be min(period end, now) for a period still running, so the future is not counted as missing.
  function availability(readings, from, to, interval) {
    var expected = Math.max(0, Math.floor((to - from) / interval));
    if (!expected) return { expected: 0, received: 0, pct: 100, gaps: [] };
    var have = new Uint8Array(expected), received = 0;
    readings.forEach(function (r) {
      if (r.ts < from || r.ts >= to) return;
      var k = Math.floor((r.ts - from) / interval);
      if (k < expected && !have[k]) { have[k] = 1; received++; }
    });
    var gaps = [], start = -1;
    for (var k = 0; k <= expected; k++) {
      var missing = k < expected && !have[k];
      if (missing && start < 0) start = k;
      if (!missing && start >= 0) {
        gaps.push({ from: from + start * interval, to: from + k * interval, dur: (k - start) * interval });
        start = -1;
      }
    }
    return { expected: expected, received: received, pct: received * 100 / expected, gaps: gaps };
  }

  // Water taken out in [from, to): the meter's own totalizer, last reading minus the one before the period. The meter keeps
  // counting while the link is down, so a gap in the data does not lose water from the total.
  function abstraction(readings, from, to) {
    var before = null, last = null;
    for (var i = 0; i < readings.length; i++) {
      var r = readings[i];
      if (r.ts < from) before = r;
      else if (r.ts < to) last = r;
      else break;
    }
    if (!last) return null;
    var first = before || readings.find(function (r) { return r.ts >= from; });
    return Math.max(0, last.total - first.total);
  }

  // Alarms from the rules of the CGWA template, over the history (each with started/ended), plus the live no-data rule.
  function historyAlarms(readings, opt) {
    var out = [];
    var av = availability(readings, opt.from, opt.to, opt.interval);
    av.gaps.forEach(function (g) {
      if (g.dur > opt.noDataMin * 60) out.push({ type: 'no_data', sev: 'critical', start: g.from + opt.noDataMin * 60, end: g.to, text: 'No data from the meter for ' + Math.round(g.dur / 60) + ' min' });
    });
    for (var d = opt.from; d < opt.to; d += 86400) {
      var used = abstraction(readings, d, d + 86400);
      if (used != null && used > opt.permittedDay) out.push({ type: 'over_noc', sev: 'warning', start: d + 86400 - 1, end: d + 86400 - 1, text: 'Daily abstraction ' + used.toFixed(1) + ' m³ is over the NOC limit of ' + opt.permittedDay + ' m³' });
    }
    var run = null;
    readings.forEach(function (r) {
      if (r.pump && r.flow === 0) { if (!run) run = { start: r.ts }; run.end = r.ts; }
      else { if (run && run.end - run.start >= 3600) out.push({ type: 'no_pulse', sev: 'critical', start: run.start, end: run.end, text: 'Pump running but no flow pulses: check the meter (possible tamper)' }); run = null; }
    });
    return out.sort(function (a, b) { return b.start - a.start; });
  }

  function noData(store, now, minutes) { var l = store.lastRx; return !!l && now - l > minutes * 60; }

  // The demo's meters: pumps run in two shifts, flow varies a little, with outages (some lost, some back-filled later) and
  // one no-pulse event. Returns {readings, pending}: pending = readings the device still holds in its buffer.
  function simulate(dev, start, now, interval) {
    var R = rng(dev.seed), out = [], seq = 1, total = dev.startTotal, outages = [], t;
    for (t = start + 86400 * 2; t < now - 86400; t += 86400) {
      if (R() < 0.18) { var s = t + Math.floor(R() * 20) * 3600, len = (1 + Math.floor(R() * 8)) * 3600; outages.push({ from: s, to: s + len, lost: R() < 0.45 }); }
    }
    if (dev.bigOutage) outages.push({ from: now - 86400 * dev.bigOutage, to: now - 86400 * dev.bigOutage + 30 * 3600, lost: true });
    var tamperDay = dev.tamper ? Math.floor((now - start) / 86400) - dev.tamper : -1;
    for (t = start; t < now; t += interval) {
      var h = new Date((t + 19800) * 1000).getUTCHours(), day = Math.floor((t - start) / 86400);
      var pump = (h >= 6 && h < 13) || (h >= 14 && h < 22);
      var flow = pump ? dev.rate * (0.9 + R() * 0.2) * (day % 9 === 4 && dev.heavy ? 1.25 : 1) : 0;
      var tampered = day === tamperDay && h >= 9 && h < 12;
      if (tampered) flow = 0;
      total += flow * interval / 3600;
      var o = outages.find(function (x) { return t >= x.from && t < x.to; });
      if (o && o.lost) continue;                                            // power cut: nothing recorded
      var r = { seq: seq++, ts: t, flow: Math.round(flow * 10) / 10, total: Math.round(total * 100) / 100, pump: pump, rx: o ? o.to + 60 : t + 2 };
      out.push(r);                                                            // buffered in an outage: arrives when the link is back
    }
    return { readings: out, seq: seq, total: total };
  }

  var api = { rng: rng, Store: Store, availability: availability, abstraction: abstraction, historyAlarms: historyAlarms, noData: noData, simulate: simulate };
  if (typeof module !== 'undefined' && module.exports) module.exports = api; else root.DL = api;
})(this);
