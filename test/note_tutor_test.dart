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

  final List<String> spoken = [];
  final List<List<String>> prepared = [];
  final List<String> remembered = [];
  int hushed = 0;

  NoteTutor tutor({Duration retry = const Duration(milliseconds: 10), int retries = 3, String lang = 'en'}) => NoteTutor(41,
      loadNote: (id, lang) async {
        calls.add('note $id $lang');
        return note;
      },
      loadGuide: (id, lang) async {
        calls.add('guide $id $lang');
        return guideLater;
      },
      checkQuiz: (id, section, choice, tries, lang) async {
        calls.add('quiz $section $choice $tries');
        return quizReply;
      },
      askTutor: (id, section, question, history, lang) async {
        calls.add('ask $section $question ${history.length} $lang');
        if (askError != null) throw askError!;
        return lang == 'hi' ? 'क्योंकि वह पास में है।' : 'Because it is nearby.';
      },
      speak: spoken.add,
      hush: () => hushed++,
      prepare: prepared.add,
      onLanguage: remembered.add,
      lang: lang,
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
    expect(s.calls.last, endsWith(' en'));
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
    expect(t.items.where((i) => i.text == 'Better words.'), isEmpty); // English: the note's own words were already said
    t.dispose();
  });

  test('in Hindi the plain line only names the section, so the real explanation is said when the guide arrives', () async {
    final s = FakeServer();
    final t = s.tutor();
    await t.load();
    s.guideLater = {
      'guide_ready': false,
      'guide': {
        's0': {'say': 'अब हम What is IoT वाले section पर हैं।', 'quiz': null},
        's1': {'say': 'यह section Cloud vs Edge के बारे में है।', 'quiz': null},
      },
    };
    await t.setLanguage('hi');
    expect(s.spoken.last, 'अब हम What is IoT वाले section पर हैं।'); // Hindi at once, never the note's English
    s.guideLater = {
      'guide_ready': true,
      'guide': {
        's0': {'say': 'सोचिए कि चीज़ें आपस में बात करना सीख गईं।', 'quiz': {'question': 'Bulb को IoT क्या बनाता है?', 'options': ['connected', 'bright']}},
        's1': {'say': 'Toggle बदलकर देखिए।', 'quiz': null},
      },
    };
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(t.guideReady, isTrue);
    expect(s.spoken.last, 'सोचिए कि चीज़ें आपस में बात करना सीख गईं।');
    expect(t.items.last.kind, 'quiz');
    expect(t.items.where((i) => i.text.startsWith('सोचिए')).length, 1);
    t.dispose();
  });

  test('the tutor says each new thing out loud, and muting silences it at once', () async {
    final s = FakeServer();
    final t = s.tutor();
    await t.load();
    expect(s.spoken, ['Think of things that learned to talk.']); // the section it opened on, not the written note
    t.readingIndex(1);
    expect(s.spoken.last, 'Flip the toggle and watch the time.');
    t.setVoice(false);
    expect(s.hushed, 1);
    final n = s.spoken.length;
    await t.answer(t.items.firstWhere((i) => i.kind == 'quiz'), 0);
    await t.ask('why?');
    expect(s.spoken.length, n); // muted: shown, not spoken (not even the "let me think")
    t.dispose();
    expect(s.hushed, 2); // leaving the note stops the voice
  });

  test('the note is told which section the tutor is on, and to go there when it was picked from the list', () async {
    final s = FakeServer();
    final t = s.tutor();
    final shown = <String>[];
    t.onFocus = (id, bring) => shown.add('$id $bring');
    await t.load();
    expect(shown, ['s0 false']); // where it opened
    t.readingIndex(1); // the learner scrolled
    t.reading('s0', bring: true); // the learner chose it in the list
    t.reading('s0', bring: true); // already there: nothing more
    expect(shown, ['s0 false', 's1 false', 's0 true']);
    expect(showSectionScript(3), 'window.__altroShow && window.__altroShow(3, false)');
    expect(showSectionScript(0, bring: true), contains('(0, true)'));
    expect(tutorPage('<p>x</p>'), contains('__altroShow'));
    t.dispose();
  });

  test('a question is met at once with a short spoken "let me think", different each time, and never written down', () async {
    final s = FakeServer();
    final t = s.tutor();
    await t.load();
    final before = t.items.length;
    final asked = t.ask('why is edge faster?');
    expect(t.asking, isTrue); // the screen shows the tutor typing
    expect(thinkingLines['en'], contains(s.spoken.last)); // said immediately, before the answer exists
    final first = s.spoken.last;
    await asked;
    expect(s.spoken.last, 'Because it is nearby.');
    expect(t.items.length, before + 2); // the question and the answer: the filler is not part of the conversation
    await t.ask('and cloud?');
    final second = s.spoken[s.spoken.length - 2];
    expect(second, isNot(first));
    t.dispose();
  });

  test('what will be said next is made ready before the learner gets there', () async {
    final s = FakeServer();
    final t = s.tutor();
    await t.load();
    expect(s.prepared.last, contains('Flip the toggle and watch the time.')); // the next section's words
    expect(s.prepared.last, containsAll(thinkingLines['en']!)); // and the short acknowledgements
    t.readingIndex(1);
    expect(s.prepared.last.where((x) => x.startsWith('Flip')), isEmpty); // already said: not prepared again
    t.dispose();
  });

  test('the learner can switch to Hindi: the guide, the fixed lines, the answers and the choice are all Hindi', () async {
    final s = FakeServer();
    final t = s.tutor();
    await t.load();
    s.guideLater = {
      'guide_ready': true,
      'guide': {
        's0': {'say': 'चलिए देखते हैं: IoT यानी जुड़ी हुई चीज़ें।', 'quiz': {'question': 'Bulb को IoT क्या बनाता है?', 'options': ['वह connected है', 'वह bright है']}},
        's1': {'say': 'Toggle को बदलकर देखिए।', 'quiz': null},
      },
    };
    await t.setLanguage('hi');
    expect(t.lang, 'hi');
    expect(s.remembered, ['hi']); // kept for next time
    expect(s.calls, contains('guide 41 hi'));
    final said = t.items.where((i) => i.kind == 'tutor' && i.lang == 'hi').map((i) => i.text).toList();
    expect(said, ['ठीक है, अब Hinglish में।', 'चलिए देखते हैं: IoT यानी जुड़ी हुई चीज़ें।']); // where the learner is, again, in Hindi
    final quiz = t.items.lastWhere((i) => i.kind == 'quiz');
    expect(quiz.lang, 'hi');
    expect(quiz.text, 'Bulb को IoT क्या बनाता है?');
    await t.answer(quiz, 0);
    expect(t.items.last.text, startsWith('बिल्कुल सही!'));
    await t.ask('edge fast kyun hai?');
    expect(s.calls.last, endsWith(' hi'));
    expect(t.items.last.text, 'क्योंकि वह पास में है।');
    expect(thinkingLines['hi'], contains(s.spoken[s.spoken.length - 2]));
    await t.setLanguage('hi'); // already Hindi: nothing happens
    await t.setLanguage('fr'); // not a language we have
    expect(s.remembered, ['hi']);
    await t.setLanguage('en');
    expect(t.items.last.kind == 'quiz' || t.items.last.text.isNotEmpty, isTrue);
    expect(t.items.where((i) => i.text == 'Okay, English from here.').length, 1);
    expect(t.items.where((i) => i.text == 'Think of things that learned to talk.').length, 1); // already said in English: not repeated
    t.dispose();
  });

  test('a tutor opened in Hindi greets in Hindi', () async {
    final s = FakeServer();
    final t = s.tutor(lang: 'hi');
    await t.load();
    expect(s.calls.first, 'note 41 hi');
    expect(t.items.first.text, startsWith('चलिए, यह note साथ में पढ़ते हैं।'));
    expect(NoteTutor(1, loadNote: (a, b) async => {}, loadGuide: (a, b) async => {}, checkQuiz: (a, b, c, d, e) async => {}, askTutor: (a, b, c, d, e) async => '', lang: 'xx').lang, 'en');
    t.dispose();
  });

  test('while the camera tutor is on there is one voice: this tutor writes and hands its lines over', () async {
    final s = FakeServer();
    final t = s.tutor();
    await t.load();
    final handed = <String>[];
    t.relay = handed.add;
    final spokenBefore = s.spoken.length;
    t.readingIndex(1);
    expect(handed.single, contains('Flip the toggle and watch the time.'));
    expect(handed.single, contains('Cloud vs Edge'));                     // it knows which section the learner is on
    await t.answer(t.items.firstWhere((i) => i.kind == 'quiz'), 0);
    expect(handed.last, startsWith('Correct!'));
    expect(s.spoken.length, spokenBefore);                               // nothing spoken on top of the camera tutor
    expect(t.items.where((i) => i.text == 'Flip the toggle and watch the time.'), isNotEmpty);   // still written
    t.relay = null;
    t.readingIndex(0);
    t.dispose();
  });

  test('a note that cannot be loaded says why in plain words', () async {
    final t = NoteTutor(1,
        loadNote: (id, lang) async => throw Exception('Unlock this module first to read its notes.'),
        loadGuide: (id, lang) async => {},
        checkQuiz: (a, b, c, d, e) async => {},
        askTutor: (a, b, c, d, e) async => '');
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
