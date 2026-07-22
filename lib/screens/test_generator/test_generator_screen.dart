// ignore_for_file: deprecated_member_use
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../constants/app_colors.dart';
import '../../constants/api_constants.dart';
import '../../l10n/app_localizations.dart';
import '../../models/batch_model.dart';
import '../../models/test_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/institute_provider.dart';
import '../../providers/test_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/custom_button_widget.dart';

class TestGeneratorScreen extends StatefulWidget {
  const TestGeneratorScreen({super.key});

  @override
  State<TestGeneratorScreen> createState() => _TestGeneratorScreenState();
}

// Entry point — wraps with tabs
class _TestGeneratorScreenState extends State<TestGeneratorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  Map<String, dynamic>? _usage; // {used, limit, remaining, allowed}

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _loadUsage();
  }

  Future<void> _loadUsage() async {
    final instituteId = context.read<AuthProvider>().instituteId;
    if (instituteId == null) return;
    try {
      final usage = await ApiService.getGenerationUsage(instituteId);
      if (mounted) setState(() => _usage = usage);
    } catch (_) {}
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final aiLimit = (_usage?['limit'] as num?)?.toInt() ?? -1; // -1 unlimited
    final used = (_usage?['used'] as num?)?.toInt() ?? 0;
    final usageText = aiLimit == -1
        ? 'Unlimited AI tests'
        : 'AI tests: $used / $aiLimit this month';

    return Column(
      children: [
        if (_usage != null)
          Container(
            padding: const EdgeInsets.all(8),
            color: AppColors.accent.withValues(alpha: 0.08),
            child: Row(
              children: [
                Expanded(child: Text(usageText, style: GoogleFonts.inter(fontSize: 12, color: Colors.white70))),
                if (aiLimit != -1 && used >= aiLimit * 0.8)
                  TextButton(
                    onPressed: () => context.push('/plans'),
                    child: const Text('Upgrade for more', style: TextStyle(fontSize: 11)),
                  ),
              ],
            ),
          ),
        Container(
          color: AppColors.background,
          child: TabBar(
            controller: _tabs,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(icon: const Icon(Icons.auto_awesome_rounded, size: 18), text: l10n.testGenTabGenerate),
              const Tab(icon: Icon(Icons.picture_as_pdf_rounded, size: 18), text: 'PDF Upload'),
              const Tab(icon: Icon(Icons.flash_on_rounded, size: 18), text: 'Templates'),
              Tab(icon: const Icon(Icons.list_alt_rounded, size: 18), text: l10n.testGenTabMyTests),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: const [
              _GenerateTab(),
              _PdfUploadTab(),
              _TemplatesTab(),
              _MyTestsTab(),
            ],
          ),
        ),
      ],
    );
  }
}

class _GenerateTab extends StatefulWidget {
  const _GenerateTab();

  @override
  State<_GenerateTab> createState() => _GenerateTabState();
}

class _GenerateTabState extends State<_GenerateTab> {

  final _titleCtrl = TextEditingController();
  final _topicCtrl = TextEditingController();
  final _customInstructionsCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  String _subject = 'Mathematics';
  String _difficulty = 'Medium';
  String _examType = 'SSC GD Constable';

  String _language = 'Hindi';
  int _count = 20;
  int? _batchId;
  List<Batch> _batches = [];
  List<Map<String, dynamic>> _subjects = [];
  List<Map<String, dynamic>> _examPatterns = [];

