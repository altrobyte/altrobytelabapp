import 'package:flutter_test/flutter_test.dart';
import 'package:altrobytelab/desktop/visual_page.dart';

void main() {
  test('the note bridge goes in the head, never inside a script that mentions </body>', () {
    const note = '<html><head><title>x</title></head><body><h2>A</h2>'
        '<script>var tpl = "<p>hi</p></body>"; document.body.insertAdjacentHTML("beforeend", tpl);</script>'
        '<select id="s"><option>Red</option><option>Blue</option></select></body></html>';
    final page = tutorPage(note);
    final bridge = page.indexOf('window.__altroShow');
    expect(bridge, greaterThan(0));
    expect(bridge, lessThan(page.indexOf('<title>')));          // in the head, before anything of the note
    expect(page.contains('var tpl = "<p>hi</p></body>"'), isTrue);  // the note's own script untouched
    expect(page.indexOf('window.__altroShow'), page.lastIndexOf('window.__altroShow'));   // once
    expect(page.contains('tapSelects'), isTrue);
  });

  test('a note with no head still gets the bridge before its content', () {
    final page = tutorPage('<h2>A</h2><p>text</p>');
    expect(page.indexOf('window.__altroShow'), lessThan(page.indexOf('<h2>A</h2>')));
  });
}
