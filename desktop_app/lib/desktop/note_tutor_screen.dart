// A note open inside the app, with the tutor beside it.
//
// Left: the note exactly as its author wrote it (interactive parts included), shown by the Windows web view with the network
// switched off. Right: the tutor, which follows the section the learner is on. If the web view is not available on this
// computer the note opens in the browser instead and the tutor still works: the learner picks the section they are reading.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_windows/webview_windows.dart';
import '../constants/app_colors.dart';
import '../services/api_service.dart';
import 'chat_text.dart';
import 'note_tutor.dart';
import 'tutor_feel.dart';
import 'visual_page.dart';
import 'web_scroll.dart';

class NoteTutorScreen extends StatefulWidget {
  final int contentId;
  final String title;

  /// Speaks through the computer (the helper), and stops speaking. Null when no helper is connected.
  final void Function(String text)? speak;
  final void Function()? hush;

  /// Makes sentences ready ahead of time on this computer, so saying them starts at once.
  final void Function(List<String> texts)? prepare;
  const NoteTutorScreen({super.key, required this.contentId, required this.title, this.speak, this.hush, this.prepare});

  @override
  State<NoteTutorScreen> createState() => _NoteTutorScreenState();
}

class _NoteTutorScreenState extends State<NoteTutorScreen> {
  late NoteTutor t = _tutorIn('en');

  NoteTutor _tutorIn(String lang) => NoteTutor(widget.contentId,
      loadNote: ApiService.noteTutor,
      loadGuide: ApiService.noteGuide,
      checkQuiz: ApiService.noteQuiz,
      askTutor: ApiService.noteAsk,
      speak: widget.speak,
      hush: widget.hush,
      prepare: widget.prepare,
      lang: lang,
      onLanguage: (l) => SharedPreferences.getInstance().then((p) => p.setString('tutor_lang', l)));
  final _web = WebviewController();
  late final _pan = PanScroller((script) => _web.executeScript(script));
  final _input = TextEditingController();
  final _scroll = ScrollController();
  StreamSubscription? _messages;
  bool _webReady = false;
  String? _webProblem; // why the note cannot be shown inside the app
  int _shown = 0;

  @override
  void initState() {
    super.initState();
    t.addListener(_onTutor);
    t.onFocus = _show;
    _start();
  }

  Future<void> _start() async {
    if (t.items.isEmpty && t.problem == null) {
      // The language the learner chose last time, before anything is said.
      final saved = (await SharedPreferences.getInstance()).getString('tutor_lang');
      if (saved != null && saved != t.lang && tutorLanguages.containsKey(saved)) {
        t.removeListener(_onTutor);
        t = _tutorIn(saved)
          ..addListener(_onTutor)
          ..onFocus = _show;
      }
    }
    await t.load();
    if (!mounted || t.problem != null) return;
    try {
      if (await WebviewController.getWebViewVersion() == null) {
        throw Exception('missing');
      }
      await _web.initialize();
      await _web.setBackgroundColor(Colors.white);
      await _web.setPopupWindowPolicy(WebviewPopupWindowPolicy.deny);
      _messages = _web.webMessage.listen(_onPageMessage);
      await _web.loadStringContent(tutorPage(t.html));
      if (mounted) setState(() => _webReady = true);
      // The first section was introduced while the page was still loading: point at it now.
      Future<void>.delayed(const Duration(milliseconds: 700), () {
        if (mounted && t.current.isNotEmpty) _show(t.current, false);
      });
    } catch (_) {
      if (mounted) {
        setState(() => _webProblem = 'This computer cannot show the note inside the app (the Windows web view is missing). '
            'Open it in your browser and keep the tutor here.');
      }
    }
  }

  // The tutor moved to a section: make it glow in the note.
  void _show(String sectionId, bool bring) {
    final index = int.tryParse(sectionId.replaceFirst('s', ''));
    if (index != null && _webReady) _web.executeScript(showSectionScript(index, bring: bring));
  }

  // What the note reports: which section is in view, or a link the learner clicked.
  void _onPageMessage(dynamic m) {
    if (m is! Map) return;
    final s = m['section'];
    if (s is num) t.readingIndex(s.toInt());
    final link = m['open'];
    if (link is String) openExternal(link);
  }

  // Keep the newest words in view while they are being written out.
  void _follow() {
    if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
  }

  void _onTutor() {
    if (t.items.length != _shown) {
      _shown = t.items.length;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent + 200, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      });
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    t.removeListener(_onTutor);
    _messages?.cancel();
    t.dispose();
    _pan.dispose();
    _web.dispose();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _ask() {
    final q = _input.text.trim();
    if (q.isEmpty) return;
    _input.clear();
    t.ask(q);
  }

