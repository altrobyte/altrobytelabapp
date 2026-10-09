// The tutor that sits beside a note: what it says as the learner moves through the sections, its quick questions, and the
// learner's own questions. No widgets here, and the server calls are passed in, so the whole conversation can be tested.
//
// The tutor's guide for a note is prepared once on the server and reused; reading costs the learner nothing. Only a question
// the learner types goes to a model.

import 'dart:async';
import 'package:flutter/foundation.dart';

typedef LoadNote = Future<Map<String, dynamic>> Function(int contentId);
typedef LoadGuide = Future<Map<String, dynamic>> Function(int contentId);
typedef CheckQuiz = Future<Map<String, dynamic>> Function(int contentId, String section, int choice, int tries);
typedef AskTutor = Future<String> Function(int contentId, String section, String question, List<Map<String, String>> history);

class TutorItem {
  final String kind; // tutor | me | quiz | system
  final String text;
  final String section; // the section this belongs to ('' when none)
  final String heading; // shown above a tutor line that introduces a section
  final List<String> options; // quiz
  int tries = 0; // quiz: wrong answers so far
  int? picked; // quiz: the last option tapped
  bool settled = false; // quiz: answered correctly, or the answer was told
  TutorItem(this.kind, this.text, {this.section = '', this.heading = '', this.options = const []});
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

  NoteTutor(this.contentId,
      {required this.loadNote,
      required this.loadGuide,
      required this.checkQuiz,
      required this.askTutor,
      this.guideRetry = const Duration(seconds: 5),
      this.guideRetries = 12});

  String title = '';
  String html = '';
  String? problem; // the note itself could not be loaded
  bool loading = true;
  bool asking = false;
  bool guideReady = false;
  List<Map<String, String>> sections = []; // [{id, title}]
  Map<String, dynamic> _guide = {};
  String current = '';
  final List<TutorItem> items = [];
  final Set<String> _introduced = {};
  Timer? _retry;
  int _retried = 0;
  bool _disposed = false;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _retry?.cancel();
    super.dispose();
  }

  String titleOf(String id) => sections.firstWhere((s) => s['id'] == id, orElse: () => const {'title': ''})['title'] ?? '';

  Future<void> load() async {
    loading = true;
    problem = null;
    _notify();
    try {
      final r = await loadNote(contentId);
      title = '${r['title'] ?? ''}';
      html = '${r['html'] ?? ''}';
      sections = [
        for (final s in (r['sections'] as List? ?? const [])) {'id': '${(s as Map)['id']}', 'title': '${s['title'] ?? ''}'}
      ];
      _guide = Map<String, dynamic>.from((r['guide'] as Map?) ?? const {});
      guideReady = r['guide_ready'] == true;
      items.add(TutorItem('tutor', sections.isEmpty
          ? 'I am here while you read. Ask me anything about this note.'
          : 'I am reading this note with you. Open or scroll to a section and I will tell you what to notice, then ask one quick question. You can ask me anything, any time.'));
      if (sections.isNotEmpty) reading(sections.first['id']!);
      if (!guideReady) _scheduleGuide();
    } catch (e) {
      problem = tutorProblem(e);
    }
    loading = false;
    _notify();
  }

  // The guide is still being prepared for the first reader: ask again a few times, then live with the plain one.
  void _scheduleGuide() {
    if (_disposed || _retried >= guideRetries) return;
    _retry = Timer(guideRetry, () async {
      _retried++;
      try {
        final r = await loadGuide(contentId);
        if (r['guide_ready'] == true) {
          _guide = Map<String, dynamic>.from((r['guide'] as Map?) ?? const {});
          guideReady = true;
          // Sections already introduced with the plain text keep it; their question, now that there is one, is offered.
          for (final id in _introduced) {
            _offerQuiz(id);
          }
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
    if (q == null || items.any((i) => i.kind == 'quiz' && i.section == id)) return;
    items.add(TutorItem('quiz', '${q['question'] ?? ''}', section: id, options: [for (final o in (q['options'] as List? ?? const [])) '$o']));
  }

  /// The learner is now on this section (they scrolled to it, opened it, or picked it).
  void reading(String id) {
    if (id.isEmpty || id == current && _introduced.contains(id) || !sections.any((s) => s['id'] == id)) return;
    current = id;
    if (_introduced.add(id)) {
      final g = _guide[id];
      final say = g is Map ? '${g['say'] ?? ''}' : '';
      if (say.isNotEmpty) items.add(TutorItem('tutor', say, section: id, heading: titleOf(id)));
      _offerQuiz(id);
    }
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
      final r = await checkQuiz(contentId, quiz.section, choice, quiz.tries + 1);
      if (r['correct'] == true) {
        quiz.settled = true;
        items.add(TutorItem('tutor', 'Correct! ${r['explain'] ?? ''}'.trim(), section: quiz.section));
      } else if (r['revealed'] == true) {
        quiz.settled = true;
        items.add(TutorItem('tutor', 'The answer is "${r['answer']}". ${r['explain'] ?? ''} No worries, that is how we learn it.'.trim(), section: quiz.section));
      } else {
        quiz.tries++;
        quiz.picked = null;
        items.add(TutorItem('tutor', 'Not quite. Read that part once more and try another option.', section: quiz.section));
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
    items.add(TutorItem('me', q, section: current));
    asking = true;
    _notify();
    try {
      items.add(TutorItem('tutor', await askTutor(contentId, current, q, history), section: current));
    } catch (e) {
      items.add(TutorItem('system', tutorProblem(e)));
    }
    asking = false;
    _notify();
  }
}
