import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants/app_colors.dart';
import '../../constants/api_constants.dart';
import '../../services/api_service.dart';

const _accent = AppColors.accent;

/// Self-practice: student generates an AI test and attempts it inline.
/// The generated questions are not saved as institute `tests`, but the
/// finished attempt is recorded in practice_attempts so the student and
/// admins can see what was taken and scored.
class StudentPracticeScreen extends StatefulWidget {
  final String? initialSubject;
  const StudentPracticeScreen({super.key, this.initialSubject});

  @override
  State<StudentPracticeScreen> createState() => _StudentPracticeScreenState();
}

class _StudentPracticeScreenState extends State<StudentPracticeScreen> {
  // phase: 'form' | 'generating' | 'quiz' | 'done'
  String _phase = 'form';

  // Quota
  int _remaining = -1;
  int _limit = 0;
  bool _isPremium = false;

  // Form state
  String _subject = 'Embedded C';
  final _topicCtrl = TextEditingController();
  String _difficulty = 'Medium';
  int _count = 10;
  String _language = 'English';

  static const _subjects = [
    'Embedded C',
    'Electronics Fundamentals',
    'ESP32 / Microcontrollers',
    'IoT Protocols',
    'Circuit Design & PCB',
    'Sensors',
    'AI/ML for Embedded',
    'FreeRTOS / RTOS',
  ];

