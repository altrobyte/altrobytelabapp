// node tools/pace.test.js
const assert = require('assert');
const P = require('../web/live/pace.js');
const SR = 24000;

function voice(sec) { const f = new Float32Array(sec * SR); for (let i = 0; i < f.length; i++) f[i] = 0.3 * Math.sin(i * 0.05); return f; }
function quiet(sec) { const f = new Float32Array(sec * SR); for (let i = 0; i < f.length; i++) f[i] = 0.002 * Math.sin(i * 0.3); return f; }
function join(...a) { const out = new Float32Array(a.reduce((n, x) => n + x.length, 0)); let o = 0; for (const x of a) { out.set(x, o); o += x.length; } return out; }
function loud(f) { let n = 0; for (const v of f) if (Math.abs(v) >= 0.012) n++; return n; }
function inChunks(f, size) { let n = 0, all = []; for (let i = 0; i < f.length; i += size) { const c = P.stretch(f.slice(i, i + size)); n += c.length; all.push(c); } return { n, all: join(...all) }; }

// normal: nothing is touched
P.set('normal');
const talk = join(voice(1), quiet(0.4), voice(1));
assert.strictEqual(P.stretch(talk), talk);
assert.strictEqual(P.rate(), 1);

// easy: a 0.4 s pause grows by the part past the first 120 ms (0.28 s); the speech itself is untouched
P.set('easy');
let out = P.stretch(talk);
assert.ok(Math.abs((out.length - talk.length) / SR - 0.28) < 0.02, 'easy adds ' + (out.length - talk.length) / SR);
assert.strictEqual(loud(out), loud(talk));
assert.strictEqual(P.rate(), 0.95);

// the gap inside a word (80 ms) is never lengthened
P.reset();
const word = join(voice(0.5), quiet(0.08), voice(0.5));
assert.strictEqual(P.stretch(word).length, word.length);

// a long silence is lengthened only up to the cap
P.reset();
const long = join(voice(0.2), quiet(3), voice(0.2));
out = P.stretch(long);
assert.ok(Math.abs((out.length - long.length) / SR - 0.7) < 0.02, 'cap ' + (out.length - long.length) / SR);

// slow: twice as much, capped at 1.2 s
P.set('slow');
out = P.stretch(talk);
assert.ok(Math.abs((out.length - talk.length) / SR - 0.56) < 0.03, 'slow adds ' + (out.length - talk.length) / SR);
P.reset();
assert.ok(Math.abs((P.stretch(long).length - long.length) / SR - 1.2) < 0.03);

// the same result whether the voice arrives whole or in small odd-sized chunks (a pause spans chunks)
P.set('easy');
const whole = P.stretch(talk).length;
P.reset();
const parts = inChunks(talk, 1111);
assert.ok(Math.abs(parts.n - whole) <= 480, parts.n + ' vs ' + whole);
assert.strictEqual(loud(parts.all), loud(talk));

// the button goes round the levels; "not clear" only ever makes it slower
P.set('easy');
assert.strictEqual(P.next(), 'slow'); assert.strictEqual(P.next(), 'normal'); assert.strictEqual(P.next(), 'easy');
P.set('normal'); assert.strictEqual(P.slower(), 'easy'); assert.strictEqual(P.slower(), 'slow'); assert.strictEqual(P.slower(), 'slow');
assert.strictEqual(P.set('nonsense'), 'slow');
console.log('pace: ok');
