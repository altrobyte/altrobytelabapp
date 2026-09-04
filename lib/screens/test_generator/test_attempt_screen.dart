import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../widgets/auth_sheet.dart';
import '../../widgets/share_test_link.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../../constants/api_constants.dart';
import '../../constants/app_colors.dart';
import '../../models/test_model.dart';
import '../../services/api_service.dart';
import '../../widgets/upgrade_sheet.dart';

// NTA-style question states
enum QState { notVisited, visitedNotAnswered, answered, markedForReview, answeredAndMarked }

Color _qColor(QState s) {
  switch (s) {
    case QState.notVisited: return const Color(0xFF9E9E9E);
    case QState.visitedNotAnswered: return AppColors.error;
    case QState.answered: return AppColors.success;
    case QState.markedForReview: return AppColors.accent;
    case QState.answeredAndMarked: return AppColors.accent;
  }
}

class TestAttemptScreen extends StatefulWidget {
  final int testId;
  const TestAttemptScreen({super.key, required this.testId});

  @override
  State<TestAttemptScreen> createState() => _TestAttemptScreenState();
}

class _TestAttemptScreenState extends State<TestAttemptScreen> {
  AltroTest? _test;
  bool _loading = true;
  String? _error;
  bool _started = false;   // instructions shown first

  int _currentQ = 0;
  final Map<int, String> _answers = {};
  final Map<int, QState> _qStates = {};
  bool _submitted = false;
  TestAttemptResult? _result;
  Timer? _timer;
  int _secondsLeft = 0;
  int _secondsTaken = 0;
  int? _studentId;
  String _studentPhone = '';
  String _studentName = '';
  Map<String, dynamic>? _subscription;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  bool get _quizBlocked =>
      _subscription != null &&
      _subscription!['is_premium'] != true &&
      (_subscription!['remaining_today'] ?? 1) <= 0;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final prefs = await SharedPreferences.getInstance();
      _studentId = prefs.getInt('student_id');
      _studentPhone = prefs.getString('student_phone') ?? '';
      _studentName = prefs.getString('student_name') ?? '';
      final data = await ApiService.getTest(widget.testId);
      final test = AltroTest.fromJson(Map<String, dynamic>.from(data));
      Map<String, dynamic>? sub;
      try {
        sub = await ApiService.getStudentSubscription();
      } catch (_) {
        // Subscription check is best-effort; don't block test loading if it fails.
      }
      setState(() {
        _test = test;
        _subscription = sub;
        _secondsLeft = _allowedSeconds(test);
        _qStates.addAll({for (int i = 0; i < test.questions.length; i++) i: QState.notVisited});
        _loading = false;
      });
    } catch (e) {
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  /// Ask for the account before the clock starts, not after the answers.
  ///
  /// Submitting requires a signed-in student, so an anonymous reader who
  /// starts anyway spends fifteen minutes and then loses the lot. The test
  /// stays readable to anyone — that is what a shared link is for — but
  /// taking it begins here.
  Future<void> _startTest() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('student_token') ?? '';
    if (token.isEmpty) {
      if (!mounted) return;
      final ok = await showAuthSheet(context,
          reason: 'to take this test and keep your score');
      if (!ok || !mounted) return;
    }
    setState(() { _started = true; _qStates[0] = QState.visitedNotAnswered; });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _secondsTaken++;
        if (_secondsLeft > 0) {
          _secondsLeft--;
        } else {
          _submitTest();
        }
      });
    });
  }

  /// How long this paper runs, in seconds.
  ///
  /// The seconds figure wins when it is set: a scholarship test can be
  /// thirty seconds long, and whole minutes cannot say that.
  int _allowedSeconds(AltroTest test) =>
      test.durationSeconds > 0 ? test.durationSeconds : test.durationMins * 60;

  void _retake() {
    _timer?.cancel();
    setState(() {
      _result = null;
      _answers.clear();
      _qStates.clear();
      _qStates.addAll({for (int i = 0; i < _test!.questions.length; i++) i: QState.notVisited});
      _currentQ = 0;
      _secondsTaken = 0;
      _secondsLeft = _allowedSeconds(_test!);
      _started = false;
    });
  }

  String get _timerDisplay {
    final m = _secondsLeft ~/ 60;
    final s = _secondsLeft % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  bool get _isTimeCritical => _secondsLeft < 300;

  void _navigateTo(int i) {
    setState(() {
      // mark current as visited-not-answered if no answer
      if (_qStates[_currentQ] == QState.notVisited) {
        _qStates[_currentQ] = QState.visitedNotAnswered;
      }
      _currentQ = i;
      if (_qStates[i] == QState.notVisited) {
        _qStates[i] = QState.visitedNotAnswered;
      }
    });
  }

  void _selectAnswer(String key) {
    setState(() {
      _answers[_currentQ] = key;
      if (_qStates[_currentQ] == QState.markedForReview) {
        _qStates[_currentQ] = QState.answeredAndMarked;
      } else {
        _qStates[_currentQ] = QState.answered;
      }
    });
  }

  void _clearResponse() {
    setState(() {
      _answers.remove(_currentQ);
      _qStates[_currentQ] = QState.visitedNotAnswered;
    });
  }

  void _markForReview() {
    setState(() {
      if (_answers.containsKey(_currentQ)) {
        _qStates[_currentQ] = QState.answeredAndMarked;
      } else {
        _qStates[_currentQ] = QState.markedForReview;
      }
      _goNext();
    });
  }

  void _saveAndNext() {
    if (!_answers.containsKey(_currentQ)) {
      _qStates[_currentQ] = QState.visitedNotAnswered;
    }
    _goNext();
  }

  void _goNext() {
    if (_currentQ < _test!.questions.length - 1) {
      _navigateTo(_currentQ + 1);
    }
  }

  int get _answeredCount => _answers.length;
  int get _notAnsweredCount => _qStates.values.where((s) => s == QState.visitedNotAnswered).length;
  int get _markedCount => _qStates.values.where((s) => s == QState.markedForReview || s == QState.answeredAndMarked).length;
  int get _notVisitedCount => _qStates.values.where((s) => s == QState.notVisited).length;

  Future<void> _submitTest() async {
    if (_submitted) return;
    _timer?.cancel();
    setState(() => _submitted = true);
    try {
      final data = await ApiService.submitAttempt(widget.testId, {
        'answers': _answers.map((k, v) => MapEntry(k.toString(), v)),
        'student_id': (_studentId != null && _studentId! > 0) ? _studentId : null,
        'student_phone': _studentPhone,
        'student_name': _studentName,
      });
      setState(() => _result = TestAttemptResult.fromJson(Map<String, dynamic>.from(data)));
    } catch (e) {
      setState(() => _submitted = false);
      if (!mounted) return;
      // 429 is the daily quiz limit. Match on the status code, not on words
      // in the message — the old check also fired on any unrelated error that
      // happened to contain "limit".
      if (e is ApiException && e.statusCode == 429) {
        _showQuizLimitDialog(e.message);
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
      }
    }
  }

  void _showUpgradeSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => UpgradeSheet(
        lastResult: null,
        onPaymentOpened: _startSubscriptionVerification,
      ),
    );
  }

  // Polls backend every 5 seconds for up to 3 minutes after payment link opened.
  void _startSubscriptionVerification() {
    int attempts = 0;
    const maxAttempts = 36; // 36 x 5s = 3 min
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 5));
      if (!mounted) return false;
      attempts++;
      try {
        final res = await ApiService.verifyStudentSubscription();
        if (res['status'] == 'paid') {
          if (mounted) {
            setState(() {
              _subscription = {
                ..._subscription ?? {},
                'is_premium': true,
                'plan': 'premium',
                'remaining_today': -1,
              };
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Premium activated! Unlimited quizzes unlocked.'),
                backgroundColor: AppColors.success,
                duration: Duration(seconds: 4),
              ),
            );
          }
          return false;
        }
      } catch (_) {}
      return attempts < maxAttempts && mounted;
    });
  }

  /// [message] comes from the server, which knows the student's actual plan
  /// and limit. The old copy hardcoded "3 free quizzes" and "Premium
  /// (₹49/month) for unlimited access" — by now all three were wrong, and it
  /// offered no way to act on it.
  void _showQuizLimitDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.lock_clock_rounded, color: AppColors.warning, size: 40),
        title: Text('Daily limit reached',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 17)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(message, textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13.5, height: 1.5)),
          const SizedBox(height: 10),
          // The submit failed but nothing was thrown away — _answers is still
          // in memory and the screen stays open, so say so instead of leaving
          // them wondering whether the attempt is gone.
          Text('Your answers are still here — submit again once you have room.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 12, height: 1.4, color: AppColors.textSecondary)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.push('/pricing');
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('See plans'),
          ),
        ],
      ),
    );
  }

  void _showSubmitConfirm() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Submit Test?', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _SummaryRow('Answered', _answeredCount, AppColors.success),
          _SummaryRow('Not Answered', _notAnsweredCount, AppColors.error),
          _SummaryRow('Marked for Review', _markedCount, AppColors.accent),
          _SummaryRow('Not Visited', _notVisitedCount, const Color(0xFF9E9E9E)),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))),
            const SizedBox(width: 12),
            Expanded(child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () { Navigator.pop(context); _submitTest(); },
              child: const Text('Submit Test'),
            )),
          ]),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 16),
          Text('Loading test...', style: GoogleFonts.inter(color: Colors.grey)),
        ])),
      );
    }
    if (_error != null || _test == null) {
      // "Test not found" was printed for every failure — a dead network, a
      // slow one, a server error — so a link that worked perfectly well
      // looked like a broken link, and there was nothing to do about it.
      final missing = _error == null;
      return Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          title: Text('Test',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(missing ? Icons.search_off_rounded : Icons.wifi_off_rounded,
                  size: 40, color: AppColors.textSecondary),
              const SizedBox(height: 14),
              Text(
                  missing
                      ? 'This test is no longer available.'
                      : _error!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      fontSize: 14, height: 1.5,
                      color: AppColors.textSecondary)),
              const SizedBox(height: 18),
              Wrap(spacing: 10, runSpacing: 10, children: [
                if (!missing)
                  FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 26, vertical: 12)),
                    onPressed: _load,
                    child: Text('Try again',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600, fontSize: 13.5)),
                  ),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 26, vertical: 12)),
                  onPressed: () => context.go('/student/test-series'),
                  child: Text('See all tests',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600, fontSize: 13.5)),
                ),
              ]),
            ]),
          ),
        ),
      );
    }
    if (_result != null) {
      return _ResultScreen(result: _result!, test: _test!, answers: _answers,
          timeTaken: '${_secondsTaken ~/ 60}m ${_secondsTaken % 60}s',
          onRetake: _retake);
    }
    if (!_started && _quizBlocked) return _buildLimitReachedScreen();
    if (!_started) return _InstructionsScreen(test: _test!, onStart: _startTest);

    final q = _test!.questions[_currentQ];
    final total = _test!.questions.length;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        if (await _confirmExit()) nav.pop();
      },
      child: Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: Container(
          color: AppColors.primary,
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top, left: 16, right: 16, bottom: 8),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_test!.title, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
              Text('${_test!.subject} | ${_test!.examType}', style: GoogleFonts.inter(color: Colors.white70, fontSize: 11)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _isTimeCritical ? Colors.red.shade700 : Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
                border: _isTimeCritical ? Border.all(color: Colors.red.shade300) : null,
              ),
              child: Row(children: [
                Icon(Icons.timer_rounded, color: _isTimeCritical ? Colors.white : Colors.white70, size: 14),
                const SizedBox(width: 4),
                Text(_timerDisplay, style: GoogleFonts.poppins(
                    color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              ]),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _scaffoldKey.currentState?.openEndDrawer(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                child: Row(children: [
                  const Icon(Icons.grid_view_rounded, color: Colors.white, size: 16),
                  const SizedBox(width: 4),
                  Text('$_answeredCount/$total', style: GoogleFonts.poppins(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ]),
        ),
      ),
      endDrawer: _QuestionPalette(
        total: total,
        currentQ: _currentQ,
        qStates: _qStates,
        onTap: (i) { Navigator.pop(context); _navigateTo(i); },
        answered: _answeredCount,
        notAnswered: _notAnsweredCount,
        markedCount: _markedCount,
        notVisited: _notVisitedCount,
        onSubmit: _showSubmitConfirm,
      ),
      body: Column(children: [
        // Question number strip
        Container(
          color: AppColors.primary.withValues(alpha: 0.08),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(children: [
            Text('Question ${_currentQ + 1} of $total',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppColors.primary, fontSize: 13)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _qColor(_qStates[_currentQ] ?? QState.notVisited).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(_qStateLabel(_qStates[_currentQ] ?? QState.notVisited),
                  style: TextStyle(fontSize: 11, color: _qColor(_qStates[_currentQ] ?? QState.notVisited), fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
        // Question body
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${_currentQ + 1}. ${q.question}',
                        style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w500, height: 1.5, color: Colors.black87)),
                    const SizedBox(height: 16),
                    ...q.options.entries.map((e) {
                      final selected = _answers[_currentQ] == e.key;
                      return GestureDetector(
                        onTap: () => _selectAnswer(e.key),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: selected ? AppColors.primary : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: selected ? AppColors.primary : Colors.grey.shade300,
                              width: selected ? 2 : 1,
                            ),
                          ),
                          child: Row(children: [
                            Container(
                              width: 28, height: 28,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: selected ? Colors.white : AppColors.primary.withValues(alpha: 0.1),
                              ),
                              child: Center(child: Text(e.key, style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: selected ? AppColors.primary : AppColors.primary,
                                  fontSize: 13))),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Text(e.value, style: TextStyle(
                                color: selected ? Colors.white : Colors.black87, fontSize: 14, height: 1.3))),
                          ]),
                        ),
                      );
                    }),
                  ]),
                ),
              ),
            ]),
          ),
        ),
        // Bottom action buttons (NTA style)
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Column(children: [
            Row(children: [
              Expanded(child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accent,
                    side: const BorderSide(color: AppColors.accent),
                    padding: const EdgeInsets.symmetric(vertical: 10)),
                onPressed: _markForReview,
                child: Text('Mark for Review & Next', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600)),
              )),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey.shade700,
                    side: BorderSide(color: Colors.grey.shade400),
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12)),
                onPressed: _clearResponse,
                child: Text('Clear', style: GoogleFonts.inter(fontSize: 12)),
              ),
              const SizedBox(width: 8),
              if (_currentQ > 0)
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12)),
                  onPressed: () => _navigateTo(_currentQ - 1),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.arrow_back_ios, size: 12),
                    Text('Back', style: GoogleFonts.inter(fontSize: 12)),
                  ]),
                ),
              const Spacer(),
              if (_currentQ < total - 1)
                FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16)),
                  onPressed: _saveAndNext,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('Save & Next', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_ios, size: 12),
                  ]),
                )
              else
                FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16)),
                  onPressed: _submitted ? null : _showSubmitConfirm,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.check_circle_rounded, size: 16),
                    const SizedBox(width: 6),
                    Text(_submitted ? 'Submitting...' : 'Submit', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                  ]),
                ),
            ]),
          ]),
        ),
      ]),
      ),
    );
  }

  /// A test in progress is timed and single-attempt, so a stray back gesture
  /// must not silently discard it. Submitting is the only clean way out.
  Future<bool> _confirmExit() async {
    final total = _test?.questions.length ?? 0;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Leave the test?',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 17)),
        content: Text(
          'You have answered ${_answers.length} of $total questions. '
          'Leaving now abandons the attempt — it will not be scored or saved.',
          style: GoogleFonts.inter(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Keep going', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text('Leave', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Widget _buildLimitReachedScreen() {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Text('Daily Limit Reached', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_clock_rounded, color: AppColors.warning, size: 56),
              const SizedBox(height: 16),
              Text("You've used today's free quizzes",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              // No price in this copy — the sheet reads the live price from
              // the subscription API, so hardcoding one here only creates a
              // second number to keep in sync (it was still advertising ₹49).
              Text('Upgrade for unlimited quiz attempts.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 14, color: Colors.grey)),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: _showUpgradeSheet,
                  child: Text('See upgrade options',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Kal Aana'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _qStateLabel(QState s) {
  switch (s) {
    case QState.notVisited: return 'Not Visited';
    case QState.visitedNotAnswered: return 'Not Answered';
    case QState.answered: return 'Answered';
    case QState.markedForReview: return 'Marked for Review';
    case QState.answeredAndMarked: return 'Answered & Marked';
  }
}

// ─── Instructions Screen ─────────────────────────────────────────────────────

/// "30s", "2 min", "2 min 30s" — whichever the number actually is.
String _readableTime(int seconds) {
  if (seconds < 60) return '${seconds}s';
  final m = seconds ~/ 60, sec = seconds % 60;
  return sec == 0 ? '$m min' : '$m min ${sec}s';
}

class _InstructionsScreen extends StatelessWidget {
  final AltroTest test;
  final VoidCallback onStart;
  const _InstructionsScreen({required this.test, required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Text('General Instructions', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: 'Copy link to this test',
            onPressed: () => shareTestLink(context,
                id: test.id,
                title: test.title,
                minutes: test.durationMins,
                questions: test.questions.length),
            icon: const Icon(Icons.link_rounded, size: 21, color: Colors.white),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Card(
            color: AppColors.primary.withValues(alpha: 0.06),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                Row(children: [
                  const Icon(Icons.quiz_rounded, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(test.title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primary))),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  _InfoBadge(Icons.subject_rounded, test.subject),
                  const SizedBox(width: 8),
                  _InfoBadge(
                      Icons.timer_rounded,
                      test.durationSeconds > 0
                          ? _readableTime(test.durationSeconds)
                          : '${test.durationMins} min'),
                  const SizedBox(width: 8),
                  _InfoBadge(Icons.quiz_outlined, '${test.questions.length} Qs'),
                ]),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          Text('Read the following instructions carefully:', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 12),
          const _Instruction('1', 'Total duration of this test is ${0} minutes. The timer will be displayed on the top right corner.', isTemplate: true, templateKey: 'duration'),
          _Instruction('1', 'Total duration of this test is ${test.durationMins} minutes. The timer will be displayed on top right.'),
          const _Instruction('2', 'The clock will be set at the server. The countdown timer at the top shows remaining time.'),
          const _Instruction('3', 'When the timer reaches zero, the test will automatically submit. Save your responses before time runs out.'),
          const _Instruction('4', 'Click on a question number in the palette to navigate to that question.'),
          const _Instruction('5', 'To answer a question: click on one of the options. Click again to deselect.'),
          const _Instruction('6', '"Save & Next" button saves your answer and moves to next question.'),
          const _Instruction('7', '"Mark for Review & Next" saves your answer (if any) and marks the question for later review.'),
          const _Instruction('8', '"Clear" button removes your selected answer for the current question.'),
          const SizedBox(height: 16),
          Text('Question Palette Legend:', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          const _LegendRow(Color(0xFF9E9E9E), 'Not Visited', 'You have not visited this question yet.'),
          const _LegendRow(AppColors.error, 'Not Answered', 'Visited but no answer selected.'),
          const _LegendRow(AppColors.success, 'Answered', 'Answer saved.'),
          const _LegendRow(AppColors.accent, 'Marked for Review', 'Marked for review. Will be evaluated if answered.'),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 14)),
              onPressed: onStart,
              child: Text('I am ready to begin', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
            )),
          ]),
          const SizedBox(height: 8),
          Center(child: Text('By clicking above, you agree to follow the exam rules.', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey))),
        ]),
      ),
    );
  }
}

