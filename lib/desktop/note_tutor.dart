// The tutor that sits beside a note: what it says as the learner moves through the sections, its quick questions, and the
// learner's own questions, in English or in Hindi as the learner chooses. No widgets here, and the server calls are passed
// in, so the whole conversation can be tested.
//
// The tutor's guide for a note is prepared once on the server (per language) and reused; reading costs the learner nothing.
// Only a question the learner types goes to a model.
//
// Waiting is kept out of sight where it honestly can be: the words of the next section are made ready before the learner
// gets there, and when a question is asked the tutor says a short "let me think" at once, the way a person would, while the
// real answer is on its way.

import 'dart:async';
import 'package:flutter/foundation.dart';

typedef LoadNote = Future<Map<String, dynamic>> Function(int contentId, String lang);
typedef LoadGuide = Future<Map<String, dynamic>> Function(int contentId, String lang);
typedef CheckQuiz = Future<Map<String, dynamic>> Function(int contentId, String section, int choice, int tries, String lang);
typedef AskTutor = Future<String> Function(int contentId, String section, String question, List<Map<String, String>> history, String lang);

const tutorLanguages = {'en': 'English', 'hi': 'Hinglish'};

/// The tutor's own fixed lines, in each language. "hi" is Hinglish, the way people really talk: Hindi grammar, everyday and
/// technical words left in English, and no verb that assumes the tutor is a man or a woman.
const _lines = <String, Map<String, String>>{
  'en': {
    'hello': 'I am reading this note with you. Open or scroll to a section and I will tell you what to notice, then ask one quick question. You can ask me anything, any time.',
    'hello_plain': 'I am here while you read. Ask me anything about this note.',
    'correct': 'Correct!',
    'answer_is': 'The answer is',
    'no_worries': 'No worries, that is how we learn it.',
    'try_again': 'Not quite. Read that part once more and try another option.',
    'switched': 'Okay, English from here.',
  },
  'hi': {
    'hello': 'चलिए, यह note साथ में पढ़ते हैं। किसी भी section पर जाइए, हम देखेंगे कि वहाँ important क्या है, और फिर एक quick question। कोई भी doubt हो तो कभी भी पूछिए।',
    'hello_plain': 'आप पढ़िए, इस note के बारे में कोई भी doubt हो तो कभी भी पूछिए।',
    'correct': 'बिल्कुल सही!',
    'answer_is': 'Correct answer है',
    'no_worries': 'कोई बात नहीं, ऐसे ही तो सीखते हैं।',
    'try_again': 'Not quite। वह part एक बार फिर पढ़िए और दूसरा option try कीजिए।',
    'switched': 'ठीक है, अब Hinglish में।',
  },
};

/// What a person says the moment they are asked something, before the answer: short, and different each time.
const thinkingLines = <String, List<String>>{
  'en': ['Good question. Give me a second.', 'Hmm, let me think about that.', 'Okay, one moment.', 'Let me look at that with you.'],
  'hi': ['अच्छा question है। एक second।', 'हम्म, एक minute सोचने दीजिए।', 'ठीक है, one moment।', 'चलिए, इसे साथ में देखते हैं।'],
};

String tutorLine(String lang, String key) => (_lines[lang] ?? _lines['en']!)[key] ?? _lines['en']![key] ?? '';

class TutorItem {
  final String kind; // tutor | me | quiz | system
  final String text;
  final String section; // the section this belongs to ('' when none)
  final String heading; // shown above a tutor line that introduces a section
  final List<String> options; // quiz
  final String lang; // the language it was said in
  int tries = 0; // quiz: wrong answers so far
  int? picked; // quiz: the last option tapped
  bool settled = false; // quiz: answered correctly, or the answer was told
  bool shown = false; // the screen has finished writing it out (so it is not written out again)
  TutorItem(this.kind, this.text, {this.section = '', this.heading = '', this.options = const [], this.lang = 'en'});
}

/// What an error from the server should read like next to a note.
String tutorProblem(Object e) {
  final t = '$e'.replaceFirst('Exception: ', '').trim();
  final low = t.toLowerCase();
  if (low.contains('socket') || low.contains('failed host') || low.contains('connection') || low.contains('timeout')) {
    return 'I cannot reach Altrobyte right now. Check your internet; you can keep reading meanwhile.';
  }
  if (t.isEmpty || low.contains('formatexception') || low.contains('type \'')) return 'Something went wrong. Please try again.';
  return t.length > 220 ? '${t.substring(0, 220)}…' : t;
}

class NoteTutor extends ChangeNotifier {
  final int contentId;
  final LoadNote loadNote;
  final LoadGuide loadGuide;
  final CheckQuiz checkQuiz;
  final AskTutor askTutor;
  final Duration guideRetry;
  final int guideRetries;

  /// Says a sentence out loud on this computer (the helper does it). Null when there is no voice here.
  final void Function(String text)? speak;
  final void Function()? hush;

  /// Makes these sentences ready ahead of time, so that saying them later starts at once.
  final void Function(List<String> texts)? prepare;