  @override
  void initState() {
    super.initState();
    _loadBatches();
    _loadConfig();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBatches() async {
    final auth = context.read<AuthProvider>();
    if (auth.instituteId != null) {
      await context.read<InstituteProvider>().ensureBatches(auth.instituteId!);
      if (!mounted) return;
      setState(() {
        _batches = context.read<InstituteProvider>().batches;
      });
    }
  }

  Future<void> _loadConfig() async {
    final auth = context.read<AuthProvider>();
    if (auth.instituteId == null) return;
    try {
      final res = await ApiService.getTestConfig(auth.instituteId!);
      if (!mounted) return;
      final subjects = List<Map<String, dynamic>>.from(res['subjects'] ?? []);
      final patterns = List<Map<String, dynamic>>.from(res['exam_patterns'] ?? []);
      setState(() {
        _subjects = subjects;
        _examPatterns = patterns;
        if (subjects.isNotEmpty && !subjects.any((s) => s['value'] == _subject)) {
          _subject = subjects.first['value'] ?? 'Mathematics';
        }
        if (patterns.isNotEmpty && !patterns.any((p) => p['value'] == _examType)) {
          _examType = patterns.first['value'] ?? 'General/Custom';
        }
      });
    } catch (_) {}
  }

  Future<void> _generate() async {
    final auth = context.read<AuthProvider>();
    final provider = context.read<TestProvider>();
    final ok = await provider.generateTest({
      'institute_id': auth.instituteId,
      'batch_id': _batchId,
      'title': _titleCtrl.text.trim().isEmpty
          ? '$_subject - $_examType Test'
          : _titleCtrl.text.trim(),
      'subject': _subject,
      'topic': _topicCtrl.text.trim(),
      'difficulty': _difficulty,
      'exam_type': _examType,
      'language': _language,
      'count': _count,
      'duration_mins': (_count * 1.5).round(),
      'custom_instructions': _customInstructionsCtrl.text.trim(),
    });
    if (!mounted) return;
    if (ok) {
      // Auto-scroll to preview on mobile
      await Future.delayed(const Duration(milliseconds: 200));
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOut,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(provider.error ?? 'Generation failed'),
        backgroundColor: Colors.red,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 900;
    if (isMobile) {
      return SingleChildScrollView(
        controller: _scrollCtrl,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _ConfigPanel(
              titleCtrl: _titleCtrl,
              topicCtrl: _topicCtrl,
              customInstructionsCtrl: _customInstructionsCtrl,
              subject: _subject,
              difficulty: _difficulty,
              examType: _examType,
              language: _language,
              count: _count,
              batchId: _batchId,
              batches: _batches,
              subjects: _subjects,
              examPatterns: _examPatterns,
              onSubject: (v) => setState(() => _subject = v),
              onDifficulty: (v) => setState(() => _difficulty = v),
              onExamType: (v) => setState(() => _examType = v),
              onLanguage: (v) => setState(() => _language = v),
              onCount: (v) => setState(() => _count = v),
              onBatch: (v) => setState(() => _batchId = v),
              onGenerate: _generate,
            ),
            const SizedBox(height: 20),
            const _PreviewPanel(),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 380,
            child: SingleChildScrollView(
              child: _ConfigPanel(
                titleCtrl: _titleCtrl,
                topicCtrl: _topicCtrl,
                customInstructionsCtrl: _customInstructionsCtrl,
                subject: _subject,
                difficulty: _difficulty,
                examType: _examType,
                language: _language,
                count: _count,
                batchId: _batchId,
                batches: _batches,
                subjects: _subjects,
                examPatterns: _examPatterns,
                onSubject: (v) => setState(() => _subject = v),
                onDifficulty: (v) => setState(() => _difficulty = v),
                onExamType: (v) => setState(() => _examType = v),
                onLanguage: (v) => setState(() => _language = v),
                onCount: (v) => setState(() => _count = v),
                onBatch: (v) => setState(() => _batchId = v),
                onGenerate: _generate,
              ),
            ),
          ),
          const SizedBox(width: 24),
          const Expanded(
            child: SingleChildScrollView(
              child: _PreviewPanel(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfigPanel extends StatelessWidget {
  final TextEditingController titleCtrl, topicCtrl, customInstructionsCtrl;
  final String subject, difficulty, examType, language;
  final int count;
  final int? batchId;
  final List<Batch> batches;
  final List<Map<String, dynamic>> subjects;
  final List<Map<String, dynamic>> examPatterns;
  final ValueChanged<String> onSubject, onDifficulty, onExamType, onLanguage;
  final ValueChanged<int> onCount;
  final ValueChanged<int?> onBatch;
  final VoidCallback onGenerate;

  const _ConfigPanel({
    required this.titleCtrl,
    required this.topicCtrl,
    required this.customInstructionsCtrl,
    required this.subject,
    required this.difficulty,
    required this.examType,
    required this.language,
    required this.count,
    required this.batchId,
    required this.batches,
    required this.subjects,
    required this.examPatterns,
    required this.onSubject,
    required this.onDifficulty,
    required this.onExamType,
    required this.onLanguage,
    required this.onCount,
    required this.onBatch,
    required this.onGenerate,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TestProvider>();

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primaryLight],
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome_rounded,
                    color: Colors.white, size: 24),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(AppLocalizations.of(context)!.testGenAITitle,
                        style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                    Text(AppLocalizations.of(context)!.testGenAIPowered,
                        style: GoogleFonts.inter(
                            color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.testGenTestTitle,
                    hintText: AppLocalizations.of(context)!.testGenTestTitleHint,
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: subject,
                  decoration: InputDecoration(labelText: AppLocalizations.of(context)!.testGenSubject),
                  items: (subjects.isEmpty
                      ? [
                          {'label': 'Mathematics', 'value': 'Mathematics', 'icon': '🔢'},
                          {'label': 'General Knowledge', 'value': 'General Knowledge', 'icon': '🌍'},
                          {'label': 'Reasoning', 'value': 'Reasoning', 'icon': '🧠'},
                          {'label': 'English', 'value': 'English', 'icon': '📝'},
                          {'label': 'Science', 'value': 'Science', 'icon': '🔬'},
                          {'label': 'Hindi', 'value': 'Hindi', 'icon': '🇮🇳'},
                          {'label': 'Mixed', 'value': 'Mixed', 'icon': '📚'},
                        ]
                      : subjects)
                      .map((s) => DropdownMenuItem(
                            value: (s['value'] ?? s['label']).toString(),
                            child: Text('${s['icon'] ?? ''} ${s['label']}'.trim()),
                          ))
                      .toList(),
                  onChanged: (v) => v != null ? onSubject(v) : null,
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: topicCtrl,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.testGenTopic,
                    hintText: AppLocalizations.of(context)!.testGenTopicHint,
                    helperText: AppLocalizations.of(context)!.testGenTopicHelper,
                  ),
                ),
                const SizedBox(height: 14),
                _SectionLabel(AppLocalizations.of(context)!.testGenDifficulty),
                const SizedBox(height: 8),
                _SegmentedRow(
                  options: const ['Easy', 'Medium', 'Hard', 'Mixed'],
                  colors: const [
                    AppColors.success,
                    AppColors.warning,
                    AppColors.error,
                    AppColors.primaryLight
                  ],
                  selected: difficulty,
                  onSelected: onDifficulty,
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: examType,
                  decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.testGenExamPattern),
                  items: (examPatterns.isEmpty
                      ? [
                          {'label': 'SSC GD Constable', 'value': 'SSC GD Constable'},
                          {'label': 'SSC CGL', 'value': 'SSC CGL'},
                          {'label': 'SSC CHSL', 'value': 'SSC CHSL'},
                          {'label': 'Army Agniveer', 'value': 'Army Agniveer'},
                          {'label': 'Railway NTPC', 'value': 'Railway NTPC'},
                          {'label': 'Railway Group D', 'value': 'Railway Group D'},
                          {'label': 'UPSC Prelims', 'value': 'UPSC Prelims'},
                          {'label': 'MPPSC', 'value': 'MPPSC'},
                          {'label': 'General/Custom', 'value': 'General/Custom'},
                        ]
                      : examPatterns)
                      .map((e) => DropdownMenuItem(
                          value: (e['value'] ?? e['label']).toString(),
                          child: Text((e['label'] ?? '').toString())))
                      .toList(),
                  onChanged: (v) => v != null ? onExamType(v) : null,
                ),
                const SizedBox(height: 14),
                _SectionLabel(AppLocalizations.of(context)!.testGenQuestionCount),
                const SizedBox(height: 8),
                _CountSelector(
                  options: const [10, 20, 30, 50, 100],
                  selected: count,
                  onSelected: onCount,
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: language,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.testGenLanguage,
                    prefixIcon: const Icon(Icons.language_rounded),
                  ),
                  items: [
                    DropdownMenuItem(
                        value: 'Hindi',
                        child: Text(AppLocalizations.of(context)!.testGenLangHindi)),
                    DropdownMenuItem(
                        value: 'English',
                        child: Text(AppLocalizations.of(context)!.testGenLangEnglish)),
                    DropdownMenuItem(
                        value: 'Both',
                        child: Text(AppLocalizations.of(context)!.testGenLangBoth)),
                  ],
                  onChanged: (v) => v != null ? onLanguage(v) : null,
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<int?>(
                  value: batchId,
                  decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.testGenBatch),
                  items: [
                    DropdownMenuItem(
                        value: null,
                        child: Text(AppLocalizations.of(context)!.testGenNoBatch)),
                    ...batches.map((b) => DropdownMenuItem(
                        value: b.id, child: Text(b.name))),
                  ],
                  onChanged: onBatch,
                ),
                const SizedBox(height: 14),
                // ── Custom Instructions (Expert Mode) ──
                TextField(
                  controller: customInstructionsCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: '🎯 Expert Instructions (Optional)',
                    hintText: 'e.g. "Focus on Bihar GK" or "More numerical, less theory"',
                    helperText: 'AI will follow these special instructions',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    filled: true,
                    fillColor: AppColors.accent.withValues(alpha: 0.04),
                    prefixIcon: const Icon(Icons.psychology_rounded, color: AppColors.accent),
                  ),
                ),
                const SizedBox(height: 20),
                OrangeButton(
                  label: provider.isGenerating
                      ? provider.generationStatus
                      : '🤖  ${AppLocalizations.of(context)!.testGenGenerateBtn}',
                  onPressed: provider.isGenerating ? null : onGenerate,
                  loading: provider.isGenerating,
                ),
                if (provider.error != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(provider.error!,
                        style: const TextStyle(color: AppColors.error)),
                  ),
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: GoogleFonts.inter(
            fontSize: 12,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500));
  }
}

class _SegmentedRow extends StatelessWidget {
  final List<String> options;
  final List<Color> colors;
  final String selected;
  final ValueChanged<String> onSelected;

  const _SegmentedRow({
    required this.options,
    required this.colors,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: options.asMap().entries.map((e) {
        final i = e.key;
        final opt = e.value;
        final active = opt == selected;
        final color = colors[i];
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < options.length - 1 ? 6 : 0),
            child: InkWell(
              onTap: () => onSelected(opt),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: active ? color : color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withValues(alpha: 0.4)),
                ),
                child: Center(
                  child: Text(opt,
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          color: active ? Colors.white : color,
                          fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _CountSelector extends StatelessWidget {
  final List<int> options;
  final int selected;
  final ValueChanged<int> onSelected;

  const _CountSelector(
      {required this.options,
      required this.selected,
      required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: options.map((n) {
        final active = n == selected;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 6),
            child: InkWell(
              onTap: () => onSelected(n),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: active ? AppColors.primary : AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: active
                          ? AppColors.primary
                          : Colors.grey.shade300),
                ),
                child: Center(
                  child: Text('$n',
                      style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: active ? Colors.white : AppColors.textPrimary,
                          fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _PreviewPanel extends StatelessWidget {
  const _PreviewPanel();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TestProvider>();

    if (provider.isGenerating) {
      return Card(
        child: SizedBox(
          height: 500,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: AppColors.accent),
                const SizedBox(height: 20),
                Text(AppLocalizations.of(context)!.testGenGenerating,
                    style: GoogleFonts.poppins(
                        fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text(provider.generationStatus,
                    style: GoogleFonts.inter(
                        color: AppColors.textSecondary)),
              ],
            ),
          ),
        ),
      );
    }

    if (provider.currentTest == null) {
      return Card(
        child: SizedBox(
          height: 500,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.auto_awesome_rounded,
                    size: 72, color: AppColors.textSecondary),
                const SizedBox(height: 16),
                Text(AppLocalizations.of(context)!.testGenEmptyTitle,
                    style: GoogleFonts.poppins(
                        fontSize: 16, fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                Text(AppLocalizations.of(context)!.testGenEmptySubtitle,
                    style: GoogleFonts.inter(
                        color: AppColors.textSecondary)),
              ],
            ),
          ),
        ),
      );
    }

    final test = provider.currentTest!;
    return Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TestHeader(test: test),
          _QualityBar(test: test),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: test.questions.length,
            itemBuilder: (_, i) =>
                _QuestionCard(q: test.questions[i], index: i),
          ),
          _ActionBar(test: test),
        ],
      ),
    );
  }
}

// ── Quality Bar: topic distribution + difficulty mix + quality score ─────────

class _QualityBar extends StatelessWidget {
  final AltroTest test;
  const _QualityBar({required this.test});

  @override
  Widget build(BuildContext context) {
    final diffDist = test.difficultyDistribution;
    final topicDist = test.topicDistribution;
    final qScore = test.qualityScore;
    final scoreColor = qScore >= 80
        ? AppColors.success
        : qScore >= 60
            ? Colors.orange
            : AppColors.error;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppColors.background,
      child: Column(
        children: [
          // Quality Score + Difficulty Mix
          Row(
            children: [
              // Quality Score
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: scoreColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: scoreColor.withValues(alpha: 0.3)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.verified_rounded, color: scoreColor, size: 14),
                  const SizedBox(width: 4),
                  Text('Quality: $qScore%',
                      style: GoogleFonts.inter(
                          fontSize: 11, fontWeight: FontWeight.w700, color: scoreColor)),
                ]),
              ),
              const SizedBox(width: 8),
              // Difficulty chips
              ...diffDist.entries.map((e) {
                final color = e.key == 'Easy' || e.key == 'easy'
                    ? AppColors.success
                    : e.key == 'Hard' || e.key == 'hard'
                        ? AppColors.error
                        : Colors.orange;
                return Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('${e.key}: ${e.value}',
                        style: GoogleFonts.inter(
                            fontSize: 10, color: color, fontWeight: FontWeight.w600)),
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 8),
          // Topic distribution
          if (topicDist.isNotEmpty)
            SizedBox(
              height: 22,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: topicDist.entries.map((e) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${e.key.replaceAll('_', ' ')} (${e.value})',
                        style: GoogleFonts.inter(
                            fontSize: 10, color: AppColors.primary,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _TestHeader extends StatelessWidget {
  final AltroTest test;
  const _TestHeader({required this.test});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.shield_rounded, color: AppColors.accent, size: 16),
                  const SizedBox(width: 6),
                  Text('EXPERT REVIEW MODE',
                      style: GoogleFonts.inter(
                          fontSize: 10, fontWeight: FontWeight.w700,
                          color: AppColors.accent, letterSpacing: 0.8)),
                ]),
                const SizedBox(height: 6),
                Text(test.title,
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text(
                    '${test.subject} • ${test.difficulty} • ${test.examType}',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          _badge('${test.questions.length} Qs', AppColors.primary),
          const SizedBox(width: 8),
          _badge('${test.durationMins} min', AppColors.accent),
        ],
      ),
    );
  }

  Widget _badge(String t, Color c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(t,
          style: GoogleFonts.inter(
              fontSize: 11, color: c, fontWeight: FontWeight.w600)),
    );
  }
}

class _QuestionCard extends StatefulWidget {
  final Question q;
  final int index;
  const _QuestionCard({required this.q, required this.index});

  @override
  State<_QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<_QuestionCard> {
  bool _showExplanation = false;

  Color get _qualityColor {
    final s = widget.q.qualityScore;
    return s >= 80 ? AppColors.success : s >= 60 ? Colors.orange : AppColors.error;
  }

  void _editQuestion() {
    final provider = context.read<TestProvider>();
    final q = widget.q;
    final qCtrl = TextEditingController(text: q.question);
    final aCtrl = TextEditingController(text: q.options['A'] ?? '');
    final bCtrl = TextEditingController(text: q.options['B'] ?? '');
    final cCtrl = TextEditingController(text: q.options['C'] ?? '');
    final dCtrl = TextEditingController(text: q.options['D'] ?? '');
    final expCtrl = TextEditingController(text: q.explanation);
    String correct = q.correct;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Row(children: [
            const Icon(Icons.edit_rounded, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Text('Edit Q${widget.index + 1}',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ]),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: qCtrl,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Question'),
              ),
              const SizedBox(height: 10),
              TextField(controller: aCtrl, decoration: const InputDecoration(labelText: 'Option A')),
              const SizedBox(height: 6),
              TextField(controller: bCtrl, decoration: const InputDecoration(labelText: 'Option B')),
              const SizedBox(height: 6),
              TextField(controller: cCtrl, decoration: const InputDecoration(labelText: 'Option C')),
              const SizedBox(height: 6),
              TextField(controller: dCtrl, decoration: const InputDecoration(labelText: 'Option D')),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: correct,
                decoration: const InputDecoration(labelText: 'Correct Answer'),
                items: ['A', 'B', 'C', 'D']
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: (v) => setS(() => correct = v!),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: expCtrl,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Explanation'),
              ),
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () {
                provider.editQuestion(widget.index, q.copyWith(
                  question: qCtrl.text,
                  options: {'A': aCtrl.text, 'B': bCtrl.text, 'C': cCtrl.text, 'D': dCtrl.text},
                  correct: correct,
                  explanation: expCtrl.text,
                ));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Question updated!'),
                  behavior: SnackBarBehavior.floating,
                ));
              },
              icon: const Icon(Icons.save_rounded, size: 16),
              label: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteQuestion() {
    final provider = context.read<TestProvider>();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Question?'),
        content: Text('Remove Q${widget.index + 1} from this test?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              provider.deleteQuestion(widget.index);
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _regenerateQuestion() async {
    final provider = context.read<TestProvider>();
    final ok = await provider.regenerateQuestion(widget.index);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? 'Question regenerated!' : 'Regeneration failed'),
      behavior: SnackBarBehavior.floating,
      backgroundColor: ok ? AppColors.success : AppColors.error,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TestProvider>();
    final isRegenerating = provider.regeneratingIndex == widget.index;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      child: isRegenerating
          ? Container(
              padding: const EdgeInsets.all(32),
              child: const Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  CircularProgressIndicator(color: AppColors.accent),
                  SizedBox(height: 12),
                  Text('Regenerating question...'),
                ]),
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row: Q number + difficulty + quality + actions
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('Q${widget.index + 1}',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(widget.q.difficulty,
                          style: GoogleFonts.inter(fontSize: 10, color: AppColors.accent)),
                    ),
                    const SizedBox(width: 6),
                    // Quality badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _qualityColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.verified_rounded, color: _qualityColor, size: 10),
                        const SizedBox(width: 2),
                        Text('${widget.q.qualityScore}',
                            style: GoogleFonts.inter(
                                fontSize: 10, color: _qualityColor, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                    if (widget.q.topic.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(widget.q.topic.replaceAll('_', ' '),
                              style: GoogleFonts.inter(fontSize: 9, color: AppColors.primary),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                    const Spacer(),
                    // Action buttons
                    _MiniBtn(Icons.edit_rounded, AppColors.primary, _editQuestion, 'Edit'),
                    _MiniBtn(Icons.refresh_rounded, AppColors.accent, _regenerateQuestion, 'Regen'),
                    _MiniBtn(Icons.delete_outline_rounded, AppColors.error, _deleteQuestion, 'Delete'),
                  ]),
                  const SizedBox(height: 10),
                  Text(widget.q.question,
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  ...widget.q.options.entries.map((e) {
                    final isCorrect = e.key == widget.q.correct;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isCorrect
                            ? AppColors.success.withValues(alpha: 0.1)
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isCorrect ? AppColors.success : Colors.grey.shade200,
                          width: isCorrect ? 1.5 : 1,
                        ),
                      ),
                      child: Row(children: [
                        Text('${e.key}.',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isCorrect ? AppColors.success : AppColors.textSecondary)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(e.value,
                              style: TextStyle(
                                  color: isCorrect ? AppColors.success : AppColors.textPrimary,
                                  fontWeight: isCorrect ? FontWeight.w600 : FontWeight.normal)),
                        ),
                        if (isCorrect)
                          const Icon(Icons.check_circle, color: AppColors.success, size: 16),
                      ]),
                    );
                  }),
                  if (widget.q.explanation.isNotEmpty) ...[
                    InkWell(
                      onTap: () => setState(() => _showExplanation = !_showExplanation),
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(children: [
                          Icon(
                              _showExplanation ? Icons.expand_less : Icons.expand_more,
                              size: 16, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text('Explanation',
                              style: GoogleFonts.inter(
                                  fontSize: 12, color: AppColors.textSecondary)),
                        ]),
                      ),
                    ),
                    if (_showExplanation) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('💡 ${widget.q.explanation}',
                            style: GoogleFonts.inter(fontSize: 12)),
                      ),
                    ],
                  ],
                ],
              ),
            ),
    );
  }
}