class _Instruction extends StatelessWidget {
  final String num;
  final String text;
  final bool isTemplate;
  final String? templateKey;
  const _Instruction(this.num, this.text, {this.isTemplate = false, this.templateKey});

  @override
  Widget build(BuildContext context) {
    if (isTemplate) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 22, height: 22,
          decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: Center(child: Text(num, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary))),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: GoogleFonts.inter(fontSize: 13, height: 1.4, color: Colors.black87))),
      ]),
    );
  }
}

class _InfoBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoBadge(this.icon, this.label);

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 14, color: AppColors.primary),
    const SizedBox(width: 4),
    Text(label, style: GoogleFonts.inter(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w500)),
  ]);
}

class _LegendRow extends StatelessWidget {
  final Color color;
  final String label;
  final String desc;
  const _LegendRow(this.color, this.label, this.desc);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(children: [
      Container(width: 24, height: 24, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
          child: const Center(child: Text('1', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)))),
      const SizedBox(width: 10),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12)),
        Text(desc, style: GoogleFonts.inter(fontSize: 11, color: Colors.grey)),
      ]),
    ]),
  );
}

// ─── Question Palette Drawer ──────────────────────────────────────────────────

class _QuestionPalette extends StatelessWidget {
  final int total, currentQ, answered, notAnswered, markedCount, notVisited;
  final Map<int, QState> qStates;
  final ValueChanged<int> onTap;
  final VoidCallback onSubmit;