  // Quiz state
  List<Map<String, dynamic>> _questions = [];
  int _qIndex = 0;
  String? _selected; // selected option key for current question
  final List<String?> _answers = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialSubject != null) _subject = widget.initialSubject!;
    _loadQuota();
  }

  @override
  void dispose() {
    _topicCtrl.dispose();
    super.dispose();
  }

  Future<String> _token() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('student_token') ?? '';
  }

  Future<void> _loadQuota() async {
    try {
      final res = await http.get(
        Uri.parse(ApiConstants.studentSubscription()),
        headers: {'Authorization': 'Bearer ${await _token()}'},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _remaining = data['generations_remaining'] ?? 0;
            _limit = data['monthly_generation_limit'] ?? 0;
            _isPremium = data['is_premium'] == true;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _generate() async {
    if (_topicCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Enter a topic — e.g. Pointers, GPIO, MQTT QoS'),
          backgroundColor: AppColors.error));
      return;
    }
    setState(() => _phase = 'generating');
    try {
      final res = await http.post(
        Uri.parse(ApiConstants.studentGenerateTest()),
        headers: {
          'Authorization': 'Bearer ${await _token()}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'subject': _subject,
          'topic': _topicCtrl.text.trim(),
          'difficulty': _difficulty,
          'count': _count,
          'language': _language,
        }),
      );
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 429) {
        if (mounted) {
          setState(() => _phase = 'form');
          _showLimitDialog(body['detail']?.toString() ?? 'Monthly limit reached');
        }
        return;
      }
      if (res.statusCode >= 400) throw body['detail'] ?? 'Generation failed';

      final qs = List<Map<String, dynamic>>.from(body['questions'] ?? []);
      if (qs.isEmpty) throw 'No questions generated. Try a different topic.';
      setState(() {
        _questions = qs;
        _qIndex = 0;
        _selected = null;
        _answers
          ..clear()
          ..addAll(List.filled(qs.length, null));
        _phase = 'quiz';
      });
      _loadQuota();
    } catch (e) {
      if (!mounted) return;
      setState(() => _phase = 'form');
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error));
    }
  }

  void _showLimitDialog(String reason) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          const Icon(Icons.hourglass_empty_rounded, color: AppColors.warning),
          const SizedBox(width: 10),
          Text('Limit Reached',
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
        ]),
        content: Text(reason, style: GoogleFonts.inter(fontSize: 13)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK')),
          if (!_isPremium)
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _accent),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context, 'upgrade'); // home handles upgrade sheet
              },
              child: const Text('Upgrade'),
            ),
        ],
      ),
    );
  }

  int get _score {
    int s = 0;
    for (int i = 0; i < _questions.length; i++) {
      if (_answers[i] != null && _answers[i] == _questions[i]['correct']) s++;
    }
    return s;
  }

  /// The result used to live only in this widget's state, so closing the
  /// screen erased any record that the test was ever taken. Persist it so it
  /// shows up in My Test Results and the admin activity view.
  bool _recorded = false;
  Future<void> _recordAttempt() async {
    if (_recorded) return;
    _recorded = true;
    try {
      await ApiService.recordPracticeAttempt({
        'subject': _subject,
        'topic': _topicCtrl.text.trim(),
        'difficulty': _difficulty,
        'language': _language,
        'score': _score,
        'total': _questions.length,
        'answers': [
          for (int i = 0; i < _questions.length; i++)
            {
              'q': _questions[i]['question'],
              'chosen': _answers[i],
              'correct': _questions[i]['correct'],
            },
        ],
      });
    } catch (_) {
      // Recording is best-effort — never block the student from seeing
      // their result because the write failed.
    }
  }

  /// Leaving mid-quiz throws the generated questions away and still burns a
  /// generation against the monthly quota, so make it a deliberate choice.
  Future<bool> _confirmExit() async {
    if (_phase != 'quiz') return true;
    final answered = _answers.where((a) => a != null).length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Leave this test?',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 17)),
        content: Text(
          answered > 0
              ? 'You have answered $answered of ${_questions.length} questions. '
                  'Leaving now discards them and this test cannot be resumed.'
              : 'Leaving now discards this test and it cannot be resumed.',
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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _phase != 'quiz',
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        if (await _confirmExit()) nav.pop();
      },
      child: Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: _accent,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text('AI Practice Test',
            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
        actions: [
          if (_remaining >= 0)
            Center(
              child: Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text('$_remaining / $_limit left',
                    style: GoogleFonts.poppins(
                        color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ),
        ],
      ),
      body: switch (_phase) {
        'generating' => _buildGenerating(),
        'quiz' => _buildQuiz(),
        'done' => _buildResult(),
        _ => _buildForm(),
      },
      ),
    );
  }

  // ── Form ────────────────────────────────────────────────────────────────

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Subject', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _subjects.map((s) {
              final active = _subject == s;
              return ChoiceChip(
                label: Text(s),
                selected: active,
                onSelected: (_) => setState(() => _subject = s),
                selectedColor: _accent,
                labelStyle: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: active ? Colors.white : AppColors.textSecondary),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          Text('Topic', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 8),
          TextField(
            controller: _topicCtrl,
            decoration: InputDecoration(
              hintText: 'e.g. Pointers & Arrays, GPIO Interfacing, MQTT QoS',
              prefixIcon: const Icon(Icons.topic_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true, fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 20),

          Text('Difficulty', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 10),
          Row(
            children: ['Easy', 'Medium', 'Hard'].map((d) {
              final active = _difficulty == d;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(d),
                  selected: active,
                  onSelected: (_) => setState(() => _difficulty = d),
                  selectedColor: _accent,
                  labelStyle: GoogleFonts.inter(
                      fontSize: 12, fontWeight: FontWeight.w600,
                      color: active ? Colors.white : AppColors.textSecondary),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Questions',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 10),
                Row(
                  children: [5, 10, 15].map((c) {
                    final active = _count == c;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text('$c'),
                        selected: active,
                        onSelected: (_) => setState(() => _count = c),
                        selectedColor: _accent,
                        labelStyle: GoogleFonts.inter(
                            fontSize: 12, fontWeight: FontWeight.w600,
                            color: active ? Colors.white : AppColors.textSecondary),
                      ),
                    );
                  }).toList(),
                ),
              ]),
            ),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Language',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 10),
                Row(
                  children: ['Hindi', 'English'].map((lang) {
                    final active = _language == lang;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(lang),
                        selected: active,
                        onSelected: (_) => setState(() => _language = lang),
                        selectedColor: _accent,
                        labelStyle: GoogleFonts.inter(
                            fontSize: 12, fontWeight: FontWeight.w600,
                            color: active ? Colors.white : AppColors.textSecondary),
                      ),
                    );
                  }).toList(),
                ),
              ]),
            ),
          ]),
          const SizedBox(height: 28),

          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _accent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _generate,
              icon: const Icon(Icons.auto_awesome_rounded, size: 20),
              label: Text('Generate Test',
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              _isPremium
                  ? 'Premium: $_limit AI tests every month'
                  : 'Free plan: $_limit AI tests/month',
              style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildGenerating() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(
            width: 56, height: 56,
            child: CircularProgressIndicator(strokeWidth: 3, color: _accent)),
        const SizedBox(height: 24),
        Text('AI is creating your test...',
            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text('$_count questions on ${_topicCtrl.text.trim()}',
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
      ]),
    );
  }

  // ── Quiz ────────────────────────────────────────────────────────────────

  Widget _buildQuiz() {
    final q = _questions[_qIndex];
    final options = Map<String, dynamic>.from(q['options'] ?? {});
    final answered = _selected != null;
    final correct = q['correct']?.toString();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Progress
          Row(children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (_qIndex + 1) / _questions.length,
                  minHeight: 6,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: const AlwaysStoppedAnimation(_accent),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text('${_qIndex + 1}/${_questions.length}',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
          ]),
          const SizedBox(height: 20),

          Text(q['question'] ?? '',
              style: GoogleFonts.poppins(
                  fontSize: 16, fontWeight: FontWeight.w600, height: 1.4)),
          const SizedBox(height: 18),

          ...['A', 'B', 'C', 'D'].where(options.containsKey).map((key) {
            final isSelected = _selected == key;
            final isCorrect = key == correct;
            Color border = Colors.grey.shade300;
            Color bg = Colors.white;
            if (answered) {
              if (isCorrect) {
                border = AppColors.success;
                bg = AppColors.success.withValues(alpha: 0.08);
              } else if (isSelected) {
                border = AppColors.error;
                bg = AppColors.error.withValues(alpha: 0.08);
              }
            } else if (isSelected) {
              border = _accent;
              bg = _accent.withValues(alpha: 0.06);
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: answered
                    ? null
                    : () => setState(() {
                          _selected = key;
                          _answers[_qIndex] = key;
                        }),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: border, width: answered && (isCorrect || isSelected) ? 2 : 1),
                  ),
                  child: Row(children: [
                    Container(
                      width: 28, height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: answered && isCorrect
                            ? AppColors.success
                            : answered && isSelected
                                ? AppColors.error
                                : _accent.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: answered && isCorrect
                          ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                          : answered && isSelected
                              ? const Icon(Icons.close_rounded, color: Colors.white, size: 16)
                              : Text(key,
                                  style: GoogleFonts.poppins(
                                      fontSize: 13, fontWeight: FontWeight.w600,
                                      color: _accent)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text(options[key]?.toString() ?? '',
                            style: GoogleFonts.inter(fontSize: 14, height: 1.3))),
                  ]),
                ),
              ),
            );
          }),

          // Explanation after answering
          if (answered && (q['explanation'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.success.withValues(alpha: 0.35)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.lightbulb_rounded, size: 16, color: AppColors.success),
                  const SizedBox(width: 6),
                  Text('Explanation',
                      style: GoogleFonts.poppins(
                          fontSize: 12, fontWeight: FontWeight.w700,
                          color: AppColors.success)),
                ]),
                const SizedBox(height: 6),
                Text(q['explanation'].toString(),
                    style: GoogleFonts.inter(
                        fontSize: 13, height: 1.4, color: AppColors.textPrimary)),
              ]),
            ),
          ],

          const SizedBox(height: 24),
          if (answered)
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _accent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  if (_qIndex < _questions.length - 1) {
                    setState(() {
                      _qIndex++;
                      _selected = _answers[_qIndex];
                    });
                  } else {
                    setState(() => _phase = 'done');
                    _recordAttempt();
                  }
                },
                child: Text(
                    _qIndex < _questions.length - 1 ? 'Next Question' : 'See Result',
                    style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
        ]),
      ),
    );
  }

  // ── Result ──────────────────────────────────────────────────────────────

  Widget _buildResult() {
    final total = _questions.length;
    final score = _score;
    final pct = total > 0 ? (score / total * 100).round() : 0;
    final good = pct >= 60;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(children: [
          const SizedBox(height: 20),
          Container(
            width: 110, height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (good ? AppColors.success : AppColors.warning)
                  .withValues(alpha: 0.12),
            ),
            child: Center(
              child: Text('$pct%',
                  style: GoogleFonts.poppins(
                      fontSize: 30, fontWeight: FontWeight.bold,
                      color: good ? AppColors.success : AppColors.warning)),
            ),
          ),
          const SizedBox(height: 16),
          Text(good ? 'Shabash! 🎉' : 'Keep Practicing 💪',
              style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text('$score / $total correct • $_subject — ${_topicCtrl.text.trim()}',
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 28),

          // Review list
          ...List.generate(total, (i) {
            final q = _questions[i];
            final my = _answers[i];
            final ok = my == q['correct'];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                dense: true,
                leading: Icon(
                  ok ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  color: ok ? AppColors.success : AppColors.error,
                ),
                title: Text('Q${i + 1}. ${q['question']}',
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(fontSize: 12.5)),
                subtitle: Text(
                    ok ? 'Correct' : 'Your: ${my ?? "—"} • Correct: ${q['correct']}',
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        color: ok ? AppColors.success : AppColors.error)),
              ),
            );
          }),
          const SizedBox(height: 20),

          Row(children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(context),
                child: Text('Done', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: _accent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => setState(() {
                  _phase = 'form';
                  _questions = [];
                  _recorded = false;
                }),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text('New Test',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}