/// Tiny icon button for question actions
class _MiniBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String tooltip;
  const _MiniBtn(this.icon, this.color, this.onTap, this.tooltip);

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  final AltroTest test;
  const _ActionBar({required this.test});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, -2)),
        ],
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          OutlinedButton.icon(
            onPressed: () => context.read<TestProvider>().clearCurrent(),
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Regenerate All'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white),
            onPressed: () async {
              final provider = context.read<TestProvider>();
              final ok = await provider.saveQuestions();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(ok ? 'Questions saved!' : 'Save failed'),
                backgroundColor: ok ? AppColors.success : AppColors.error,
                behavior: SnackBarBehavior.floating,
              ));
            },
            icon: const Icon(Icons.save_rounded, size: 16),
            label: const Text('Save Changes'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white),
            onPressed: () => _showSendDialog(context, test),
            icon: const Icon(Icons.send_rounded, size: 16),
            label: const Text('Approve & Send'),
          ),
        ],
      ),
    );
  }

  void _showSendDialog(BuildContext context, AltroTest test) {
    final testLink = 'https://coachingclub-bba5c.web.app/test/${test.id}';
    final message = '*${test.title}*\n\n'
        'Subject: ${test.subject}\n'
        'Questions: ${test.questions.length}\n'
        'Duration: ${test.durationMins} min\n\n'
        'Attempt here:\n$testLink';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Share Test on WhatsApp'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Share "${test.title}" with students?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(testLink,
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.primary)),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366)),
            onPressed: () async {
              Navigator.pop(context);
              final encoded = Uri.encodeComponent(message);
              final waUrl = Uri.parse('https://wa.me/?text=$encoded');
              if (await canLaunchUrl(waUrl)) {
                await launchUrl(waUrl, mode: LaunchMode.externalApplication);
              }
            },
            icon: const Icon(Icons.chat_rounded, size: 16, color: Colors.white),
            label: const Text('Open WhatsApp', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ─── My Tests Tab ────────────────────────────────────────────────────────────

class _MyTestsTab extends StatefulWidget {
  const _MyTestsTab();
  @override
  State<_MyTestsTab> createState() => _MyTestsTabState();
}

class _MyTestsTabState extends State<_MyTestsTab> {
  List<Map<String, dynamic>> _tests = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final provider = context.read<TestProvider>();
    _tests = provider.testRows;
    _loading = !provider.testsLoaded;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  String? _formatDate(dynamic raw) {
    if (raw == null) return null;
    final dt = DateTime.tryParse(raw.toString());
    if (dt == null) return null;
    return DateFormat('d MMM yyyy, h:mm a').format(dt.toLocal());
  }

  Future<void> _load({bool force = false}) async {
    final auth = context.read<AuthProvider>();
    if (auth.instituteId == null) return;
    final provider = context.read<TestProvider>();
    if (force) setState(() => _loading = true);
    try {
      await provider.ensureTests(auth.instituteId!, force: force);
      if (!mounted) return;
      setState(() => _tests = provider.testRows);
    } catch (_) {}
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _togglePublish(Map<String, dynamic> test) async {
    final isPublished = test['is_published'] == true;
    try {
      await ApiService.publishTest(test['id'], published: !isPublished);
      _load(force: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isPublished ? 'Test unpublished' : 'Test published! Students can now see it.'),
          backgroundColor: isPublished ? Colors.orange : AppColors.success,
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _delete(Map<String, dynamic> test) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Test?'),
        content: Text('Delete "${test['title']}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ApiService.deleteTest(test['id']);
    _load(force: true);
  }

  double _pctOf(Map<String, dynamic> r) {
    final score = (r['score'] ?? 0) as num;
    final total = (r['total'] ?? 0) as num;
    return total > 0 ? (score / total * 100) : 0.0;
  }

  String _nameOf(Map<String, dynamic> r) {
    final name = (r['student_name'] ?? '').toString().trim();
    if (name.isNotEmpty) return name;
    final phone = (r['student_phone_num'] ?? r['student_phone'] ?? '').toString().trim();
    return phone.isNotEmpty ? phone : 'Unknown';
  }

  void _showResults(Map<String, dynamic> test) async {
    final data = await ApiService.getTestResults(test['id']);
    final results = List<Map<String, dynamic>>.from(data['results'] ?? []);
    if (!mounted) return;

    // ── Admin analytics ──
    double avg = 0, topScore = 0;
    int passed = 0;
    String topper = '-';
    if (results.isNotEmpty) {
      double sum = 0;
      for (final r in results) {
        final p = _pctOf(r);
        sum += p;
        if (p >= 40) passed++;
        if (p > topScore) { topScore = p; topper = _nameOf(r); }
      }
      avg = sum / results.length;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        expand: false,
        builder: (_, ctrl) => Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Expanded(child: Text('Results: ${test['title']}',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15))),
                Text('${results.length} attempts', style: GoogleFonts.inter(color: AppColors.textSecondary)),
              ]),
            ),
            if (results.isNotEmpty)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(children: [
                  _AnalyticStat('Average', '${avg.toStringAsFixed(0)}%', AppColors.primary),
                  _AnalyticStat('Pass Rate', '${(passed / results.length * 100).toStringAsFixed(0)}%', AppColors.success),
                  _AnalyticStat('Topper', topper.length > 8 ? '${topper.substring(0, 8)}…' : topper, AppColors.accent),
                ]),
              ),
            const Divider(height: 1),
            if (results.isEmpty)
              const Expanded(child: Center(child: Text('No attempts yet')))
            else
              Expanded(
                child: ListView.builder(
                  controller: ctrl,
                  itemCount: results.length,
                  itemBuilder: (_, i) {
                    final r = results[i];
                    final pct = _pctOf(r);
                    final color = pct >= 70 ? AppColors.success : pct >= 40 ? Colors.orange : Colors.red;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: color.withValues(alpha: 0.15),
                        child: Text('${i + 1}', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                      ),
                      title: Text(_nameOf(r), style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
                      subtitle: Text('${r['score']}/${r['total']} correct', style: GoogleFonts.inter(fontSize: 12)),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                        child: Text('${pct.toStringAsFixed(0)}%',
                            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Open / preview a generated test with correct answers highlighted
  void _viewTest(Map<String, dynamic> test) {
    final raw = test['questions_json'];
    final questions = raw is List ? raw : <dynamic>[];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, ctrl) => Column(children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Expanded(child: Text(test['title'] ?? '',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15))),
              Text('${questions.length} Qs', style: GoogleFonts.inter(color: AppColors.textSecondary)),
            ]),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              controller: ctrl,
              padding: const EdgeInsets.all(16),
              itemCount: questions.length,
              itemBuilder: (_, i) {
                final q = Map<String, dynamic>.from(questions[i] as Map);
                final opts = Map<String, dynamic>.from(q['options'] ?? {});
                final correct = q['correct'];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Q${i + 1}. ${q['question'] ?? ''}',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 8),
                      ...opts.entries.map((e) {
                        final isCorrect = e.key == correct;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: isCorrect ? AppColors.success.withValues(alpha: 0.1) : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isCorrect ? AppColors.success : Colors.grey.shade200),
                          ),
                          child: Row(children: [
                            Text('${e.key}.', style: TextStyle(fontWeight: FontWeight.bold,
                                color: isCorrect ? AppColors.success : AppColors.textSecondary)),
                            const SizedBox(width: 8),
                            Expanded(child: Text('${e.value}', style: TextStyle(
                                color: isCorrect ? AppColors.success : AppColors.textPrimary))),
                            if (isCorrect) const Icon(Icons.check_circle, color: AppColors.success, size: 16),
                          ]),
                        );
                      }),
                      if ((q['explanation'] ?? '').toString().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(8)),
                          child: Text('💡 ${q['explanation']}', style: GoogleFonts.inter(fontSize: 12)),
                        ),
                      ],
                    ]),
                  ),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_tests.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.quiz_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 12),
          Text('No tests yet', style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 16)),
          const SizedBox(height: 6),
          Text('Generate your first test from the Generate tab', style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12)),
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _load(force: true),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _tests.length,
        itemBuilder: (_, i) {
          final t = _tests[i];
          final isPublished = t['is_published'] == true;
          final attempts = t['attempts'] ?? 0;
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text(t['title'] ?? '', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 8),
                  _StatusChip(isPublished),
                ]),
                const SizedBox(height: 6),
                Text('${t['subject']} • ${t['difficulty']} • ${t['exam_type'] ?? ''}',
                    style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12)),
                if (_formatDate(t['created_at']) != null) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.schedule_rounded, size: 12, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(_formatDate(t['created_at'])!,
                        style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 11)),
                  ]),
                ],
                const SizedBox(height: 10),
                Row(children: [
                  _InfoChip(Icons.quiz_rounded, '${(t['questions_json'] as List?)?.length ?? 0} Qs'),
                  const SizedBox(width: 8),
                  _InfoChip(Icons.people_rounded, '$attempts attempts'),
                  const Spacer(),
                  // View
                  IconButton(
                    icon: const Icon(Icons.visibility_outlined, size: 18, color: AppColors.primary),
                    onPressed: () => _viewTest(t),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    tooltip: 'View',
                  ),
                  const SizedBox(width: 4),
                  // Delete
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                    onPressed: () => _delete(t),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    tooltip: 'Delete',
                  ),
                ]),
                const SizedBox(height: 6),
                Row(children: [
                  // Results button
                  Expanded(child: OutlinedButton.icon(
                    onPressed: () => _showResults(t),
                    icon: const Icon(Icons.bar_chart_rounded, size: 14),
                    label: const Text('Results', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 6)),
                  )),
                  const SizedBox(width: 8),
                  // Publish toggle
                  Expanded(child: FilledButton.icon(
                    onPressed: () => _togglePublish(t),
                    icon: Icon(isPublished ? Icons.visibility_off_rounded : Icons.send_rounded, size: 14),
                    label: Text(isPublished ? 'Unpublish' : 'Publish', style: const TextStyle(fontSize: 12)),
                    style: FilledButton.styleFrom(
                      backgroundColor: isPublished ? Colors.orange : AppColors.success,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                    ),
                  )),
                ]),
              ]),
            ),
          );
        },
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final bool published;
  const _StatusChip(this.published);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: (published ? AppColors.success : Colors.orange).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: (published ? AppColors.success : Colors.orange).withValues(alpha: 0.3)),
      ),
      child: Text(published ? 'Published' : 'Draft',
          style: GoogleFonts.inter(
              color: published ? AppColors.success : Colors.orange,
              fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip(this.icon, this.label);
  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: AppColors.textSecondary),
      const SizedBox(width: 4),
      Text(label, style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12)),
    ]);
  }
}

