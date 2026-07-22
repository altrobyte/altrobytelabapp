import 'package:flutter/material.dart';
import '../models/student_model.dart';
import '../models/batch_model.dart';
import '../services/api_service.dart';

/// Single source of truth for institute-scoped data.
///
/// Screens should call the `ensure*` methods (which only hit the network when
/// the cache is empty or stale) and the `refresh*` methods for pull-to-refresh
/// or after a mutation. Concurrent calls are de-duplicated so a tab switch can
/// never fire the same request twice.
class InstituteProvider extends ChangeNotifier {
  // Cache freshness window. Within this window an ensure* call is a no-op.
  static const _ttl = Duration(minutes: 5);

  Map<String, dynamic>? dashboard;
  Map<String, dynamic>? subscription;
  List<Student> students = [];
  List<Batch> batches = [];

  bool isLoading = false; // dashboard spinner (kept for backwards-compat)
  bool isLoadingStudents = false;

  int? _loadedInstitute;
  DateTime? _dashboardAt;
  DateTime? _studentsAt;
  DateTime? _batchesAt;
  DateTime? _subscriptionAt;

  Future<void>? _dashboardInFlight;
  Future<void>? _studentsInFlight;
  Future<void>? _batchesInFlight;
  Future<void>? _subscriptionInFlight;

  bool get studentsLoaded => _studentsAt != null;
  bool get batchesLoaded => _batchesAt != null;
  bool get dashboardLoaded => _dashboardAt != null;
  bool get subscriptionLoaded => _subscriptionAt != null;

  bool _fresh(DateTime? at) =>
      at != null && DateTime.now().difference(at) < _ttl;

  // Drop everything when the logged-in institute changes (or on logout).
  void _scope(int instituteId) {
    if (_loadedInstitute != instituteId) {
      _loadedInstitute = instituteId;
      dashboard = null;
      subscription = null;
      students = [];
      batches = [];
      _dashboardAt = _studentsAt = _batchesAt = _subscriptionAt = null;
    }
  }

  void clear() {
    _loadedInstitute = null;
    dashboard = null;
    subscription = null;
    students = [];
    batches = [];
    _dashboardAt = _studentsAt = _batchesAt = _subscriptionAt = null;
    notifyListeners();
  }

  // ── Subscription ──
  Future<void> ensureSubscription(int instituteId, {bool force = false}) {
    _scope(instituteId);
    if (!force && _fresh(_subscriptionAt)) return Future.value();
    return _subscriptionInFlight ??= _fetchSubscription(instituteId);
  }

  Future<void> _fetchSubscription(int instituteId) async {
    try {
      subscription = await ApiService.getSubscription(instituteId);
      _subscriptionAt = DateTime.now();
    } catch (_) {
    } finally {
      _subscriptionInFlight = null;
      notifyListeners();
    }
  }

  // ── Dashboard ──
  Future<void> ensureDashboard(int instituteId, {bool force = false}) {
    _scope(instituteId);
    if (!force && _fresh(_dashboardAt)) return Future.value();
    return _dashboardInFlight ??= _fetchDashboard(instituteId);
  }

  Future<void> _fetchDashboard(int instituteId) async {
    isLoading = true;
    notifyListeners();
    try {
      dashboard = await ApiService.getDashboard(instituteId);
      _dashboardAt = DateTime.now();
    } catch (_) {
    } finally {
      isLoading = false;
      _dashboardInFlight = null;
      notifyListeners();
    }
  }

  // ── Students ──
  Future<void> ensureStudents(int instituteId, {bool force = false}) {
    _scope(instituteId);
    if (!force && _fresh(_studentsAt)) return Future.value();
    // force: drop any in-flight request so we always start fresh
    if (force) _studentsInFlight = null;
    return _studentsInFlight ??= _fetchStudents(instituteId);
  }

  Future<void> _fetchStudents(int instituteId) async {
    isLoadingStudents = true;
    notifyListeners();
    try {
      final raw = await ApiService.getStudents(instituteId);
      students =
          raw.map((s) => Student.fromJson(Map<String, dynamic>.from(s))).toList();
      _studentsAt = DateTime.now();
    } catch (_) {
    } finally {
      isLoadingStudents = false;
      _studentsInFlight = null;
      notifyListeners();
    }
  }

  // ── Batches ──
  Future<void> ensureBatches(int instituteId, {bool force = false}) {
    _scope(instituteId);
    if (!force && _fresh(_batchesAt)) return Future.value();
    return _batchesInFlight ??= _fetchBatches(instituteId);
  }

  Future<void> _fetchBatches(int instituteId) async {
    try {
      final raw = await ApiService.getBatches(instituteId);
      batches =
          raw.map((b) => Batch.fromJson(Map<String, dynamic>.from(b))).toList();
      _batchesAt = DateTime.now();
    } catch (_) {
    } finally {
      _batchesInFlight = null;
      notifyListeners();
    }
  }

  // Backwards-compatible explicit fetchers (force a refresh, bypass cache).
  Future<void> fetchDashboard(int instituteId) =>
      ensureDashboard(instituteId, force: true);
  Future<void> fetchStudents(int instituteId,
          {String search = '', int? batchId}) =>
      ensureStudents(instituteId, force: true);
  Future<void> fetchBatches(int instituteId) =>
      ensureBatches(instituteId, force: true);
}