  const _QuestionPalette({
    required this.total, required this.currentQ, required this.qStates,
    required this.onTap, required this.answered, required this.notAnswered,
    required this.markedCount, required this.notVisited, required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(children: [
        Container(
          color: AppColors.primary,
          padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 12, 16, 12),
          child: Column(children: [
            Row(children: [
              Text('Question Palette', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
              const Spacer(),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: Colors.white, size: 20), padding: EdgeInsets.zero),
            ]),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              _PaletteStat(answered, AppColors.success, 'Answered'),
              _PaletteStat(notAnswered, AppColors.error, 'Not Ans.'),
              _PaletteStat(markedCount, AppColors.accent, 'Marked'),
              _PaletteStat(notVisited, const Color(0xFF9E9E9E), 'Not Visited'),
            ]),
          ]),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5, mainAxisSpacing: 8, crossAxisSpacing: 8,
            ),
            itemCount: total,
            itemBuilder: (_, i) {
              final state = qStates[i] ?? QState.notVisited;
              final isCurrent = i == currentQ;
              return GestureDetector(
                onTap: () => onTap(i),
                child: Container(
                  decoration: BoxDecoration(
                    color: _qColor(state),
                    borderRadius: BorderRadius.circular(6),
                    border: isCurrent ? Border.all(color: Colors.yellow, width: 2) : null,
                  ),
                  child: Center(child: Text('${i + 1}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).padding.bottom + 16),
          child: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.green.shade700, minimumSize: const Size(double.infinity, 46)),
            onPressed: () { Navigator.pop(context); onSubmit(); },
            child: Text('Submit Test', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
          ),
        ),
      ]),
    );
  }
}

