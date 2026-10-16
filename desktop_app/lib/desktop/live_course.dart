// Altron Live for a built-in course: the voice that teaches the course on screen.
//
// One brain: the course engine (through the helper, exactly as the chat uses it) decides every step and every answer.
// Altron reads it and answers for the learner through two tools the Live page passes to this app:
//   get_current_step     what the course says now and the card on screen (never the answer)
//   answer_for_learner   the learner's spoken answer, given to the course as if they had tapped it
// When the learner taps instead, the app tells Altron ("[Screen] ...") so it never talks past the screen.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_windows/webview_windows.dart';

import 'helper_controller.dart';
import 'live_tutor_screen.dart';

/// Text as it should be said: no markdown marks.
String spoken(String s) => s.replaceAll(RegExp(r'[*`]'), '').trim();

String _cut(String s, int n) => s.length <= n ? s : '${s.substring(0, n)}…';

/// The card the learner can answer now: the last quiz or suggested replies since they last said anything.
ChatBubble? activeCard(HelperController c) {
  for (var i = c.chat.length - 1; i >= 0; i--) {
    final b = c.chat[i];
    if (b.role == 'learner') return null;
    if (b.interactive == 'quiz' || b.interactive == 'replies') return b;
  }
  return null;
}

List<String> _options(ChatBubble b) => [for (final o in (b.props?['options'] as List? ?? const [])) '$o'];

Map<String, dynamic> _cardMap(ChatBubble b) {
  final options = _options(b);
  return b.interactive == 'quiz'
      ? {'type': 'quick question', 'question': '${b.props?['question'] ?? ''}', 'options': [for (var i = 0; i < options.length; i++) '${i + 1}. ${options[i]}']}
      : {'type': 'suggested replies', 'options': options};
}

/// What the course shows now, for Altron to teach from. Never carries a quiz's answer (the card never has it).
Map<String, dynamic> courseStep(HelperController c) {
  final st = c.state;
  var i = c.chat.length - 1;
  while (i >= 0 && c.chat[i].role != 'learner') {
    i--;
  }
  final said = [for (final b in c.chat.skip(i + 1)) if (b.role == 'trainer' && b.text.trim().isNotEmpty) spoken(b.text)].join('\n\n');
  final card = activeCard(c);
  final done = st?.progress.where((m) => m.done).length ?? 0;
  final total = st?.progress.length ?? 0;
  return {
    'step': currentStepTitle(st) ?? (total > 0 && done == total ? 'All steps are done: the course is complete.' : ''),
    'steps_done': '$done of $total',
    'course_says': _cut(said, 1800),
    if (card != null) 'card_on_screen': _cardMap(card),
    if (card == null) 'card_on_screen': 'none: the learner may answer in their own words',
    'interactive_lesson': c.hasLesson ? 'the orange "Open lesson" button at the top, next to the step name; it opens the section this step is about' : 'none',
  };
}

const _numberWords = {
  'one': 1, 'first': 1, 'ek': 1, 'pehla': 1, 'pahla': 1,
  'two': 2, 'second': 2, 'do': 2, 'doosra': 2, 'dusra': 2,
  'three': 3, 'third': 3, 'teen': 3, 'tisra': 3, 'teesra': 3,
  'four': 4, 'fourth': 4, 'char': 4, 'chaar': 4, 'chautha': 4,
};
const _letters = {'a': 1, 'b': 2, 'c': 3, 'd': 4};

List<String> _words(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]'), ' ').split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

/// Which option a spoken answer means: a number ("2", "option two", "doosra", "b"), else the option whose words it shares
/// most. Null when it is not clear, so the learner is asked again rather than marked on a guess.
int? matchOption(String said, List<String> options) {
  final words = _words(said);
  if (words.isEmpty || options.isEmpty) return null;
  int? inRange(int? n) => n != null && n >= 1 && n <= options.length ? n - 1 : null;
  // A digit anywhere, a number word in a short answer or after "option"/"number", a lone letter ("b", "option b").
  final pointed = words.length <= 4 || words.contains('option') || words.contains('number');
  for (final w in words) {
    final n = inRange(int.tryParse(w)) ?? (pointed ? inRange(_numberWords[w]) : null);
    if (n != null) return n;
  }
  final letter = words.length == 1 ? words.first : (words.length == 2 && words.first == 'option' ? words.last : '');
  if (inRange(_letters[letter]) != null) return inRange(_letters[letter]);
  final heard = words.where((w) => w.length > 2).toSet();
  var best = -1, bestScore = 0.0, second = 0.0;
  for (var i = 0; i < options.length; i++) {
    final ow = _words(options[i]).where((w) => w.length > 2).toSet();
    if (ow.isEmpty) continue;
    final score = ow.intersection(heard).length / ow.length;
    if (score > bestScore) {
      second = bestScore;
      bestScore = score;
      best = i;
    } else if (score > second) {
      second = score;
    }
  }
  return best >= 0 && bestScore >= 0.34 && bestScore - second >= 0.15 ? best : null;
}

