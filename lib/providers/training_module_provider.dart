import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/training_module_model.dart';
import '../services/api_service.dart';

class TrainingModuleProvider extends ChangeNotifier {
  static const _ttl = Duration(minutes: 5);

  List<TrainingModule> modules = [];
  TrainingModule? currentModule;
  bool isLoading = false;
  String? error;

  // Student progress — keyed by moduleId
  final Map<int, ModuleProgress> _progressMap = {};

  int? _loadedInstitute;
  DateTime? _modulesAt;
  Future<void>? _modulesInFlight;

  bool get modulesLoaded => _modulesAt != null;

  // ── Ensure modules are loaded (cached) ─────────────────────────────────

  bool _fresh() =>
      _modulesAt != null && DateTime.now().difference(_modulesAt!) < _ttl;

  Future<void> ensureModules(int instituteId, {bool force = false}) {
    if (_loadedInstitute != instituteId) {
      _loadedInstitute = instituteId;
      modules = [];
      _modulesAt = null;
    }
    if (!force && _fresh()) return Future.value();
    return _modulesInFlight ??= _fetchModules(instituteId);
  }

  Future<void> _fetchModules(int instituteId) async {
    isLoading = true;
    notifyListeners();
    try {
      final raw = await ApiService.getTrainingModules(instituteId);
      modules = raw
          .map((m) =>
              TrainingModule.fromJson(Map<String, dynamic>.from(m as Map)))
          .toList();
      _modulesAt = DateTime.now();
    } catch (e) {
      // If API fails, keep existing data
      error = e.toString();
    } finally {
      isLoading = false;
      _modulesInFlight = null;
      notifyListeners();
    }
  }

  void refreshModules(int instituteId) {
    _modulesAt = null;
    ensureModules(instituteId, force: true);
  }

  // ── Student-facing reads (student_token instead of educator token) ────

  Future<void> ensureModulesAsStudent(int instituteId, {bool force = false}) {
    if (_loadedInstitute != instituteId) {
      _loadedInstitute = instituteId;
      modules = [];
      _modulesAt = null;
    }
    if (!force && _fresh()) return Future.value();
    return _modulesInFlight ??= _fetchModulesAsStudent(instituteId);
  }

  Future<void> _fetchModulesAsStudent(int instituteId) async {
    isLoading = true;
    notifyListeners();
    try {
      final raw = await ApiService.getStudentTrainingModules(instituteId);
      modules = raw
          .map((m) =>
              TrainingModule.fromJson(Map<String, dynamic>.from(m as Map)))
          .where((m) => m.isPublished)
          .toList();
      _modulesAt = DateTime.now();
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      _modulesInFlight = null;
      notifyListeners();
    }
  }