class _PaletteStat extends StatelessWidget {
  final int count;
  final Color color;
  final String label;
  const _PaletteStat(this.count, this.color, this.label);

  @override
  Widget build(BuildContext context) => Column(children: [
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
      child: Text('$count', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
    ),
    const SizedBox(height: 2),
    Text(label, style: GoogleFonts.inter(color: Colors.white70, fontSize: 9)),
  ]);
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _SummaryRow(this.label, this.count, this.color);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      Container(width: 20, height: 20, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
          child: Center(child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)))),
      const SizedBox(width: 10),
      Text(label, style: GoogleFonts.inter(fontSize: 14)),
      const Spacer(),
      Text('$count', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: color)),
    ]),
  );
}

// ─── Result Screen ────────────────────────────────────────────────────────────

class _ResultScreen extends StatefulWidget {
  final TestAttemptResult result;
  final AltroTest test;
  final Map<int, String> answers;
  final String timeTaken;
  final VoidCallback onRetake;

  const _ResultScreen({required this.result, required this.test, required this.answers,
      required this.timeTaken, required this.onRetake});

  @override
  State<_ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<_ResultScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  String? _aiFeedback;
  bool _loadingFeedback = true;
  Map<String, dynamic>? _next;
  Map<String, dynamic>? _scholarship;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _loadAiFeedback();
    _loadNext();
    _loadScholarship();
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  /// What to do next, worked out from their own results rather than written
  /// by the model. Silent on failure: a missing suggestion is a smaller loss
  /// than an error banner on top of a score somebody just earned.
  Future<void> _loadNext() async {
    try {
      final d = await ApiService.getAfterTest(widget.test.id);
      if (mounted && (d['cards'] as List?)?.isNotEmpty == true) {
        setState(() => _next = d);
      }
    } catch (_) {}
  }

