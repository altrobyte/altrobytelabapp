import 'package:flutter/material.dart';
import '../models/test_model.dart';
import '../services/api_service.dart';

class TestProvider extends ChangeNotifier {
  static const _ttl = Duration(minutes: 5);

  AltroTest? currentTest;
  // Raw rows for the "My Tests" management list (needs attempts/is_published/
  // created_at/questions_json which the typed model drops).
  List<Map<String, dynamic>> testRows = [];
  bool isGenerating = false;
  bool isLoadingTests = false;
  String generationStatus = '';
  String? error;

  // Expert review state
  int? _regeneratingIndex;
  int? get regeneratingIndex => _regeneratingIndex;
  bool get isRegenerating => _regeneratingIndex != null;

  int? _loadedInstitute;
  DateTime? _testsAt;
  Future<void>? _testsInFlight;

  bool get testsLoaded => _testsAt != null;

  // Last generation config — used by Templates tab to save current settings
  String? lastExamType;
  String? lastSubject;
  String? lastTopic;
  String? lastDifficulty;
  String? lastLanguage;
  int? lastCount;

  Future<bool> generateTest(Map<String, dynamic> config) async {
    isGenerating = true;
    error = null;
    generationStatus = 'Sending request to AI...';
    // Save last config for template saving
    lastExamType = config['exam_type']?.toString();
    lastSubject = config['subject']?.toString();
    lastTopic = config['topic']?.toString();
    lastDifficulty = config['difficulty']?.toString();
    lastLanguage = config['language']?.toString();
    lastCount = config['count'] as int?;
    notifyListeners();
    try {
      generationStatus = 'Generating exam-quality questions...';
      notifyListeners();
      final data = await ApiService.generateTest(config);
      currentTest = AltroTest.fromJson(Map<String, dynamic>.from(data));
      // Invalidate test list cache so "My Tests" tab refreshes
      _testsAt = null;
      isGenerating = false;
      generationStatus = '';
      notifyListeners();
      return true;
    } catch (e) {
      error = e.toString();
      isGenerating = false;
      generationStatus = '';
      notifyListeners();
      return false;
    }
  }

  void refreshTests(int instituteId) {
    _testsAt = null;
    ensureTests(instituteId, force: true);
  }

  // ── Expert Review: Edit Question ────────────────────────────────────────

  void editQuestion(int index, Question updated) {
    if (currentTest == null || index < 0 || index >= currentTest!.questions.length) return;
    currentTest!.questions[index] = updated;
    currentTest!.recalculateQuality();
    notifyListeners();
  }

  // ── Expert Review: Delete Question ──────────────────────────────────────

  void deleteQuestion(int index) {
    if (currentTest == null || index < 0 || index >= currentTest!.questions.length) return;
    currentTest!.questions.removeAt(index);
    currentTest!.recalculateQuality();
    notifyListeners();
  }

  // ── Expert Review: Regenerate Single Question ───────────────────────────

  Future<bool> regenerateQuestion(int index) async {
    if (currentTest == null) return false;
    _regeneratingIndex = index;
    notifyListeners();

    try {
      final data = await ApiService.regenerateQuestion(currentTest!.id, index);
      final newQ = Question.fromJson(Map<String, dynamic>.from(data['question']));
      currentTest!.questions[index] = newQ;
      currentTest!.recalculateQuality();
      _regeneratingIndex = null;
      notifyListeners();
      return true;
    } catch (e) {
      error = e.toString();
      _regeneratingIndex = null;
      notifyListeners();
      return false;
    }
  }

  // ── Expert Review: Save Edited Questions to Backend ─────────────────────

  Future<bool> saveQuestions() async {
    if (currentTest == null) return false;
    try {
      final questionsJson = currentTest!.questions.map((q) => q.toJson()).toList();
      await ApiService.updateTestQuestions(currentTest!.id, questionsJson);
      return true;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ── Existing Methods ────────────────────────────────────────────────────

  bool _fresh() =>
      _testsAt != null && DateTime.now().difference(_testsAt!) < _ttl;

  Future<void> ensureTests(int instituteId, {bool force = false}) {
    if (_loadedInstitute != instituteId) {
      _loadedInstitute = instituteId;
      testRows = [];
      _testsAt = null;
    }
    if (!force && _fresh()) return Future.value();
    return _testsInFlight ??= _fetchTests(instituteId);
  }

  Future<void> _fetchTests(int instituteId) async {
    isLoadingTests = true;
    notifyListeners();
    try {
      final raw = await ApiService.getTests(instituteId);
      testRows =
          raw.map((t) => Map<String, dynamic>.from(t as Map)).toList();
      _testsAt = DateTime.now();
    } catch (_) {
    } finally {
      isLoadingTests = false;
      _testsInFlight = null;
      notifyListeners();
    }
  }

  // Backwards-compatible: force a refresh.
  Future<void> fetchTests(int instituteId) =>
      ensureTests(instituteId, force: true);

  void clearCurrent() {
    currentTest = null;
    notifyListeners();
  }
}
