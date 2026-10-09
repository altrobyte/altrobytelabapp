// The tutor beside a note, without a window or a server: the calls are stand-ins.

import 'package:flutter_test/flutter_test.dart';
import 'package:altrobytelab/desktop/note_tutor.dart';
import 'package:altrobytelab/desktop/visual_page.dart';

class FakeServer {
  Map<String, dynamic> note = {
    'title': 'IoT & Edge',
    'html': '<html><head></head><body><h1>IoT</h1><h2>Edge</h2></body></html>',
    'sections': [
      {'id': 's0', 'title': 'What is IoT?'},
      {'id': 's1', 'title': 'Cloud vs Edge'},
    ],
    'guide': {
      's0': {'say': 'Think of things that learned to talk.', 'quiz': {'question': 'What makes a bulb IoT?', 'options': ['It is connected', 'It is bright']}},
      's1': {'say': 'Flip the toggle and watch the time.', 'quiz': null},
    },
    'guide_ready': true,
  };
  Map<String, dynamic> guideLater = {'guide_ready': false, 'guide': {}};
  final List<String> calls = [];
  Map<String, dynamic> quizReply = {'correct': true, 'explain': 'IoT is about being connected.'};
  Object? askError;

  NoteTutor tutor({Duration retry = const Duration(milliseconds: 10), int retries = 3}) => NoteTutor(41,
      loadNote: (id) async {
        calls.add('note $id');
        return note;
      },
      loadGuide: (id) async {
        calls.add('guide $id');
        return guideLater;
      },
      checkQuiz: (id, section, choice, tries) async {
        calls.add('quiz $section $choice $tries');
        return quizReply;
      },
      askTutor: (id, section, question, history) async {
        calls.add('ask $section $question ${history.length}');
        if (askError != null) throw askError!;
        return 'Because it is nearby.';
      },
      guideRetry: retry,
      guideRetries: retries);
}

void main() {
  test('opening a note greets, introduces the first section and offers its question', () async {
    final s = FakeServer();
    final t = s.tutor();
    await t.load();
    expect(t.loading, isFalse);
    expect(t.title, 'IoT & Edge');
    expect(t.current, 's0');
    expect(t.items.map((i) => i.kind), ['tutor', 'tutor', 'quiz']);
    expect(t.items[1].heading, 'What is IoT?');
    expect(t.items[1].text, 'Think of things that learned to talk.');
    expect(t.items[2].options, ['It is connected', 'It is bright']);
    t.dispose();
  });

  test('the tutor follows the section in view and says each thing once', () async {
    final s = FakeServer();
    final t = s.tutor();
    await t.load();
    t.readingIndex(1);
    expect(t.current, 's1');
    expect(t.items.last.text, 'Flip the toggle and watch the time.');
    final n = t.items.length;
    t.readingIndex(0); // back up the page: nothing is repeated
    t.readingIndex(1);
    t.readingIndex(7); // not a section of this note
    expect(t.items.length, n);
    expect(t.current, 's1');
    t.dispose();
  });

  test('a right answer settles the question with the reason; the server decided', () async {
    final s = FakeServer();
    final t = s.tutor();
    await t.load();
    final quiz = t.items.firstWhere((i) => i.kind == 'quiz');
    await t.answer(quiz, 0);
    expect(s.calls.last, 'quiz s0 0 1');
    expect(quiz.settled, isTrue);
    expect(t.items.last.text, 'Correct! IoT is about being connected.');
    await t.answer(quiz, 1); // already settled: nothing is sent
    expect(s.calls.where((c) => c.startsWith('quiz')).length, 1);
    t.dispose();
  });

  test('a wrong answer gets another try without the answer, and the second one is told kindly', () async {
    final s = FakeServer()..quizReply = {'correct': false};
    final t = s.tutor();
    await t.load();
    final quiz = t.items.firstWhere((i) => i.kind == 'quiz');
    await t.answer(quiz, 1);
    expect(quiz.settled, isFalse);
    expect(quiz.tries, 1);
    expect(quiz.picked, isNull);
    expect(t.items.last.text, contains('Not quite'));
    s.quizReply = {'correct': false, 'revealed': true, 'answer': 'It is connected', 'explain': 'IoT is about being connected.'};
    await t.answer(quiz, 1);
    expect(s.calls.last, 'quiz s0 1 2');
    expect(quiz.settled, isTrue);
    expect(t.items.last.text, contains('The answer is "It is connected"'));
    t.dispose();
  });

  test('a question is asked about the section being read, with the recent talk, and a failure is said calmly', () async {
    final s = FakeServer();
    final t = s.tutor();
    await t.load();
    t.readingIndex(1);
    await t.ask('  why is edge faster?  ');
    expect(s.calls.last, startsWith('ask s1 why is edge faster? '));
    expect(t.items[t.items.length - 2].kind, 'me');
    expect(t.items.last.text, 'Because it is nearby.');
    s.askError = Exception('The trainer is having a problem right now. Please try again in a minute.');
    await t.ask('and cloud?');
    expect(t.items.last.kind, 'system');
    expect(t.items.last.text, startsWith('The trainer is having a problem'));
    expect(t.asking, isFalse);
    await t.ask('   ');
    expect(s.calls.where((c) => c.startsWith('ask')).length, 2);
    t.dispose();
  });

  test('while the guide is still being prepared the plain one is used, and the questions arrive when it is ready', () async {
    final s = FakeServer();
    s.note = {
      ...s.note,
      'guide_ready': false,
      'guide': {
        's0': {'say': 'IoT means everyday things connected.', 'quiz': null},
        's1': {'say': 'Cloud is far away.', 'quiz': null},
      },
    };
    final t = s.tutor();
    await t.load();
    expect(t.guideReady, isFalse);
    expect(t.items.where((i) => i.kind == 'quiz'), isEmpty);
    s.guideLater = {
      'guide_ready': true,
      'guide': {
        's0': {'say': 'Better words.', 'quiz': {'question': 'Q?', 'options': ['a', 'b']}},
        's1': {'say': 'x', 'quiz': null},
      },
    };
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(t.guideReady, isTrue);
    expect(t.items.where((i) => i.kind == 'quiz').single.text, 'Q?');
    t.dispose();
  });

  test('a note that cannot be loaded says why in plain words', () async {
    final t = NoteTutor(1,
        loadNote: (id) async => throw Exception('Unlock this module first to read its notes.'),
        loadGuide: (id) async => {},
        checkQuiz: (a, b, c, d) async => {},
        askTutor: (a, b, c, d) async => '');
    await t.load();
    expect(t.problem, 'Unlock this module first to read its notes.');
    expect(tutorProblem(Exception('SocketException: Failed host lookup')), contains('internet'));
    expect(tutorProblem(const FormatException('x')), isNotEmpty);
    t.dispose();
  });

  test('the note page inside the app is closed to the network and only reports the section and links', () {
    final page = tutorPage('<!DOCTYPE html><html><head><title>t</title></head><body><h1>A</h1></body></html>');
    expect(page, contains("default-src 'none'"));
    expect(page.indexOf('Content-Security-Policy') < page.indexOf('<h1>'), isTrue);
    expect(page.indexOf('chrome.webview.postMessage') < page.toLowerCase().lastIndexOf('</body>'), isTrue);
    expect(noteBridgeScript, isNot(contains('fetch(')));
    expect(noteBridgeScript, isNot(contains('XMLHttpRequest')));
    expect(noteBridgeScript, isNot(contains('innerHTML')));
    expect(tutorPage('<p>bare</p>'), contains('postMessage'));
  });
}