  /// Was this the scholarship test, and what did it earn them?
  ///
  /// Asked after the score is on screen rather than before: the number they
  /// got is the thing they came for, and an offer arriving underneath it
  /// lands better than one that interrupts it. Silent when this was an
  /// ordinary test, which is almost always.
  Future<void> _loadScholarship() async {
    try {
      final cfg = await ApiService.getScholarship();
      if (cfg['enabled'] != true) return;
      if ((cfg['test']?['id'] as num?)?.toInt() != widget.test.id) return;

      final res = await ApiService.claimScholarship();
      if (mounted) setState(() => _scholarship = res);
    } catch (_) {
      // A scholarship that cannot be worked out is not worth an error on a
      // page somebody is reading their result on.
    }
  }

  Widget _scholarshipCard() {
    final s = _scholarship!;
    final awarded = s['awarded'] == true;
    final percent = (s['percent'] as num?)?.toDouble() ?? 0;
    final base = (s['base_amount'] as num?)?.toDouble() ?? 0;

    if (!awarded) {
      return Card(
        color: AppColors.warning.withValues(alpha: 0.10),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Scholarship: not this time',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 6),
            Text(
                'You scored ${percent.toStringAsFixed(0)}%. The lowest '
                'scholarship band starts at 50%. You can take it again — the '
                'best score counts.',
                style: GoogleFonts.inter(
                    fontSize: 12.5, height: 1.55, color: Colors.black87)),
          ]),
        ),
      );
    }

    final off = (s['discount_percent'] as num?)?.toInt() ?? 0;
    final pay = (s['you_pay'] as num?)?.toDouble() ?? base;
    final code = '${s['coupon_code'] ?? ''}';
    final days = (s['valid_days'] as num?)?.toInt() ?? 14;

    return Card(
      color: AppColors.success.withValues(alpha: 0.10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.workspace_premium_rounded,
                color: AppColors.success, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Scholarship earned — $off% off',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      fontSize: 15.5,
                      color: AppColors.success)),
            ),
          ]),
          const SizedBox(height: 8),
          Text(
              'You scored ${percent.toStringAsFixed(0)}%'
              '${s['label'] == null ? '' : " (${s['label']})"}.',
              style: GoogleFonts.inter(fontSize: 12.5, color: Colors.black87)),
          const SizedBox(height: 12),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('Rs ${base.toStringAsFixed(0)}',
                style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.grey,
                    decoration: TextDecoration.lineThrough)),
            const SizedBox(width: 10),
            Text('Rs ${pay.toStringAsFixed(0)}',
                style: GoogleFonts.poppins(
                    fontSize: 24,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary)),
          ]),
          const SizedBox(height: 12),
          // The code, big enough to read off a screen and copyable, because
          // it is the one thing on this card they have to carry to the form.
          InkWell(
            onTap: () {
              Clipboard.setData(ClipboardData(text: code));
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Code copied')));
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
              ),
              child: Row(children: [
                Expanded(
                  child: Text(code,
                      style: GoogleFonts.poppins(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.6,
                          color: AppColors.primary)),
                ),
                const Icon(Icons.copy_rounded,
                    size: 17, color: AppColors.textSecondary),
              ]),
            ),
          ),
          const SizedBox(height: 8),
          Text(
              'Yours alone, and valid for $days days. Enter it at '
              'registration.',
              style: GoogleFonts.inter(
                  fontSize: 11.5, height: 1.4, color: AppColors.textSecondary)),
        ]),
      ),
    );
  }

  Widget _nextSteps() {
    final cards = (_next?['cards'] as List?) ?? const [];
    final note = '${_next?['note'] ?? ''}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('What next',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600, fontSize: 14)),
          if (note.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(note,
                style: GoogleFonts.inter(
                    fontSize: 11.5, height: 1.45, color: Colors.grey)),
          ],
          const SizedBox(height: 12),
          for (final raw in cards)
            _nextCard(Map<String, dynamic>.from(raw as Map)),
        ]),
      ),
    );
  }

  Widget _nextCard(Map<String, dynamic> c) {
    final kind = '${c['kind']}';
    final done = kind == 'series_complete';
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: const Color(0xFFE6EBF3)),
      ),
      child: InkWell(
        onTap: done
            ? null
            : () {
                if (c['test_id'] != null && kind == 'retake') {
                  widget.onRetake();
                } else if (c['test_id'] != null) {
                  context.pushReplacement('/test/${c['test_id']}');
                } else if (c['series_id'] != null) {
                  context.push('/test-series/${c['series_id']}');
                }
              },
        borderRadius: BorderRadius.circular(11),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${c['label']}',
                        style: GoogleFonts.inter(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: AppColors.accent)),
                    const SizedBox(height: 3),
                    Text('${c['title']}',
                        style: GoogleFonts.poppins(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary)),
                    const SizedBox(height: 3),
                    // The reason names one of their own results. A suggestion
                    // that cannot say where it came from is just an advert.
                    Text('${c['reason']}',
                        style: GoogleFonts.inter(
                            fontSize: 11.5, height: 1.45, color: Colors.grey)),
                  ]),
            ),
            if (!done)
              const Icon(Icons.chevron_right_rounded,
                  size: 20, color: Color(0xFFC3CCD9)),
          ]),
        ),
      ),
    );
  }

  Future<void> _loadAiFeedback() async {
    try {
      final wrong = <String>[];
      for (int i = 0; i < widget.test.questions.length; i++) {
        final q = widget.test.questions[i];
        final ans = widget.answers[i];
        if (ans != q.correct) wrong.add('Q${i + 1}: ${q.question} (Yours: ${ans ?? "skipped"}, Correct: ${q.correct})');
      }
      final res = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/tests/ai-feedback'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'subject': widget.test.subject, 'topic': widget.test.topic,
          'score': widget.result.score, 'total': widget.result.total,
          'percentage': widget.result.percentage, 'wrong_questions': wrong.take(5).toList()}),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() { _aiFeedback = data['feedback']; });
      }
    } catch (_) {}
    setState(() => _loadingFeedback = false);
  }

  @override
  Widget build(BuildContext context) {
    final pct = widget.result.percentage;
    final color = pct >= 70 ? AppColors.success : pct >= 40 ? AppColors.warning : AppColors.error;
    final grade = pct >= 80 ? 'Excellent! 🎉' : pct >= 60 ? 'Good Job! 👍' : pct >= 40 ? 'Keep Practicing 📚' : 'Needs Improvement 💪';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Text('Result', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
        automaticallyImplyLeading: false,
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.score_rounded, size: 16), text: 'Score Card'),
            Tab(icon: Icon(Icons.fact_check_rounded, size: 16), text: 'Answer Key'),
          ],
        ),
      ),
      body: TabBarView(controller: _tabs, children: [
        // Score Card
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(children: [
                  Container(
                    width: 120, height: 120,
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color, width: 5), color: color.withValues(alpha: 0.08)),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text('${pct.toStringAsFixed(0)}%', style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
                      Text('${widget.result.score}/${widget.result.total}', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  Text(grade, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(widget.test.title, style: GoogleFonts.inter(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 16),
                  Row(children: [
                    _ScoreStat('Correct', '${widget.result.score}', AppColors.success),
                    _ScoreStat('Wrong', '${widget.result.total - widget.result.score}', AppColors.error),
                    _ScoreStat('Time', widget.timeTaken, AppColors.primary),
                    _ScoreStat('Accuracy', '${pct.toStringAsFixed(0)}%', color),
                  ]),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: widget.onRetake,
                      icon: const Icon(Icons.replay_rounded, size: 18),
                      label: Text('Retake Test', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: AppColors.primary),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Text('🤖', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Text('AI Performance Analysis', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
                  ]),
                  const SizedBox(height: 12),
                  if (_loadingFeedback)
                    const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
                  else if (_aiFeedback != null)
                    Text(_aiFeedback!, style: GoogleFonts.inter(height: 1.6, fontSize: 13, color: Colors.black87))
                  else
                    Text('Review the Answer Key tab to see your mistakes.',
                        style: GoogleFonts.inter(color: Colors.grey, fontSize: 13)),
                ]),
              ),
            ),
            if (_scholarship != null) ...[
              const SizedBox(height: 12),
              _scholarshipCard(),
            ],
            if (_next != null) ...[
              const SizedBox(height: 12),
              _nextSteps(),
            ],
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: OutlinedButton.icon(
                onPressed: () => _tabs.animateTo(1),
                icon: const Icon(Icons.fact_check_rounded, size: 16),
                label: const Text('Answer Key'),
              )),
              const SizedBox(width: 12),
              Expanded(child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.home_rounded, size: 16),
                label: const Text('Home'),
              )),
            ]),
          ]),
        ),

        // Answer Key
        ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: widget.test.questions.length,
          itemBuilder: (_, i) {
            final q = widget.test.questions[i];
            final studentAns = widget.answers[i];
            final isCorrect = studentAns == q.correct;
            final borderColor = studentAns == null ? Colors.grey.shade300 : isCorrect ? AppColors.success : AppColors.error;

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: borderColor.withValues(alpha: 0.5), width: 1.5)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: borderColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(studentAns == null ? Icons.remove_circle_outline : isCorrect ? Icons.check_circle : Icons.cancel,
                            size: 13, color: borderColor),
                        const SizedBox(width: 4),
                        Text(studentAns == null ? 'Not Attempted' : isCorrect ? 'Correct' : 'Incorrect',
                            style: TextStyle(color: borderColor, fontSize: 11, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                    const SizedBox(width: 8),
                    Text('Q${i + 1}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                  ]),
                  const SizedBox(height: 8),
                  Text(q.question, style: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 13, height: 1.4)),
                  const SizedBox(height: 8),
                  ...q.options.entries.map((e) {
                    final isStudentChoice = e.key == studentAns;
                    final isCorrectOpt = e.key == q.correct;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 3),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: isCorrectOpt ? AppColors.success.withValues(alpha: 0.1) : isStudentChoice && !isCorrectOpt ? AppColors.error.withValues(alpha: 0.08) : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(children: [
                        Text(e.key, style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isCorrectOpt ? AppColors.success : isStudentChoice ? AppColors.error : Colors.grey,
                            fontSize: 12)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(e.value, style: TextStyle(
                            fontSize: 12,
                            color: isCorrectOpt || isStudentChoice ? Colors.black87 : Colors.grey.shade600))),
                        if (isCorrectOpt) const Icon(Icons.check_circle, size: 14, color: AppColors.success),
                        if (isStudentChoice && !isCorrectOpt) const Icon(Icons.cancel, size: 14, color: AppColors.error),
                      ]),
                    );
                  }),
                  if (q.explanation.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(6)),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('💡 ', style: TextStyle(fontSize: 12)),
                        Expanded(child: Text(q.explanation, style: GoogleFonts.inter(fontSize: 11, color: Colors.black87, height: 1.4))),
                      ]),
                    ),
                  ],
                ]),
              ),
            );
          },
        ),
      ]),
    );
  }
}

class _ScoreStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _ScoreStat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Expanded(child: Column(children: [
    Text(value, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
    Text(label, style: GoogleFonts.inter(fontSize: 10, color: Colors.grey)),
  ]));
}