class _AnalyticStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _AnalyticStat(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(children: [
        Text(value,
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: color),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        Text(label, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// PDF UPLOAD TAB
// ════════════════════════════════════════════════════════════════════════════

class _PdfUploadTab extends StatefulWidget {
  const _PdfUploadTab();

  @override
  State<_PdfUploadTab> createState() => _PdfUploadTabState();
}

class _PdfUploadTabState extends State<_PdfUploadTab> {
  bool _uploading = false;
  Map<String, dynamic>? _result;
  String? _error;
  List<Map<String, dynamic>> _questions = [];
  final Set<int> _selected = {};

  Future<void> _pickAndUpload() async {
    final auth = context.read<AuthProvider>();
    if (auth.instituteId == null) return;

    setState(() { _uploading = true; _error = null; _result = null; });
    try {
      // dart:html file picker
      final input = html.FileUploadInputElement()
        ..accept = '.pdf'
        ..multiple = false;
      input.click();
      await input.onChange.first;
      final file = input.files?.first;
      if (file == null) { setState(() => _uploading = false); return; }

      final reader = html.FileReader();
      reader.readAsArrayBuffer(file);
      await reader.onLoad.first;
      final bytes = (reader.result as ByteBuffer).asUint8List();

      final result = await ApiService.uploadPdfForTest(
          auth.instituteId!, bytes, file.name);

      final qs = List<Map<String, dynamic>>.from(result['questions'] ?? []);
      setState(() {
        _result = result;
        _questions = qs;
        _selected.addAll(List.generate(qs.length, (i) => i));
      });
    } catch (e) {
      setState(() => _error = e.toString());
    }
    setState(() => _uploading = false);
  }

  Future<void> _createTest() async {
    final auth = context.read<AuthProvider>();
    if (auth.instituteId == null || _result == null) return;
    final selected = _selected.map((i) => _questions[i]).toList();
    if (selected.isEmpty) return;

    final title = '${_result!['exam_type_detected'] ?? 'PDF'} Test — ${_result!['filename'] ?? ''}';
    try {
      final uri = Uri.parse(
        '${ApiConstants.baseUrl}/tests/from-pdf/${_result!['pdf_id']}'
        '?institute_id=${auth.instituteId}&title=${Uri.encodeComponent(title)}&duration_mins=30',
      );
      final token = await ApiService.getToken();
      final res = await http.post(uri,
        headers: {'Authorization': 'Bearer ${token ?? ""}', 'Content-Type': 'application/json'},
        body: jsonEncode(selected));
      ApiService.parsePublic(res);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Test created from PDF!'),
        backgroundColor: AppColors.success,
      ));
      setState(() { _result = null; _questions = []; _selected.clear(); });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_uploading) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 20),
          Text('Analyzing PDF...', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Stage 1: Detecting exam type\nStage 2: Extracting questions\nStage 3: Generating similar questions',
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
              textAlign: TextAlign.center),
        ]),
      );
    }

    if (_result != null && _questions.isNotEmpty) {
      return Column(children: [
        // Result header
        Container(
          padding: const EdgeInsets.all(16),
          color: AppColors.success.withValues(alpha: 0.06),
          child: Row(children: [
            const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('PDF Analyzed!',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14)),
              Text(
                '${_result!['exam_type_detected']} • ${_result!['subject_detected']} • '
                '${_result!['extracted_from_pdf']} extracted + ${_result!['ai_generated_similar']} AI generated',
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
            ])),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppColors.accent, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
              onPressed: _selected.isEmpty ? null : _createTest,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: Text('Create Test (${_selected.length}Q)'),
            ),
          ]),
        ),
        // Questions list with checkboxes
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _questions.length,
            itemBuilder: (_, i) {
              final q = _questions[i];
              final checked = _selected.contains(i);
              final isExtracted = q['source'] == 'extracted_from_pdf';
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: CheckboxListTile(
                  value: checked,
                  activeColor: AppColors.primary,
                  onChanged: (v) => setState(() {
                    if (v == true) { _selected.add(i); } else { _selected.remove(i); }
                  }),
                  title: Text(q['question'] ?? '',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (isExtracted ? AppColors.primary : AppColors.accent).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(isExtracted ? 'From PDF' : 'AI Generated',
                          style: TextStyle(fontSize: 10, color: isExtracted ? AppColors.primary : AppColors.accent)),
                    ),
                    const SizedBox(width: 8),
                    Text(q['topic'] ?? '', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
                  ]),
                ),
              );
            },
          ),
        ),
      ]);
    }

    // Upload screen
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('PDF to Test Series',
            style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        Text('Upload any exam paper, notes, or question bank PDF.\nAI will extract questions and generate similar ones.',
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
        const SizedBox(height: 24),

        if (_error != null)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              const Icon(Icons.error_outline, color: AppColors.error, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(_error!, style: GoogleFonts.inter(fontSize: 12, color: AppColors.error))),
            ]),
          ),

        // Upload zone
        GestureDetector(
          onTap: _pickAndUpload,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 48),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.03),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(children: [
              Icon(Icons.picture_as_pdf_rounded, size: 52, color: AppColors.primary.withValues(alpha: 0.7)),
              const SizedBox(height: 16),
              Text('Tap to upload PDF',
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.primary)),
              const SizedBox(height: 6),
              Text('Previous year papers • Notes • Question banks',
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 4),
              Text('Max 10MB • Text-based PDF only',
                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
            ]),
          ),
        ),
        const SizedBox(height: 24),

        // How it works
        Text('How it works', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
        const SizedBox(height: 12),
        ...[
          ('1', 'Exam Detection', 'AI detects SSC/Army/Railway/MPPSC pattern', AppColors.primary),
          ('2', 'Question Extraction', 'Extracts existing MCQs from the PDF', AppColors.accent),
          ('3', 'AI Generation', 'Generates similar NEW questions in same style', AppColors.success),
          ('4', 'Review & Publish', 'You approve/remove questions, then publish', Colors.orange),
        ].map((step) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(color: step.$4.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: Center(child: Text(step.$1, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: step.$4))),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(step.$2, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
              Text(step.$3, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
            ])),
          ]),
        )),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// TEMPLATES TAB