/// Runs Altron's course tools against the course the learner has open.
class CourseLiveBridge {
  CourseLiveBridge(this.c);
  final HelperController c;

  /// The turn now running was started by Altron (an answer it gave for the learner), so it is not told back to it.
  bool toolTurn = false;

  Future<void> _idle([Duration max = const Duration(seconds: 30)]) async {
    final end = DateTime.now().add(max);
    while (c.busy && DateTime.now().isBefore(end)) {
      await Future.delayed(const Duration(milliseconds: 120));
    }
  }

  /// [heard] is what the learner really said since their last answer (from the page's transcript). Altron may answer for
  /// them only with that: never on its own, never a guess.
  Future<Map<String, dynamic>> run(String name, Map args, {String heard = ''}) async {
    if (!c.started) return {'error': 'No course is open.'};
    await _idle();
    switch (name) {
      case 'get_current_step':
        return courseStep(c);
      case 'answer_for_learner':
        if (heard.trim().isEmpty) {
          return {'ok': false, 'note': 'The learner has not said an answer yet. Ask the question and wait for them to answer.', 'now': courseStep(c)};
        }
        return answer('${args['answer'] ?? ''}', heard: heard);
    }
    return {'error': 'Unknown tool $name.'};
  }

  /// [heard] is the learner's own words; on a quiz they decide the option, never the model's [said] alone.
  Future<Map<String, dynamic>> answer(String said, {String heard = ''}) async {
    said = said.trim();
    if (said.isEmpty) return {'ok': false, 'note': 'Nothing was said. Ask again.'};
    final card = activeCard(c);
    final before = c.chat.length;
    String sent = said;
    if (card?.interactive == 'quiz') {
      final options = _options(card!);
      var i = heard.isEmpty ? matchOption(said, options) : matchOption(heard, options);
      if (i == null && heard.isNotEmpty && heard.toLowerCase().contains(said.toLowerCase())) i = matchOption(said, options);
      if (i == null) {
        return {'ok': false, 'note': 'It is not clear which option they meant. Ask them to say the option number.', 'card_on_screen': _cardMap(card)};
      }
      sent = options[i];
      toolTurn = true;
      await c.answerQuiz('${card.props?['milestone']}', i, options[i]);
    } else {
      // A step with suggested replies waits for one of them: "it's already open" is sent as the "It's open" it means.
      final options = card == null ? const <String>[] : _options(card);
      final i = options.isEmpty ? null : matchOption(heard.isEmpty ? said : heard, options);
      if (i != null) sent = options[i];
      toolTurn = true;
      await c.send(sent);
    }
    await Future.delayed(const Duration(milliseconds: 150));
    await _idle();
    final replied = [for (final b in c.chat.skip(before)) if (b.role == 'trainer' && b.text.trim().isNotEmpty) spoken(b.text)].join('\n\n');
    return {'given_to_the_course': sent, 'course_replied': _cut(replied, 1500), 'now': courseStep(c)};
  }
}

/// The Altron card above the course's progress: it starts talking when the course opens (camera off).
class LiveCoursePanel extends StatefulWidget {
  const LiveCoursePanel({super.key, required this.controller, required this.course});
  final HelperController controller;
  final String course;

  @override
  State<LiveCoursePanel> createState() => _LiveCoursePanelState();
}

class _LiveCoursePanelState extends State<LiveCoursePanel> {
  HelperController get c => widget.controller;
  late final CourseLiveBridge _bridge = CourseLiveBridge(c);
  WebviewController? _web;
  StreamSubscription? _messages;
  String? _problem;
  String _lang = 'en';
  bool _wasBusy = false;
  int _toldUpTo = -1; // the last learner line Altron already knows about

