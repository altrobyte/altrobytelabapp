import 'dart:ui' show Offset;
import 'package:flutter_test/flutter_test.dart';
import 'package:altrobytelab/desktop/web_scroll.dart';

void main() {
  test('the movements of one frame are sent together, as an instant scroll the other way', () async {
    final sent = <String>[];
    final p = PanScroller(sent.add, frame: const Duration(milliseconds: 5));
    p.add(const Offset(0, -4));
    p.add(const Offset(0, -6));
    p.add(const Offset(1, -10));
    expect(sent, isEmpty); // nothing per movement
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(sent, ["window.scrollBy({left:-1.0,top:20.0,behavior:'instant'})"]);
    p.dispose();
  });

  test('lifting the fingers glides on and then stops by itself', () async {
    final sent = <String>[];
    final p = PanScroller(sent.add, frame: const Duration(milliseconds: 2));
    p.add(const Offset(0, -30));
    p.end();
    expect(sent.length, 1); // what was waiting goes out at once
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final n = sent.length;
    expect(n, greaterThan(5));
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(sent.length, n); // it has stopped
    p.dispose();
  });

  test('a new swipe cancels the glide of the last one', () async {
    final sent = <String>[];
    final p = PanScroller(sent.add, frame: const Duration(milliseconds: 2));
    p.add(const Offset(0, -30));
    p.end();
    p.add(const Offset(0, 5)); // fingers down again, the other way
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(sent.last, "window.scrollBy({left:0.0,top:-5.0,behavior:'instant'})");
    expect(sent.length, 2);
    p.dispose();
  });
}