  Widget _bubble(TutorItem i) {
    if (i.kind == 'quiz') {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.primary.withValues(alpha: 0.35), width: 1.5)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.quiz_rounded, size: 16, color: AppColors.primary),
            const SizedBox(width: 6),
            Text('Quick question', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary)),
          ]),
          const SizedBox(height: 6),
          Text(i.text, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, height: 1.4)),
          const SizedBox(height: 8),
          for (var n = 0; n < i.options.length; n++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    backgroundColor: i.picked == n ? AppColors.primary.withValues(alpha: 0.1) : null,
                  ),
                  onPressed: i.settled || t.asking ? null : () => t.answer(i, n),
                  child: Text(i.options[n], style: GoogleFonts.inter(fontSize: 12.5)),
                ),
              ),
            ),
        ]),
      );
    }
    final me = i.kind == 'me', system = i.kind == 'system';
    return Align(
      alignment: me ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        constraints: const BoxConstraints(maxWidth: 330),
        decoration: BoxDecoration(
          color: system ? Colors.grey.shade200 : (me ? AppColors.primary : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: me || system ? null : Border.all(color: Colors.black.withValues(alpha: 0.08)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (i.heading.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(i.heading, style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.accent)),
            ),
          system
              ? Text(i.text, style: GoogleFonts.inter(fontSize: 12.5, fontStyle: FontStyle.italic, color: AppColors.textSecondary, height: 1.4))
              : (i.kind == 'tutor' && !i.shown)
                  // A new line from the tutor is written out, at about the pace the voice says it.
                  ? RevealText(i.text, key: ObjectKey(i), color: AppColors.textPrimary, onDone: () => i.shown = true, onGrow: _follow)
                  : ChatText(i.text, color: me ? Colors.white : AppColors.textPrimary),
        ]),
      ),
    );
  }

  Widget _tutorPanel() {
    return Container(
      width: 390,
      decoration: BoxDecoration(color: const Color(0xFFF1F3F7), border: Border(left: BorderSide(color: Colors.black.withValues(alpha: 0.08)))),
      child: Column(children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          color: Colors.white,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.smart_toy_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text('Altron', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
              const Spacer(),
              // English or Hindi: the tutor's words, questions, answers and voice all follow.
              SegmentedButton<String>(
                showSelectedIcon: false,
                style: const ButtonStyle(visualDensity: VisualDensity.compact, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                segments: [for (final e in tutorLanguages.entries) ButtonSegment(value: e.key, label: Text(e.value, style: GoogleFonts.inter(fontSize: 12)))],
                selected: {t.lang},
                onSelectionChanged: t.asking ? null : (v) => t.setLanguage(v.first),
              ),
              const SizedBox(width: 4),
              // The same topic with the camera: Altron looks at the bench (best from a phone; the page shows a QR).
              IconButton(
                tooltip: 'Show your bench to Altron (camera)',
                visualDensity: VisualDensity.compact,
                onPressed: () => openExternal('https://altrobytelab.com/live/?note=${widget.contentId}'),
                icon: const Icon(Icons.videocam_rounded, size: 20, color: AppColors.primary),
              ),
              if (widget.speak != null)
                IconButton(
                  tooltip: t.voice ? 'The tutor is speaking. Tap to mute.' : 'The tutor is muted. Tap to hear it.',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => t.setVoice(!t.voice),
                  icon: Icon(t.voice ? Icons.volume_up_rounded : Icons.volume_off_rounded, size: 20, color: t.voice ? AppColors.primary : Colors.grey),
                ),
              if (!t.guideReady && t.sections.isNotEmpty)
                Tooltip(
                  message: 'Preparing questions for this note. It takes a moment the first time anyone opens it.',
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
                    const SizedBox(width: 6),
                    Text('preparing', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
                  ]),
                ),
            ]),
            if (t.sections.isNotEmpty) ...[
              const SizedBox(height: 6),
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  isDense: true,
                  value: t.current.isEmpty ? null : t.current,
                  hint: const Text('Which part are you reading?'),
                  style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textPrimary),
                  items: [
                    for (final s in t.sections)
                      DropdownMenuItem(value: s['id'], child: Text('Reading: ${s['title']}', overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (v) {
                    if (v != null) t.reading(v, bring: true); // picked from the list: take the note there too
                  },
                ),
              ),
            ],
          ]),
        ),
        Expanded(
          child: ListView(controller: _scroll, padding: const EdgeInsets.all(12), children: [
            for (final i in t.items) _bubble(i),
            if (t.asking) const TypingDots(),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(10),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _input,
                minLines: 1,
                maxLines: 3,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _ask(),
                decoration: InputDecoration(hintText: 'Ask about what you are reading…', isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              ),
            ),
            const SizedBox(width: 6),
            IconButton.filled(onPressed: t.asking ? null : _ask, icon: const Icon(Icons.send_rounded, size: 18)),
          ]),
        ),
      ]),
    );
  }

  Widget _notePane() {
    if (_webProblem != null) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.open_in_browser_rounded, size: 40, color: AppColors.primary),
            const SizedBox(height: 10),
            Text(_webProblem!, textAlign: TextAlign.center, style: GoogleFonts.inter(height: 1.5)),
            const SizedBox(height: 14),
            ElevatedButton(onPressed: () => openLessonHtml(t.html), child: const Text('Open the note in my browser')),
            const SizedBox(height: 8),
            Text('Then choose the part you are reading in the tutor panel.', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
          ]),
        ),
      );
    }
    if (!_webReady) return const Center(child: CircularProgressIndicator());
    // A two-finger swipe on a touchpad reaches Flutter, not the web view, so it is handed on as a scroll of the page.
    return Listener(
      onPointerPanZoomUpdate: (e) => _pan.add(e.panDelta),
      onPointerPanZoomEnd: (_) => _pan.end(),
      child: Webview(_web),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Text(t.title.isEmpty ? widget.title : t.title, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16)),
      ),
      body: t.loading
          ? const Center(child: CircularProgressIndicator())
          : t.problem != null
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.error_outline_rounded, size: 40, color: Colors.black38),
                    const SizedBox(height: 10),
                    Text(t.problem!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    ElevatedButton(onPressed: _start, child: const Text('Try again')),
                  ]),
                )
              : Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Expanded(child: _notePane()), _tutorPanel()]),
    );
  }
}