  /// While the camera tutor is open there is one voice, not two: what this tutor would say is handed to the camera tutor,
  /// which says it in its own words, and this tutor only writes. Set by the screen while the camera is on.
  void Function(String text)? relay;

  /// Remembers the learner's language for next time.
  final void Function(String lang)? onLanguage;
  bool voice = true; // the learner can switch the tutor's voice off
  String lang; // en | hi

  /// The tutor is now on this section: the note shows it (glows; and scrolls to it when the learner picked it from the list).
  void Function(String sectionId, bool bring)? onFocus;

  NoteTutor(this.contentId,
      {required this.loadNote,
      required this.loadGuide,
      required this.checkQuiz,
      required this.askTutor,
      this.speak,
      this.hush,
      this.prepare,
      this.onLanguage,
      String lang = 'en',
      this.guideRetry = const Duration(seconds: 5),
      this.guideRetries = 12})
      : lang = tutorLanguages.containsKey(lang) ? lang : 'en';

  String title = '';
  String html = '';
  bool hasClass = false; // the note has a class version, taught live on the board
  String? problem; // the note itself could not be loaded
  bool loading = true;
  bool asking = false; // waiting for an answer: the screen shows the tutor "typing"
  bool guideReady = false;
  List<Map<String, String>> sections = []; // [{id, title}]
  Map<String, dynamic> _guide = {};
  String current = '';
  final List<TutorItem> items = [];
  final Set<String> _introduced = {}; // "lang:section" the tutor has spoken about
  Timer? _retry;
  int _retried = 0;
  int _thinking = 0;
  bool _disposed = false;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  // The tutor talks: its line goes on the screen and, when the voice is on, out of the speakers. A newer line interrupts an
  // older one, so scrolling on makes it talk about the new section instead of finishing the old one.
  void _tutor(String text, {String section = '', String heading = ''}) {
    items.add(TutorItem('tutor', text, section: section, heading: heading, lang: lang));
    if (text.isEmpty) return;
    if (relay != null) {
      relay!(heading.isNotEmpty ? 'The learner is now reading the section "$heading". $text' : text);
    } else if (voice) {
      speak?.call(text);
    }
  }

  void setVoice(bool on) {
    voice = on;
    if (!on) hush?.call();
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    hush?.call();
    _retry?.cancel();
    super.dispose();
  }

  String titleOf(String id) => sections.firstWhere((s) => s['id'] == id, orElse: () => const {'title': ''})['title'] ?? '';

  String _sayOf(String id) {
    final g = _guide[id];
    return g is Map ? '${g['say'] ?? ''}' : '';
  }

  Future<void> load() async {
    loading = true;
    problem = null;
    _notify();
    try {
      final r = await loadNote(contentId, lang);
      title = '${r['title'] ?? ''}';
      html = '${r['html'] ?? ''}';
      hasClass = r['has_class'] == true;
      sections = [
        for (final s in (r['sections'] as List? ?? const [])) {'id': '${(s as Map)['id']}', 'title': '${s['title'] ?? ''}'}
      ];
      _guide = Map<String, dynamic>.from((r['guide'] as Map?) ?? const {});
      guideReady = r['guide_ready'] == true;
      items.add(TutorItem('tutor', tutorLine(lang, sections.isEmpty ? 'hello_plain' : 'hello'), lang: lang));
      if (sections.isNotEmpty) reading(sections.first['id']!);
      _prepareAhead();
      if (!guideReady) _scheduleGuide();
    } catch (e) {
      problem = tutorProblem(e);
    }
    loading = false;
    _notify();
  }

  /// English or Hindi. The guide for that language is fetched (and drafted, the first time anyone asks for it), and the
  /// tutor says where the learner is again, in the new language.
  Future<void> setLanguage(String next) async {
    if (!tutorLanguages.containsKey(next) || next == lang) return;
    lang = next;
    onLanguage?.call(next);
    _retry?.cancel();
    _retried = 0;
    asking = true;
    _notify();
    try {
      final r = await loadGuide(contentId, lang);
      _guide = Map<String, dynamic>.from((r['guide'] as Map?) ?? const {});
      guideReady = r['guide_ready'] == true;
    } catch (e) {
      items.add(TutorItem('system', tutorProblem(e)));
    }
    asking = false;
    items.add(TutorItem('tutor', tutorLine(lang, 'switched'), lang: lang));
    if (current.isNotEmpty) _introduce(current);
    _prepareAhead();
    if (!guideReady) _scheduleGuide();
    _notify();
  }

