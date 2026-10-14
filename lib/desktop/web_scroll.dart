// Two-finger scrolling for a page shown in the Windows web view.
//
// A touchpad swipe reaches Flutter as many tiny movements, not the web view. Sending each one to the page separately made
// scrolling lag, and pages that ask for "smooth" scrolling animated every tiny step on top of that. Here the movements of one
// frame are added up and sent together, as an instant scroll, and a little glide carries on after the fingers lift.

import 'dart:async';
import 'dart:ui' show Offset;

/// The script that scrolls the page by this much, at once (never animated).
String scrollScript(double dx, double dy) =>
    "window.scrollBy({left:${dx.toStringAsFixed(1)},top:${dy.toStringAsFixed(1)},behavior:'instant'})";

class PanScroller {
  final void Function(String script) run;
  final Duration frame;

  /// How far the page moves for a movement of the fingers. The touchpad's raw movement scrolled a note far faster than
  /// any other window on the computer, so it is scaled down.
  final double speed;
  PanScroller(this.run, {this.frame = const Duration(milliseconds: 12), this.speed = 0.55});

  static const _maxGlideStep = 22.0; // a glide never starts faster than this per frame, however hard the flick
  static const _slowDown = 0.82;     // each frame of the glide keeps this much of the last one's speed

  double _dx = 0, _dy = 0; // waiting to be sent
  double _vx = 0, _vy = 0; // the last frame's movement: the speed the fingers left at
  Timer? _flush;
  Timer? _glide;

  /// The fingers moved by [delta] (the page moves the other way).
  void add(Offset delta) {
    _glide?.cancel();
    _glide = null;
    _dx -= delta.dx * speed;
    _dy -= delta.dy * speed;
    _flush ??= Timer(frame, _send);
  }

  void _send() {
    _flush = null;
    if (_dx == 0 && _dy == 0) return;
    _vx = _dx;
    _vy = _dy;
    run(scrollScript(_dx, _dy));
    _dx = 0;
    _dy = 0;
  }

  /// The fingers lifted: keep going for a moment, slowing down, the way every other window on the computer does.
  void end() {
    _flush?.cancel();
    _send();
    _glide?.cancel();
    _vx = _vx.clamp(-_maxGlideStep, _maxGlideStep);
    _vy = _vy.clamp(-_maxGlideStep, _maxGlideStep);
    _glide = Timer.periodic(frame, (t) {
      _vx *= _slowDown;
      _vy *= _slowDown;
      if (_vx.abs() < 0.8 && _vy.abs() < 0.8) {
        t.cancel();
        _glide = null;
        return;
      }
      run(scrollScript(_vx, _vy));
    });
  }

  void dispose() {
    _flush?.cancel();
    _glide?.cancel();
  }
}