// ════════════════════════════════════════════════════════════════════════════

class _TemplatesTab extends StatefulWidget {
  const _TemplatesTab();

  @override
  State<_TemplatesTab> createState() => _TemplatesTabState();
}

class _TemplatesTabState extends State<_TemplatesTab> {
  List<Map<String, dynamic>> _templates = [];
  bool _loading = true;
  int? _generating;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    if (auth.instituteId == null) return;
    try {
      final list = await ApiService.getTestTemplates(auth.instituteId!);
      if (mounted) setState(() { _templates = List<Map<String, dynamic>>.from(list); _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _useTemplate(Map<String, dynamic> tmpl) async {
    final auth = context.read<AuthProvider>();
    if (auth.instituteId == null) return;
    setState(() => _generating = tmpl['id']);
    try {
      final result = await ApiService.generateFromTemplate(
        tmpl['id'], auth.instituteId!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Test generated: ${result['title']}'),
        backgroundColor: AppColors.success,
      ));
      // Force refresh MyTests tab
      context.read<TestProvider>().refreshTests(auth.instituteId!);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error));
      }
    }
    if (mounted) setState(() => _generating = null);
  }

  Future<void> _deleteTemplate(int id) async {
    try {
      await ApiService.deleteTestTemplate(id);
      setState(() => _templates.removeWhere((t) => t['id'] == id));
    } catch (_) {}
  }

  void _showSaveDialog() {
    final provider = context.read<TestProvider>();
    // Pre-fill from last generation if available
    final nameCtrl = TextEditingController(text: 'My Template');
    showDialog(
      context: context,
      useRootNavigator: true,
      builder: (dCtx) => AlertDialog(
        title: Text('Save as Template', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: nameCtrl,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Template Name', hintText: 'e.g. SSC Math Mixed 20Q'),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.of(dCtx).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Navigator.of(dCtx).pop();
              final auth = context.read<AuthProvider>();
              if (auth.instituteId == null) return;
              try {
                await ApiService.saveTestTemplate(auth.instituteId!, {
                  'template_name': nameCtrl.text.trim().isEmpty ? 'My Template' : nameCtrl.text.trim(),
                  'exam_type': provider.lastExamType ?? '',
                  'subject': provider.lastSubject ?? '',
                  'topic': provider.lastTopic ?? '',
                  'difficulty': provider.lastDifficulty ?? 'Mixed',
                  'question_count': provider.lastCount ?? 20,
                  'duration_mins': 30,
                  'language': provider.lastLanguage ?? 'Hindi',
                  'custom_instructions': '',
                });
                _load();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error));
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.primary));

    return Column(children: [
      // Header
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Row(children: [
          Text('Quick Templates',
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: _showSaveDialog,
            icon: const Icon(Icons.save_rounded, size: 16),
            label: const Text('Save Current'),
          ),
        ]),
      ),
      const SizedBox(height: 4),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text('One-click test generation from saved configs',
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
      ),
      const SizedBox(height: 12),

      if (_templates.isEmpty)
        Expanded(
          child: Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.flash_on_rounded, size: 56, color: AppColors.textSecondary.withValues(alpha: 0.3)),
              const SizedBox(height: 16),
              Text('No templates yet',
                  style: GoogleFonts.poppins(fontSize: 16, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Text('Configure a test and tap "Save Current"\nto create a quick template.',
                  style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
                  textAlign: TextAlign.center),
            ]),
          ),
        )
      else
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _templates.length,
              itemBuilder: (_, i) {
                final t = _templates[i];
                final isGenerating = _generating == t['id'];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.flash_on_rounded, color: AppColors.primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(t['template_name'] ?? '',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
                        const SizedBox(height: 2),
                        Text(
                          '${t['exam_type'] ?? ''} • ${t['subject'] ?? ''} • ${t['question_count'] ?? 20}Q • ${t['difficulty'] ?? 'Mixed'}',
                          style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                        if ((t['times_used'] ?? 0) > 0)
                          Text('Used ${t['times_used']} times',
                              style: GoogleFonts.inter(fontSize: 10, color: AppColors.textSecondary)),
                      ])),
                      const SizedBox(width: 8),
                      Column(children: [
                        SizedBox(
                          height: 36,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.accent,
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                            ),
                            onPressed: isGenerating ? null : () => _useTemplate(t),
                            child: isGenerating
                                ? const SizedBox(width: 14, height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('Generate', style: TextStyle(fontSize: 12)),
                          ),
                        ),
                        const SizedBox(height: 4),
                        GestureDetector(
                          onTap: () => _deleteTemplate(t['id']),
                          child: const Icon(Icons.delete_outline, size: 16, color: AppColors.error),
                        ),
                      ]),
                    ]),
                  ),
                );
              },
            ),
          ),
        ),
    ]);
  }
}