  // The guide is still being prepared for the first reader: ask again a few times, then live with the plain one.
  void _scheduleGuide() {
    if (_disposed || _retried >= guideRetries) return;
    final asked = lang;
    _retry = Timer(guideRetry, () async {
      _retried++;
      try {
        final r = await loadGuide(contentId, asked);
        if (asked != lang) return; // the learner changed language meanwhile
        if (r['guide_ready'] == true) {
          _guide = Map<String, dynamic>.from((r['guide'] as Map?) ?? const {});
          guideReady = true;
          // Sections already introduced with the plain text keep it; their question, now that there is one, is offered.
          // In Hindi the plain line only named the section, so where the learner is now gets its real explanation.
          final real = _sayOf(current);
          if (lang != 'en' && _introduced.contains('$lang:$current') && real.isNotEmpty && !items.any((i) => i.text == real)) {
            _tutor(real, section: current, heading: titleOf(current));
          }
          for (final key in _introduced.where((k) => k.startsWith('$lang:')).toList()) {
            _offerQuiz(key.substring(lang.length + 1));
          }
          _prepareAhead();
          _notify();
          return;
        }
      } catch (_) {}
      _scheduleGuide();
    });
  }

  Map<String, dynamic>? _quizOf(String id) {
    final g = _guide[id];
    final q = g is Map ? g['quiz'] : null;
    return q is Map ? Map<String, dynamic>.from(q) : null;
  }

  void _offerQuiz(String id) {
    final q = _quizOf(id);
    if (q == null || items.any((i) => i.kind == 'quiz' && i.section == id && i.lang == lang)) return;
    final options = [for (final o in (q['options'] as List? ?? const [])) '$o'];
    items.add(TutorItem('quiz', '${q['question'] ?? ''}', section: id, options: options, lang: lang));
    relay?.call('Ask them this quick question from the note (they answer by tapping an option in the note panel, '
        'do not give the answer): ${q['question'] ?? ''} Options: ${options.join(' / ')}');
  }

  // Say what this section is about (once per language) and offer its question.
  void _introduce(String id) {
    if (!_introduced.add('$lang:$id')) return;
    final say = _sayOf(id);
    if (say.isNotEmpty) _tutor(say, section: id, heading: titleOf(id));
    _offerQuiz(id);
  }

  // What will probably be said next is made ready now: the next two sections, and the short "let me think" lines.
  void _prepareAhead() {
    if (prepare == null || !voice) return;
    final at = sections.indexWhere((s) => s['id'] == current);
    final next = [
      for (var i = at + 1; i <= at + 2 && i < sections.length; i++)
        if (!_introduced.contains('$lang:${sections[i]['id']}') && _sayOf(sections[i]['id']!).isNotEmpty) _sayOf(sections[i]['id']!)
    ];
    prepare!([...next, ...(thinkingLines[lang] ?? const [])]);
  }

  /// The learner is now on this section (they scrolled to it, opened it, or picked it).
  void reading(String id, {bool bring = false}) {
    if (id.isEmpty || id == current && _introduced.contains('$lang:$id') || !sections.any((s) => s['id'] == id)) return;
    current = id;
    onFocus?.call(id, bring);
    _introduce(id);
    _prepareAhead();
    _notify();
  }

  /// By position on the page (what the note itself reports).
  void readingIndex(int index) => reading('s$index');

  Future<void> answer(TutorItem quiz, int choice) async {
    if (quiz.kind != 'quiz' || quiz.settled || asking) return;
    quiz.picked = choice;
    asking = true;
    _notify();
    try {
      final r = await checkQuiz(contentId, quiz.section, choice, quiz.tries + 1, quiz.lang);
      if (r['correct'] == true) {
        quiz.settled = true;
        _tutor('${tutorLine(lang, 'correct')} ${r['explain'] ?? ''}'.trim(), section: quiz.section);
      } else if (r['revealed'] == true) {
        quiz.settled = true;
        _tutor('${tutorLine(lang, 'answer_is')} "${r['answer']}". ${r['explain'] ?? ''} ${tutorLine(lang, 'no_worries')}'.trim(), section: quiz.section);
      } else {
        quiz.tries++;
        quiz.picked = null;
        _tutor(tutorLine(lang, 'try_again'), section: quiz.section);
      }
    } catch (e) {
      quiz.picked = null;
      items.add(TutorItem('system', tutorProblem(e)));
    }
    asking = false;
    _notify();
  }

  Future<void> ask(String question) async {
    final q = question.trim();
    if (q.isEmpty || asking) return;
    final history = [
      for (final i in items.where((i) => i.kind == 'me' || i.kind == 'tutor').toList().reversed.take(6).toList().reversed)
        {'role': i.kind == 'me' ? 'user' : 'assistant', 'text': i.text}
    ];
    items.add(TutorItem('me', q, section: current, lang: lang));
    asking = true;
    // Said at once, like a person would, while the answer is being worked out. It is spoken, not written: the answer
    // itself is what belongs in the conversation.
    final fillers = thinkingLines[lang] ?? const <String>[];
    if (voice && fillers.isNotEmpty) speak?.call(fillers[_thinking++ % fillers.length]);
    _notify();
    try {
      _tutor(await askTutor(contentId, current, q, history, lang), section: current);
    } catch (e) {
      items.add(TutorItem('system', tutorProblem(e)));
    }
    asking = false;
    _notify();
  }
}
