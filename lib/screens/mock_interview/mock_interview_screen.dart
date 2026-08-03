import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../services/api_service.dart';

/// AI Mock Interview — text-based Q&A (like Unstop's Mock Interviews).
/// Phases: setup (pick a role) → interview (answer questions one by one,
/// AI feedback after each) → result (overall score + summary).
class MockInterviewScreen extends StatefulWidget {
  const MockInterviewScreen({super.key});

  @override
  State<MockInterviewScreen> createState() => _MockInterviewScreenState();
}

class _MockInterviewScreenState extends State<MockInterviewScreen> {
  String _phase = 'setup';
  List<dynamic> _roles = [];
  String? _selectedRole;
  bool _loadingRoles = true;
  bool _starting = false;

  int? _sessionId;
  List<Map<String, dynamic>> _questions = [];
  int _currentIndex = 0;
  final _answerCtrl = TextEditingController();
  bool _submitting = false;
  Map<String, dynamic>? _lastFeedback;

  Map<String, dynamic>? _result;
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    _loadRoles();
  }

  @override
  void dispose() {
    _answerCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRoles() async {
    try {
      _roles = await ApiService.getMockInterviewRoles();
    } catch (_) {}
    if (mounted) setState(() => _loadingRoles = false);
  }

  Future<void> _start() async {
    if (_selectedRole == null) return;
    setState(() => _starting = true);
    try {
      final data = await ApiService.startMockInterview(_selectedRole!);
      if (!mounted) return;
      setState(() {
        _sessionId = data['session_id'] as int;
        _questions = List<Map<String, dynamic>>.from(data['questions'] as List);
        _currentIndex = 0;
        _phase = 'interview';
        _starting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _starting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _submitAnswer() async {
    if (_answerCtrl.text.trim().isEmpty) return;
    setState(() => _submitting = true);
    try {
      final q = _questions[_currentIndex];
      final feedback = await ApiService.submitMockInterviewAnswer(
          _sessionId!, q['id'] as int, _answerCtrl.text.trim());
      if (!mounted) return;
      setState(() {
        _lastFeedback = feedback;
        _submitting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _next() async {
    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
        _answerCtrl.clear();
        _lastFeedback = null;
      });
    } else {
      setState(() => _finishing = true);
      try {
        final result = await ApiService.finishMockInterview(_sessionId!);
        if (!mounted) return;
        setState(() {
          _result = result;
          _phase = 'result';
          _finishing = false;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() => _finishing = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  void _restart() {
    setState(() {
      _phase = 'setup';
      _selectedRole = null;
      _sessionId = null;
      _questions = [];
      _currentIndex = 0;
      _lastFeedback = null;
      _result = null;
      _answerCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text('AI Mock Interview',
            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: switch (_phase) {
            'interview' => _buildInterview(),
            'result' => _buildResult(),
            _ => _buildSetup(),
          },
        ),
      ),
    );
  }

  Widget _buildSetup() {
    if (_loadingRoles) return const Center(child: CircularProgressIndicator());
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Pick a role to interview for',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 19)),
        const SizedBox(height: 6),
        Text('AI will ask 5 technical + behavioral questions and give you feedback after each.',
            style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 13)),
        const SizedBox(height: 20),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _roles.map((r) => ChoiceChip(
            label: Text(r.toString()),
            selected: _selectedRole == r,
            onSelected: (_) => setState(() => _selectedRole = r.toString()),
          )).toList(),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: (_selectedRole == null || _starting) ? null : _start,
            style: FilledButton.styleFrom(backgroundColor: AppColors.accent, padding: const EdgeInsets.symmetric(vertical: 14)),
            child: _starting
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text('Start Interview', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ),
      ]),
    );
  }

  Widget _buildInterview() {
    final q = _questions[_currentIndex];
    final hasFeedback = _lastFeedback != null;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        LinearProgressIndicator(value: (_currentIndex + 1) / _questions.length,
            backgroundColor: Colors.grey.withValues(alpha: 0.15), color: AppColors.accent),
        const SizedBox(height: 8),
        Text('Question ${_currentIndex + 1} of ${_questions.length}',
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 16),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(q['question'] ?? '', style: GoogleFonts.poppins(fontSize: 15.5, fontWeight: FontWeight.w600, height: 1.4)),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _answerCtrl,
          maxLines: 6,
          enabled: !hasFeedback,
          decoration: InputDecoration(
            hintText: 'Type your answer here...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 14),
        if (!hasFeedback)
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _submitting ? null : _submitAnswer,
              style: FilledButton.styleFrom(backgroundColor: AppColors.accent, padding: const EdgeInsets.symmetric(vertical: 13)),
              child: _submitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text('Submit Answer', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            ),
          ),
        if (hasFeedback) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.smart_toy_rounded, color: AppColors.accent, size: 18),
                const SizedBox(width: 8),
                Text('${_lastFeedback!['score'] ?? 0}/10',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: AppColors.accent)),
              ]),
              const SizedBox(height: 8),
              Text(_lastFeedback!['feedback'] ?? '', style: GoogleFonts.inter(fontSize: 13, height: 1.4)),
            ]),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _finishing ? null : _next,
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 13)),
              child: _finishing
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(_currentIndex < _questions.length - 1 ? 'Next Question' : 'Finish Interview',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _buildResult() {
    final score = _result?['overall_score'] ?? 0;
    final color = score >= 70 ? AppColors.success : score >= 40 ? Colors.orange : AppColors.error;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        Container(
          width: 120, height: 120,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color, width: 5), color: color.withValues(alpha: 0.08)),
          child: Center(
            child: Text('$score%', style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.bold, color: color)),
          ),
        ),
        const SizedBox(height: 16),
        Text('Interview Complete', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18)),
        Text(_result?['role'] ?? '', style: GoogleFonts.inter(color: AppColors.textSecondary)),
        const SizedBox(height: 20),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.smart_toy_rounded, color: AppColors.accent),
                const SizedBox(width: 8),
                Text('AI Feedback', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 10),
              Text(_result?['overall_feedback'] ?? '', style: GoogleFonts.inter(fontSize: 13.5, height: 1.5)),
            ]),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _restart,
            child: Text('Try Another Interview', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ),
      ]),
    );
  }
}