  @override
  void initState() {
    super.initState();
    _toldUpTo = c.chat.lastIndexWhere((b) => b.role == 'learner');
    c.addListener(_onCourse);
    _open();
  }

  Future<void> _open() async {
    try {
      _lang = (await SharedPreferences.getInstance()).getString('tutor_lang') ?? 'en';
      if (_lang != 'hi') _lang = 'en';
      if (await WebviewController.getWebViewVersion() == null) {
        setState(() => _problem = 'Altron needs Microsoft Edge WebView2 on this computer.');
        return;
      }
      final web = WebviewController();
      await web.initialize();
      await web.setBackgroundColor(const Color(0xFF1E3A5F));
      await web.setPopupWindowPolicy(WebviewPopupWindowPolicy.deny);
      _messages = web.webMessage.listen(_onPage);
      await loadLive(web, course: widget.course, lang: _lang);
      if (!mounted) {
        web.dispose();
        return;
      }
      setState(() => _web = web);
    } catch (_) {
      if (mounted) setState(() => _problem = 'Altron could not open here. The course works as usual below.');
    }
  }

  Future<void> _onPage(dynamic raw) async {
    final m = liveMessage(raw);
    if (m == null || m['type'] != 'tool') return;
    final id = '${m['id']}';
    Map<String, dynamic> result;
    try {
      result = await _bridge.run('${m['name']}', Map<String, dynamic>.from((m['args'] as Map?) ?? const {}), heard: '${m['heard'] ?? ''}');
    } catch (_) {
      result = {'error': 'The course could not be read just now. Ask the learner to tap on the screen.'};
    }
    await _web?.executeScript('window.altronToolResult && window.altronToolResult(${jsonEncode(id)}, ${jsonEncode(jsonEncode(result))})');
  }

  // A turn just ended. If the learner tapped or typed it (not Altron answering for them), Altron hears what happened.
  void _onCourse() {
    final busy = c.busy;
    if (_wasBusy && !busy) {
      final i = c.chat.lastIndexWhere((b) => b.role == 'learner');
      if (_bridge.toolTurn) {
        _bridge.toolTurn = false;
        _toldUpTo = i;
      } else if (i > _toldUpTo) {
        _toldUpTo = i;
        final text = 'The learner tapped or typed "${c.chat[i].text}" on the screen. The course now: ${jsonEncode(courseStep(c))}';
        _web?.executeScript('window.altronTell && window.altronTell(${jsonEncode(text)})');
      }
    }
    _wasBusy = busy;
  }

  Future<void> _setLang(String l) async {
    if (l == _lang) return;
    setState(() => _lang = l);
    unawaited(SharedPreferences.getInstance().then((p) => p.setString('tutor_lang', l)));
    final web = _web;
    if (web != null) await loadLive(web, course: widget.course, lang: l);
  }

  @override
  void dispose() {
    c.removeListener(_onCourse);
    _messages?.cancel();
    final web = _web;
    // Pause first, so the page reports what the talk used; then let go of the microphone and the camera.
    if (web != null) {
      web.executeScript('window.altronPause && window.altronPause()').catchError((_) => null).whenComplete(
          () => Future.delayed(const Duration(milliseconds: 400), web.dispose));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: const Color(0xFF1E3A5F), borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 0),
          child: Row(children: [
            const Icon(Icons.graphic_eq_rounded, color: Color(0xFFFF9A5A), size: 18),
            const SizedBox(width: 6),
            Expanded(child: Text('Altron Live · talk, interrupt, ask anything', style: GoogleFonts.inter(color: Colors.white70, fontSize: 12))),
            for (final (code, label) in const [('en', 'English'), ('hi', 'Hinglish')])
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: InkWell(
                  onTap: () => _setLang(code),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: _lang == code ? Colors.white : Colors.white12, borderRadius: BorderRadius.circular(14)),
                    child: Text(label,
                        style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: _lang == code ? const Color(0xFF1E3A5F) : Colors.white)),
                  ),
                ),
              ),
          ]),
        ),
        Expanded(
          child: _problem != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(_problem!, textAlign: TextAlign.center, style: GoogleFonts.inter(color: Colors.white, fontSize: 13)),
                  ),
                )
              : _web == null
                  ? const Center(child: CircularProgressIndicator(color: Colors.white54))
                  : Webview(_web!, permissionRequested: (url, kind, userInitiated) => livePermission(url, kind)),
        ),
      ]),
    );
  }
}
