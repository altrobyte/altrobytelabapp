// Altron Live teaching a course: it reads the step from the course, answers for the learner through the course, and never
// gets a quiz's answer. Runs against the stand-in helper of desktop_helper_test.dart.

import 'dart:async';

import 'package:altrobytelab/desktop/live_course.dart';
import 'package:altrobytelab/desktop/live_tutor_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_windows/webview_windows.dart';

import 'desktop_helper_test.dart' as helper;

void main() {
  group('which option a spoken answer means', () {
    const options = ['It is the pump that pushes the water', 'It is the water', 'It is the tap handle'];

    test('a number, a number word, an ordinal or a letter', () {
      expect(matchOption('2', options), 1);
      expect(matchOption('option two', options), 1);
      expect(matchOption('the third one', options), 2);
      expect(matchOption('doosra', options), 1);
      expect(matchOption('B', options), 1);
      expect(matchOption('option c', options), 2);
      expect(matchOption('I think number 1', options), 0);
    });

    test("the option's own words", () {
      expect(matchOption('the pump that pushes it', options), 0);
      expect(matchOption('tap handle', options), 2);
    });

    test('nothing clear is not guessed', () {
      expect(matchOption('', options), isNull);
      expect(matchOption('hmm I am not sure', options), isNull);
      expect(matchOption('9', options), isNull);
      expect(matchOption('it is', options), isNull);
      expect(matchOption('a long sentence that says a word like do without meaning two of anything', options), isNull);
    });
  });

  test('what is said aloud has no markdown marks', () {
    expect(spoken('**Idea 1:** build *products*, not `projects`.'), 'Idea 1: build products, not projects.');
  });

  group('the course tools', () {
    test('the step comes from the course, with the card on screen and never its answer', () async {
      final h = helper.FakeHelper();
      final c = h.controller();
      await c.init();
      await c.start(course: 'intro_roadmap');
      h.emit('message', {'text': '**Idea 2: one product, four stages.**'});
      h.emit('ui', {'type': 'quiz', 'props': {'milestone': 'four_stages', 'question': 'In what order?', 'options': ['AI first', 'Cloud first', 'Device, online, industrial, AI']}});
      h.emit('turn_done', {'finished': false});
      await helper.settle();
      final step = courseStep(c);
      expect(step['course_says'], 'Idea 2: one product, four stages.');
      expect(step['card_on_screen'], {'type': 'quick question', 'question': 'In what order?', 'options': ['1. AI first', '2. Cloud first', '3. Device, online, industrial, AI']});
      expect(step.toString().contains('answer'), isFalse);
      c.dispose();
    });

    test("a spoken answer goes to the course as the tap would, and the course's reply comes back", () async {
      final h = helper.FakeHelper();
      final c = h.controller();
      await c.init();
      await c.start(course: 'intro_roadmap');
      h.emit('ui', {'type': 'quiz', 'props': {'milestone': 'four_stages', 'question': 'In what order?', 'options': ['AI first', 'Cloud first', 'Device, online, industrial, AI']}});
      h.emit('turn_done', {'finished': false});
      await helper.settle();
      final bridge = CourseLiveBridge(c);
      final pending = bridge.run('answer_for_learner', {'answer': 'the third one'}, heard: 'I think the third one');
      await helper.settle();
      expect(h.bodies.last, {'text': '[quiz answer] milestone=four_stages choice=2'});
      expect(bridge.toolTurn, isTrue);                                                  // the screen will not tell Altron its own answer
      h.emit('message', {'text': 'Correct! Device, online, industrial, AI.'});
      h.emit('message', {'text': '**Stage 1: a smart bulb.**'});
      h.emit('turn_done', {'finished': false});
      final out = await pending;
      expect(out['given_to_the_course'], 'Device, online, industrial, AI');
      expect(out['course_replied'], 'Correct! Device, online, industrial, AI.\n\nStage 1: a smart bulb.');
      expect((out['now'] as Map)['card_on_screen'], startsWith('none'));
      c.dispose();
    });

    test('an unclear answer is not sent; Altron is asked to get the number', () async {
      final h = helper.FakeHelper();
      final c = h.controller();
      await c.init();
      await c.start(course: 'intro_roadmap');
      h.emit('ui', {'type': 'quiz', 'props': {'milestone': 'm', 'question': 'Q?', 'options': ['Alpha', 'Beta']}});
      h.emit('turn_done', {'finished': false});
      await helper.settle();
      final sent = h.bodies.length;
      final out = await CourseLiveBridge(c).run('answer_for_learner', {'answer': 'no idea'}, heard: 'no idea');
      expect(out['ok'], isFalse);
      expect(h.bodies.length, sent);
      c.dispose();
    });

    test('a reply step takes the spoken words as an ordinary message', () async {
      final h = helper.FakeHelper();
      final c = h.controller();
      await c.init();
      await c.start(course: 'intro_roadmap');
      h.emit('ui', {'type': 'replies', 'props': {'options': ['Student, in college', 'Just exploring']}});
      h.emit('turn_done', {'finished': false});
      await helper.settle();
      final pending = CourseLiveBridge(c).run('answer_for_learner', {'answer': 'I am in my third year'}, heard: 'I am in my third year');
      await helper.settle();
      expect(h.bodies.last, {'text': 'I am in my third year'});
      h.emit('turn_done', {'finished': false});
      await pending.timeout(const Duration(seconds: 5));
      c.dispose();
    });

    test("on a quiz the learner's own words decide, not the option the model names", () async {
      final h = helper.FakeHelper();
      final c = h.controller();
      await c.init();
      await c.start(course: 'intro_roadmap');
      h.emit('ui', {'type': 'quiz', 'props': {'milestone': 'm', 'question': 'Q?', 'options': ['Alpha', 'Beta']}});
      h.emit('turn_done', {'finished': false});
      await helper.settle();
      final sent = h.bodies.length;
      final out = await CourseLiveBridge(c).run('answer_for_learner', {'answer': '2'}, heard: 'haan samajh gaya aage batao');
      expect(out['ok'], isFalse);
      expect(h.bodies.length, sent);
      c.dispose();
    });

    test('Altron cannot answer for the learner when the learner said nothing', () async {
      final h = helper.FakeHelper();
      final c = h.controller();
      await c.init();
      await c.start(course: 'intro_roadmap');
      h.emit('ui', {'type': 'quiz', 'props': {'milestone': 'm', 'question': 'Q?', 'options': ['Alpha', 'Beta']}});
      h.emit('turn_done', {'finished': false});
      await helper.settle();
      final sent = h.bodies.length;
      final out = await CourseLiveBridge(c).run('answer_for_learner', {'answer': '1'});
      expect(out['ok'], isFalse);
      expect('${out['note']}', contains('has not said an answer'));
      expect(h.bodies.length, sent); // nothing reached the course
      c.dispose();
    });

    test('a spoken reply is sent as the suggested reply it means', () async {
      final h = helper.FakeHelper();
      final c = h.controller();
      await c.init();
      await c.start(course: 'intro_first_program');
      h.emit('ui', {'type': 'replies', 'props': {'options': ["It's open", "I can't find it"]}});
      h.emit('turn_done', {'finished': false});
      await helper.settle();
      final pending = CourseLiveBridge(c).run('answer_for_learner', {'answer': 'it is already open'}, heard: "It's already open.");
      await helper.settle();
      expect(h.bodies.last, {'text': "It's open"});
      h.emit('turn_done', {'finished': false});
      await pending.timeout(const Duration(seconds: 5));
      c.dispose();
    });

    test('with no course open the tools say so', () async {
      final h = helper.FakeHelper();
      final c = h.controller();
      await c.init();
      expect(await CourseLiveBridge(c).run('get_current_step', {}), {'error': 'No course is open.'});
      c.dispose();
    });
  });

  group('the Live page', () {
    test('version 2: the course, the language and autostart in the query, the sign-in in the #fragment', () {
      final uri = Uri.parse(liveV2Url('https://live.altron.example/index.html', course: 'intro_roadmap', lang: 'hi', token: 'a.b/c'));
      expect(uri.host, 'live.altron.example');
      expect(uri.queryParameters, {'course': 'intro_roadmap', 'lang': 'hi', 'compact': '1', 'autostart': '1'});
      expect(Uri.decodeComponent(uri.fragment.substring(2)), 'a.b/c');
      expect(Uri.parse(liveV2Url('https://altrobytelab.com/live/v2/index.html', noteId: 7, compact: false)).queryParameters, {'note': '7', 'lang': 'en', 'autostart': '1'});
    });

    test("the app's own copy may use the camera and the microphone, nothing else may", () {
      expect(livePermission('https://live.altron.example/index.html?course=x', WebviewPermissionKind.microphone), WebviewPermissionDecision.allow);
      expect(livePermission('https://live.altron.example.evil.com/', WebviewPermissionKind.camera), WebviewPermissionDecision.deny);
      expect(livePermission('https://altrobytelab.com/live/v2/index.html', WebviewPermissionKind.camera), WebviewPermissionDecision.allow);
    });

    test('a message from the page is read whether it arrives as a string or a map', () {
      expect(liveMessage('{"type":"tool","id":"1"}'), {'type': 'tool', 'id': '1'});
      expect(liveMessage({'type': 'state'}), {'type': 'state'});
      expect(liveMessage('not json'), isNull);
      expect(liveMessage(42), isNull);
    });
  });

  unawaited(Future.value());
}
