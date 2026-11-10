// node preview/datalogger/engine.test.js  -- uptime, gaps, dedupe/late data, abstraction and alarm rules.
const assert = require('assert');
const DL = require('./engine.js');
const I = 900, D0 = 1761935400;               // 1 Nov 2026 00:00 IST
const mk = (seq, k, total) => ({ seq, ts: D0 + k * I, rx: D0 + k * I + 2, flow: 10, total, pump: true });

// availability: a full day is 96 slots; two missing hours make one gap of 8 slots
let day = []; for (let k = 0; k < 96; k++) if (k < 40 || k >= 48) day.push(mk(k + 1, k, k));
let av = DL.availability(day, D0, D0 + 86400, I);
assert.strictEqual(av.expected, 96); assert.strictEqual(av.received, 88);
assert.strictEqual(av.pct.toFixed(2), '91.67');
assert.deepStrictEqual(av.gaps, [{ from: D0 + 40 * I, to: D0 + 48 * I, dur: 8 * I }]);
// a period still running counts only up to now
assert.strictEqual(DL.availability(day, D0, D0 + 10 * I, I).pct, 100);

// dedupe on seq, and late (back-filled) data lands in time order and closes the gap
const s = new DL.Store();
day.forEach(r => s.add(r));
assert.strictEqual(s.add(mk(5, 4, 4)), false); assert.strictEqual(s.dupes, 1);
for (let k = 40; k < 48; k++) s.add({ ...mk(200 + k, k, k), rx: D0 + 86400 });
assert.strictEqual(s.list.length, 96);
assert.ok(s.list.every((r, i) => !i || s.list[i - 1].ts <= r.ts));
assert.strictEqual(DL.availability(s.list, D0, D0 + 86400, I).pct, 100);

// abstraction comes from the totalizer, so a data gap loses no water
const t2 = [{ seq: 1, ts: D0 - I, total: 1000 }, { seq: 2, ts: D0 + I, total: 1010 }, { seq: 3, ts: D0 + 80000, total: 1150 }];
assert.strictEqual(DL.abstraction(t2, D0, D0 + 86400), 150);
assert.strictEqual(DL.abstraction(t2, D0 + 86400, D0 + 2 * 86400), null);

// alarm rules: a long gap is a no-data alarm; a day over the NOC limit; pump on with no flow for an hour
const al = DL.historyAlarms(day.map(r => ({ ...r, total: r.seq * 2 })), { from: D0, to: D0 + 86400, interval: I, noDataMin: 30, permittedDay: 100 });
assert.ok(al.some(a => a.type === 'no_data' && /120 min/.test(a.text)));
assert.ok(al.some(a => a.type === 'over_noc'));
const np = []; for (let k = 0; k < 8; k++) np.push({ seq: k + 1, ts: D0 + k * I, flow: k < 6 ? 0 : 9, total: 1, pump: true });
assert.ok(DL.historyAlarms(np, { from: D0, to: D0 + 8 * I, interval: I, noDataMin: 30, permittedDay: 1e9 }).some(a => a.type === 'no_pulse'));

// live no-data rule
assert.ok(DL.noData({ lastRx: 1000 }, 1000 + 31 * 60, 30)); assert.ok(!DL.noData({ lastRx: 1000 }, 1000 + 29 * 60, 30));

// the simulator: deterministic, seq strictly increasing, some readings arrive late
const a = DL.simulate({ seed: 7, rate: 9, startTotal: 5000 }, D0, D0 + 20 * 86400, I);
const b = DL.simulate({ seed: 7, rate: 9, startTotal: 5000 }, D0, D0 + 20 * 86400, I);
assert.deepStrictEqual(a.readings.slice(0, 50), b.readings.slice(0, 50));
assert.ok(a.readings.every((r, i) => !i || r.seq > a.readings[i - 1].seq));
console.log('engine: all checks passed');
