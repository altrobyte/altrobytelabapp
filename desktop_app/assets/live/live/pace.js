// Altron's speaking pace (10 Nov 2026, founder: "very fast for a tutorial and for a beginner"). Telling the model to speak
// slowly was tried twice and did not hold, so the pace is set here, where the voice is played:
//   1. the voice plays a little slower (playbackRate), and
//   2. the pauses it already makes between phrases and sentences are made longer, so there is time to take an idea in.
// Only silence is added to silence: no word is cut or changed. Plain JS with no DOM in the core, so node can test it.
(function (root) {
  'use strict';
  var LEVELS = {
    slow: { rate: 0.90, gain: 2, cap: 1.2, label: 'slow', icon: '🐢' },     // gain: seconds of silence added per second of pause
    easy: { rate: 0.95, gain: 1, cap: 0.7, label: 'easy', icon: '🚶' },     // cap: the most that one pause is lengthened by, in seconds
    normal: { rate: 1, gain: 0, cap: 0, label: 'fast', icon: '🏃' }
  };
  var ORDER = ['easy', 'slow', 'normal'], KEY = 'altron_pace', DEFAULT = 'easy';
  var SR = 24000, FRAME = 240, QUIET = 0.012, MIN = 0.12 * SR;   // 10 ms frames; a pause is 120 ms of quiet or more
  var level = DEFAULT, run = 0, added = 0;

  try { var kept = root.localStorage && root.localStorage.getItem(KEY); if (kept && LEVELS[kept]) level = kept; } catch (_) {}

  function set(l) {
    if (!LEVELS[l]) return level;
    level = l; reset();
    try { if (root.localStorage) root.localStorage.setItem(KEY, l); } catch (_) {}
    return level;
  }
  function next() { return set(ORDER[(ORDER.indexOf(level) + 1) % ORDER.length]); }
  function slower() { return set(level === 'normal' ? 'easy' : 'slow'); }
  function reset() { run = 0; added = 0; }

  // One chunk of the voice (Float32Array, 24 kHz) in, the same chunk out with its pauses made longer. The count of quiet
  // samples carries over from chunk to chunk, because a pause usually spans several of them.
  function stretch(f) {
    var L = LEVELS[level];
    if (!L.gain || !f.length) return f;
    var cap = L.cap * SR, out = new Float32Array(f.length * (1 + L.gain)), o = 0;
    for (var i = 0; i < f.length; i += FRAME) {
      var end = Math.min(f.length, i + FRAME), peak = 0, len = end - i;
      for (var j = i; j < end; j++) { var v = f[j] < 0 ? -f[j] : f[j]; if (v > peak) peak = v; }
      out.set(f.subarray(i, end), o); o += len;
      if (peak < QUIET) {
        run += len;
        if (run > MIN && added < cap) { var more = Math.min(len * L.gain, cap - added); o += more; added += more; }   // zeros
      } else { run = 0; added = 0; }
    }
    return o === f.length ? f : out.slice(0, o);
  }

  var api = {
    LEVELS: LEVELS, stretch: stretch, reset: reset, set: set, next: next, slower: slower,
    level: function () { return level; },
    rate: function () { return LEVELS[level].rate; },
    label: function () { return LEVELS[level].label; },
    icon: function () { return LEVELS[level].icon; }
  };
  if (typeof module !== 'undefined' && module.exports) module.exports = api; else root.AltronPace = api;
})(typeof window !== 'undefined' ? window : this);
