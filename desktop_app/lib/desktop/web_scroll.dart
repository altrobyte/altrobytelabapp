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
  PanScroller(this.run, {this.frame = const Duration(milliseconds: 12)});

  double _dx = 0, _dy = 0; // waiting to be sent
  double _vx = 0, _vy = 0; // the last frame's movement: the speed the fingers left at
  Timer? _flush;
  Timer? _glide;

  /// The fingers moved by [delta] (the page moves the other way).
  void add(Offset delta) {
    _glide?.cancel();
    _glide = null;
    _dx -= delta.dx;
    _dy -= delta.dy;
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
    _glide = Timer.periodic(frame, (t) {
      _vx *= 0.9;
      _vy *= 0.9;
      if (_vx.abs() < 0.6 && _vy.abs() < 0.6) {
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