  Future<void> loadModuleDetailAsStudent(int moduleId) async {
    isLoading = true;
    notifyListeners();
    try {
      final data = await ApiService.getStudentTrainingModule(moduleId);
      currentModule = TrainingModule.fromJson(data);
    } catch (e) {
      currentModule = modules.cast<TrainingModule?>().firstWhere(
            (m) => m?.id == moduleId,
            orElse: () => null,
          );
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // ── CRUD: Training Module ──────────────────────────────────────────────

  Future<bool> createModule(int instituteId,
      {required String title,
      String description = '',
      String iconName = 'school',
      String color = '#7C4DFF'}) async {
    try {
      final data = await ApiService.createTrainingModule(instituteId, {
        'title': title,
        'description': description,
        'icon_name': iconName,
        'color': color,
      });
      final newModule = TrainingModule.fromJson(data);
      modules.insert(0, newModule);
      _modulesAt = DateTime.now();
      notifyListeners();
      return true;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateModule(int moduleId,
      {String? title,
      String? description,
      String? iconName,
      String? color,
      bool? isPublished}) async {
    try {
      final body = <String, dynamic>{};
      if (title != null) body['title'] = title;
      if (description != null) body['description'] = description;
      if (iconName != null) body['icon_name'] = iconName;
      if (color != null) body['color'] = color;
      if (isPublished != null) body['is_published'] = isPublished;

      await ApiService.updateTrainingModule(moduleId, body);

      final idx = modules.indexWhere((m) => m.id == moduleId);
      if (idx >= 0) {
        modules[idx] = modules[idx].copyWith(
          title: title,
          description: description,
          iconName: iconName,
          color: color,
          isPublished: isPublished,
        );
      }
      if (currentModule?.id == moduleId) {
        currentModule = currentModule!.copyWith(
          title: title,
          description: description,
          iconName: iconName,
          color: color,
          isPublished: isPublished,
        );
      }
      notifyListeners();
      return true;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteModule(int moduleId) async {
    try {
      await ApiService.deleteTrainingModule(moduleId);
      modules.removeWhere((m) => m.id == moduleId);
      if (currentModule?.id == moduleId) currentModule = null;
      notifyListeners();
      return true;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> togglePublish(int moduleId) async {
    final idx = modules.indexWhere((m) => m.id == moduleId);
    if (idx < 0) return false;
    final newVal = !modules[idx].isPublished;
    return updateModule(moduleId, isPublished: newVal);
  }

  // ── Load single module detail ──────────────────────────────────────────

  Future<void> loadModuleDetail(int moduleId) async {
    isLoading = true;
    notifyListeners();
    try {
      final data = await ApiService.getTrainingModule(moduleId);
      currentModule = TrainingModule.fromJson(data);
    } catch (e) {
      // Try from local list
      currentModule = modules.cast<TrainingModule?>().firstWhere(
            (m) => m?.id == moduleId,
            orElse: () => null,
          );
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // ── CRUD: Topics ───────────────────────────────────────────────────────

  Future<bool> addTopic(int moduleId, String title) async {
    try {
      final data = await ApiService.createTopic(moduleId, {'title': title});
      final topic = ModuleTopic.fromJson(data);
      if (currentModule?.id == moduleId) {
        final topics = List<ModuleTopic>.from(currentModule!.topics)
          ..add(topic);
        currentModule = currentModule!.copyWith(topics: topics);
      }
      // Update in list too
      _updateModuleInList(moduleId);
      notifyListeners();
      return true;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateTopic(int topicId, String title) async {
    try {
      await ApiService.updateTopic(topicId, {'title': title});
      if (currentModule != null) {
        final topics = currentModule!.topics.map((t) {
          if (t.id == topicId) {
            return ModuleTopic(
              id: t.id,
              moduleId: t.moduleId,
              title: title,
              order: t.order,
              subtopics: t.subtopics,
            );
          }
          return t;
        }).toList();
        currentModule = currentModule!.copyWith(topics: topics);
      }
      notifyListeners();
      return true;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteTopic(int topicId) async {
    try {
      await ApiService.deleteTopic(topicId);
      if (currentModule != null) {
        final topics =
            currentModule!.topics.where((t) => t.id != topicId).toList();
        currentModule = currentModule!.copyWith(topics: topics);
      }
      notifyListeners();
      return true;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ── CRUD: Subtopics ────────────────────────────────────────────────────

  Future<bool> addSubtopic(int topicId, String title) async {
    try {
      final data = await ApiService.createSubtopic(topicId, {'title': title});
      final subtopic = ModuleSubtopic.fromJson(data);
      if (currentModule != null) {
        final topics = currentModule!.topics.map((t) {
          if (t.id == topicId) {
            final subs = List<ModuleSubtopic>.from(t.subtopics)..add(subtopic);
            return ModuleTopic(
              id: t.id,
              moduleId: t.moduleId,
              title: t.title,
              order: t.order,
              subtopics: subs,
            );
          }
          return t;
        }).toList();
        currentModule = currentModule!.copyWith(topics: topics);
      }
      notifyListeners();
      return true;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteSubtopic(int subtopicId) async {
    try {
      await ApiService.deleteSubtopic(subtopicId);
      if (currentModule != null) {
        final topics = currentModule!.topics.map((t) {
          final subs = t.subtopics.where((s) => s.id != subtopicId).toList();
          return ModuleTopic(
            id: t.id,
            moduleId: t.moduleId,
            title: t.title,
            order: t.order,
            subtopics: subs,
          );
        }).toList();
        currentModule = currentModule!.copyWith(topics: topics);
      }
      notifyListeners();
      return true;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ── CRUD: Content Items ────────────────────────────────────────────────

  Future<bool> addContentItem(int subtopicId, ContentItem item) async {
    try {
      final data = await ApiService.createContent(subtopicId, item.toJson());
      final newItem = ContentItem.fromJson(data);
      _insertContentItem(subtopicId, newItem);
      notifyListeners();
      return true;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateContentItem(ContentItem item) async {
    try {
      await ApiService.updateContent(item.id, item.toJson());
      _replaceContentItem(item);
      notifyListeners();
      return true;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteContentItem(int subtopicId, int contentId) async {
    try {
      await ApiService.deleteContent(contentId);
      _removeContentItem(subtopicId, contentId);
      notifyListeners();
      return true;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ── Student Progress ───────────────────────────────────────────────────

  ModuleProgress? getProgress(int moduleId) => _progressMap[moduleId];

  Future<void> loadProgress(int moduleId) async {
    try {
      final data = await ApiService.getModuleProgress(moduleId);
      _progressMap[moduleId] = ModuleProgress.fromJson(data);
      notifyListeners();
    } catch (_) {
      // Load from local cache
      await _loadLocalProgress(moduleId);
    }
  }

  Future<void> markComplete(int moduleId, int contentItemId) async {
    try {
      await ApiService.markContentComplete(contentItemId);
    } catch (_) {
      // Offline — save locally anyway
    }
    // Update local
    final existing = _progressMap[moduleId];
    final completed = Set<int>.from(existing?.completedItemIds ?? {})
      ..add(contentItemId);
    final total = _countModuleItems(moduleId);
    _progressMap[moduleId] = ModuleProgress(
      moduleId: moduleId,
      studentId: existing?.studentId ?? 0,
      completedItemIds: completed,
      totalItems: total,
    );
    await _saveLocalProgress(moduleId);
    notifyListeners();
  }

  bool isItemCompleted(int moduleId, int contentItemId) {
    return _progressMap[moduleId]?.isCompleted(contentItemId) ?? false;
  }

  // ── Helpers ────────────────────────────────────────────────────────────

  void _updateModuleInList(int moduleId) {
    if (currentModule != null) {
      final idx = modules.indexWhere((m) => m.id == moduleId);
      if (idx >= 0) modules[idx] = currentModule!;
    }
  }

  void _insertContentItem(int subtopicId, ContentItem item) {
    if (currentModule == null) return;
    final topics = currentModule!.topics.map((t) {
      final subs = t.subtopics.map((s) {
        if (s.id == subtopicId) {
          return s.copyWith(
              contentItems: List<ContentItem>.from(s.contentItems)..add(item));
        }
        return s;
      }).toList();
      return ModuleTopic(
        id: t.id,
        moduleId: t.moduleId,
        title: t.title,
        order: t.order,
        subtopics: subs,
      );
    }).toList();
    currentModule = currentModule!.copyWith(topics: topics);
  }

  void _replaceContentItem(ContentItem item) {
    if (currentModule == null) return;
    final topics = currentModule!.topics.map((t) {
      final subs = t.subtopics.map((s) {
        final items = s.contentItems.map((c) {
          return c.id == item.id ? item : c;
        }).toList();
        return s.copyWith(contentItems: items);
      }).toList();
      return ModuleTopic(
        id: t.id,
        moduleId: t.moduleId,
        title: t.title,
        order: t.order,
        subtopics: subs,
      );
    }).toList();
    currentModule = currentModule!.copyWith(topics: topics);
  }

  void _removeContentItem(int subtopicId, int contentId) {
    if (currentModule == null) return;
    final topics = currentModule!.topics.map((t) {
      final subs = t.subtopics.map((s) {
        if (s.id == subtopicId) {
          return s.copyWith(
              contentItems:
                  s.contentItems.where((c) => c.id != contentId).toList());
        }
        return s;
      }).toList();
      return ModuleTopic(
        id: t.id,
        moduleId: t.moduleId,
        title: t.title,
        order: t.order,
        subtopics: subs,
      );
    }).toList();
    currentModule = currentModule!.copyWith(topics: topics);
  }

  int _countModuleItems(int moduleId) {
    // Try currentModule first, then modules list
    TrainingModule? mod = currentModule?.id == moduleId ? currentModule : null;
    mod ??= modules.cast<TrainingModule?>().firstWhere(
          (m) => m?.id == moduleId,
          orElse: () => null,
        );
    return mod?.totalContentItems ?? 0;
  }

  Future<void> _loadLocalProgress(int moduleId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'module_progress_$moduleId';
    final raw = prefs.getString(key);
    if (raw != null) {
      try {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        _progressMap[moduleId] = ModuleProgress.fromJson(data);
        notifyListeners();
      } catch (_) {}
    }
  }

  Future<void> _saveLocalProgress(int moduleId) async {
    final progress = _progressMap[moduleId];
    if (progress == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'module_progress_$moduleId', jsonEncode(progress.toJson()));
  }

  void clearCurrent() {
    currentModule = null;
    notifyListeners();
  }
}
