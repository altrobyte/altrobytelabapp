import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api_constants.dart';
import '../mock/mock_data.dart';

const bool useMock =
    false; // Kept for local testing only. Set to false in production builds.

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, {this.statusCode});
  @override
  String toString() => message;

  bool get isNetwork => statusCode == null;
  bool get isUnauthorized => statusCode == 401;
  bool get isPaymentRequired => statusCode == 402;
  bool get isRateLimited => statusCode == 429;
}

class ApiService {
  static Future<String?> _token() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  static Map<String, String> _headers([String? token]) => {
        'Content-Type': 'application/json',
        // The API sets no cache headers of its own, so browsers cached these
        // responses heuristically: a client that had fetched a roadmap before
        // `plans` and `start_label` existed kept being handed that older shape,
        // and the card silently rendered without them.
        'Cache-Control': 'no-cache',
        'Pragma': 'no-cache',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  /// Uploads an image (picked as raw bytes, works on web) and returns the
  /// hosted URL to store in any banner_url-style field.
  static Future<String> uploadImage(Uint8List bytes, String filename, String contentType) async {
    final token = await _token();
    final uri = Uri.parse(ApiConstants.uploadImage());
    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll({if (token != null) 'Authorization': 'Bearer $token'})
      ..files.add(http.MultipartFile.fromBytes('file', bytes,
          filename: filename, contentType: MediaType.parse(contentType)));
    final streamed = await request.send().timeout(const Duration(seconds: 30));
    final res = await http.Response.fromStream(streamed);
    return _parse(res)['url'] as String;
  }

  static Map<String, dynamic> _parse(http.Response res) {
    try {
      final body = jsonDecode(res.body);
      if (res.statusCode >= 400) {
        final detail = body['detail'] ?? body['message'] ?? 'Request failed';
        throw ApiException(detail.toString(), statusCode: res.statusCode);
      }
      return Map<String, dynamic>.from(body);
    } on FormatException {
      throw ApiException('Server error. Please try again.',
          statusCode: res.statusCode);
    }
  }

  static Future<http.Response> safeGet(Uri uri,
      {Map<String, String>? headers}) {
    return _withNetworkRetry(
        () => http.get(uri, headers: headers).timeout(const Duration(seconds: 15)));
  }

  static Future<http.Response> safePost(Uri uri,
      {Map<String, String>? headers, Object? body}) {
    return _withNetworkRetry(() =>
        http.post(uri, headers: headers, body: body).timeout(const Duration(seconds: 20)));
  }

  /// Many students are on a real mobile connection that shows full signal
  /// bars but very low actual throughput (congested 4G, poor indoor
  /// coverage) — full bars don't mean fast. That's slow enough to blow past
  /// our timeouts on a single attempt, which used to surface immediately as
  /// a scary, unrecoverable "Connection failed". One transparent retry
  /// gives a slow-but-working connection a second chance before we give up.
  static Future<http.Response> _withNetworkRetry(
      Future<http.Response> Function() attempt) async {
    for (var i = 0; ; i++) {
      try {
        return await attempt();
      } on SocketException {
        throw ApiException('No internet connection. Check your network.');
      } on TimeoutException {
        if (i < 1) continue;
        throw ApiException(
            'Your network seems slow right now. Please check your connection and try again.');
      } on HttpException {
        throw ApiException('Server unreachable. Try again later.');
      } catch (e) {
        if (e is ApiException) rethrow;
        throw ApiException('Connection failed. Please try again.');
      }
    }
  }

  // Auth
  static Future<Map<String, dynamic>> login(
      String email, String password) async {
    if (useMock) return MockData.loginResponse;
    final res = await safePost(
      Uri.parse(ApiConstants.login()),
      headers: _headers(),
      body: jsonEncode({'email': email, 'password': password}),
    );
    return _parse(res);
  }

  static Future<Map<String, dynamic>> registerInstitute({
    required String name,
    required String email,
    required String password,
    String ownerName = '',
    String ownerPhone = '',
    String city = '',
  }) async {
    final res = await safePost(
      Uri.parse(ApiConstants.register()),
      headers: _headers(),
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
        'owner_name': ownerName,
        'owner_phone': ownerPhone,
        'city': city,
      }),
    );
    return _parse(res);
  }

  static Future<void> requestWhatsappOtp(String phone) async {
    await safePost(
      Uri.parse(
          '${ApiConstants.requestOtp()}?phone=${Uri.encodeComponent(phone)}'),
      headers: _headers(),
    );
  }

  static Future<Map<String, dynamic>> verifyWhatsappOtp(
      String phone, String otp) async {
    final res = await http.post(
      Uri.parse(
          '${ApiConstants.verifyOtp()}?phone=${Uri.encodeComponent(phone)}&otp=$otp'),
      headers: _headers(),
    );
    return _parse(res);
  }

  static Future<void> forgotPassword(String email) async {
    await http.post(
      Uri.parse(
          '${ApiConstants.forgotPassword()}?email=${Uri.encodeComponent(email)}'),
      headers: _headers(),
    );
  }

  static Future<void> resetPassword(
      String email, String otp, String newPassword) async {
    final res = await http.post(
      Uri.parse(
          '${ApiConstants.resetPassword()}?email=${Uri.encodeComponent(email)}&otp=$otp&new_password=${Uri.encodeComponent(newPassword)}'),
      headers: _headers(),
    );
    _parse(res);
  }

  static Future<Map<String, dynamic>> managerLogin(
      String email, String password) async {
    final res = await http.post(
      Uri.parse(ApiConstants.managerLogin()),
      headers: _headers(),
      body: jsonEncode({'email': email, 'password': password}),
    );
    return _parse(res);
  }

  static Future<void> superRequestOtp() async {
    await http.post(
      Uri.parse(ApiConstants.superRequestOtp()),
      headers: _headers(),
    );
  }

  static Future<Map<String, dynamic>> superVerifyOtp(String otp) async {
    final res = await http.post(
      Uri.parse('${ApiConstants.superVerifyOtp()}?otp=$otp'),
      headers: _headers(),
    );
    return _parse(res);
  }

  static Future<Map<String, dynamic>> superAdminLogin(
      String email, String password) async {
    final res = await http.post(
      Uri.parse(ApiConstants.superLogin()),
      headers: _headers(),
      body: jsonEncode({'email': email, 'password': password}),
    );
    return _parse(res);
  }

  // TEMPORARY pre-launch dev shortcuts — remove once real launch happens.
  static Future<Map<String, dynamic>> debugAutoLoginAdmin() async {
    final res = await http.post(
      Uri.parse(ApiConstants.debugAutoLogin()),
      headers: _headers(),
    );
    return _parse(res);
  }

  static Future<Map<String, dynamic>> debugAutoLoginSuperAdmin() async {
    final res = await http.post(
      Uri.parse(ApiConstants.superDebugAutoLogin()),
      headers: _headers(),
    );
    return _parse(res);
  }

  static Future<Map<String, dynamic>> getSuperStats(String token) async {
    final res = await http.get(
      Uri.parse(ApiConstants.superStats()),
      headers: _headers(token),
    );
    return _parse(res);
  }

  static Future<Map<String, dynamic>> getSuperInstitutes(String token) async {
    final res = await http.get(
      Uri.parse(ApiConstants.superInstitutes()),
      headers: _headers(token),
    );
    return _parse(res);
  }

  static Future<void> activateInstitute(int id, String token,
      {bool active = true, String reason = ''}) async {
    await http.put(
      Uri.parse(
          '${ApiConstants.superInstitutes()}/$id/activate?active=$active&reason=${Uri.encodeComponent(reason)}'),
      headers: _headers(token),
    );
  }

  static Future<Map<String, dynamic>> getSuperRevenue(String token) async {
    final res = await http.get(Uri.parse(ApiConstants.superRevenue()),
        headers: _headers(token));
    return _parse(res);
  }

  static Future<Map<String, dynamic>> getInstituteDetail(
      int id, String token) async {
    final res = await http.get(Uri.parse(ApiConstants.superInstituteDetail(id)),
        headers: _headers(token));
    return _parse(res);
  }

  static Future<Map<String, dynamic>> getInstitutePayments(
      int id, String token) async {
    final res = await http.get(
        Uri.parse(ApiConstants.superInstitutePayments(id)),
        headers: _headers(token));
    return _parse(res);
  }

  static Future<Map<String, dynamic>> recordPayment(
    int id,
    String token, {
    required int amount,
    required String plan,
    required int durationMonths,
    String note = '',
  }) async {
    final res = await http.post(
      Uri.parse(
          '${ApiConstants.superRecordPayment(id)}?amount=$amount&plan=${Uri.encodeComponent(plan)}&duration_months=$durationMonths&note=${Uri.encodeComponent(note)}'),
      headers: _headers(token),
    );
    return _parse(res);
  }

  static Future<void> changePlan(int id, String plan, String token) async {
    final res = await http.put(
      Uri.parse(
          '${ApiConstants.superChangePlan(id)}?plan=${Uri.encodeComponent(plan)}'),
      headers: _headers(token),
    );
    _parse(res);
  }

  // Dashboard
  static Future<Map<String, dynamic>> getDashboard(int instituteId) async {
    if (useMock) return MockData.dashboard;
    final token = await _token();
    final res = await http.get(
      Uri.parse(ApiConstants.dashboard(instituteId)),
      headers: _headers(token),
    );
    return _parse(res);
  }

  // Students
  static Future<List<dynamic>> getStudents(int instituteId,
      {String search = '', int? batchId}) async {
    if (useMock) return MockData.students;
    final token = await _token();
    var url = '${ApiConstants.students(instituteId)}?search=$search';
    if (batchId != null) url += '&batch_id=$batchId';
    final res = await safeGet(Uri.parse(url), headers: _headers(token));
    final data = _parse(res);
    return data['students'] as List;
  }

  static Future<Map<String, dynamic>> addStudent(
      int instituteId, Map<String, dynamic> body) async {
    final token = await _token();
    final res = await http.post(
      Uri.parse(ApiConstants.students(instituteId)),
      headers: _headers(token),
      body: jsonEncode(body),
    );
    return _parse(res);
  }

  static Future<Map<String, dynamic>> updateStudent(
      int studentId, Map<String, dynamic> body) async {
    final token = await _token();
    final res = await http.put(
      Uri.parse(ApiConstants.student(studentId)),
      headers: _headers(token),
      body: jsonEncode(body),
    );
    return _parse(res);
  }

  static Future<void> deleteStudent(int studentId) async {
    final token = await _token();
    final res = await http.delete(
      Uri.parse(ApiConstants.student(studentId)),
      headers: _headers(token),
    );
    _parse(res);
  }

  static Future<Map<String, dynamic>> bulkImportStudents(
      int instituteId, List<Map<String, dynamic>> students) async {
    final token = await _token();
    final res = await http.post(
      Uri.parse(ApiConstants.bulkImport(instituteId)),
      headers: _headers(token),
      body: jsonEncode({'students': students}),
    );
    return _parse(res);
  }

  static Future<Map<String, dynamic>> getStudentAnalytics(int studentId) async {
    final token = await _token();
    final res = await http.get(
      Uri.parse(ApiConstants.studentAnalytics(studentId)),
      headers: _headers(token),
    );
    return _parse(res);
  }

  // Batches
  static Future<List<dynamic>> getBatches(int instituteId) async {
    if (useMock) return MockData.batches;
    final token = await _token();
    final res = await http.get(
      Uri.parse(ApiConstants.batches(instituteId)),
      headers: _headers(token),
    );
    final data = _parse(res);
    return data['batches'] as List;
  }

  static Future<Map<String, dynamic>> createBatch(
      int instituteId, Map<String, dynamic> body) async {
    final token = await _token();
    final res = await http.post(
      Uri.parse(ApiConstants.batches(instituteId)),
      headers: _headers(token),
      body: jsonEncode(body),
    );
    return _parse(res);
  }

  static Future<Map<String, dynamic>> updateBatch(
      int batchId, Map<String, dynamic> body) async {
    final token = await _token();
    final res = await http.put(
      Uri.parse(ApiConstants.batch(batchId)),
      headers: _headers(token),
      body: jsonEncode(body),
    );
    return _parse(res);
  }

  static Future<void> deleteBatch(int batchId) async {
    final token = await _token();
    final res = await http.delete(
      Uri.parse(ApiConstants.batch(batchId)),
      headers: _headers(token),
    );
    _parse(res);
  }

  // Tests
  static Future<Map<String, dynamic>> generateTest(
      Map<String, dynamic> body) async {
    final token = await _token();
    final res = await http.post(
      Uri.parse(ApiConstants.generateTest()),
      headers: _headers(token),
      body: jsonEncode(body),
    );
    return _parse(res);
  }

  static Future<Map<String, dynamic>> publishTest(int testId,
      {bool published = true}) async {
    final token = await _token();
    final res = await http.post(
      Uri.parse('${ApiConstants.publishTest(testId)}?published=$published'),
      headers: _headers(token),
    );
    return _parse(res);
  }

  static Future<void> deleteTest(int testId) async {
    final token = await _token();
    final res = await http.delete(
      Uri.parse(ApiConstants.deleteTest(testId)),
      headers: _headers(token),
    );
    _parse(res);
  }

  static Future<Map<String, dynamic>> getTestResults(int testId) async {
    final token = await _token();
    final res = await http.get(
      Uri.parse(ApiConstants.testResults(testId)),
      headers: _headers(token),
    );
    return _parse(res);
  }

  static Future<Map<String, dynamic>> getTest(int testId) async {
    final res = await http.get(Uri.parse(ApiConstants.test(testId)));
    return _parse(res);
  }

  static Future<List<dynamic>> getTests(int instituteId) async {
    final token = await _token();
    final res = await http.get(
      Uri.parse(ApiConstants.tests(instituteId)),
      headers: _headers(token),
    );
    final data = _parse(res);
    return data['tests'] as List;
  }

  /// Sends the student token: the backend keys the daily quiz limit off the
  /// token's `student_users.id`. Without it the limit silently does not apply
  /// to anyone who signed up with Google, since they have no institute
  /// `students` row for the body's `student_id` to point at.
  static Future<Map<String, dynamic>> submitAttempt(
      int testId, Map<String, dynamic> body) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('student_token') ?? prefs.getString('token');
    final res = await http.post(
      Uri.parse(ApiConstants.testAttempt(testId)),
      headers: _headers(token),
      body: jsonEncode(body),
    );
    return _parse(res);
  }

  // Expert Review: Update all questions after trainer edits
  static Future<Map<String, dynamic>> updateTestQuestions(
      int testId, List<Map<String, dynamic>> questions) async {
    final token = await _token();
    final res = await http.put(
      Uri.parse('${ApiConstants.baseUrl}/tests/$testId/questions'),
      headers: _headers(token),
      body: jsonEncode(questions),
    );
    return _parse(res);
  }

  // Expert Review: Regenerate single question
  static Future<Map<String, dynamic>> regenerateQuestion(
      int testId, int questionIndex) async {
    final token = await _token();
    final res = await http.post(
      Uri.parse(
          '${ApiConstants.baseUrl}/tests/$testId/questions/$questionIndex/regenerate'),
      headers: _headers(token),
    );
    return _parse(res);
  }

  // Test config (per-institute subjects/patterns)
  static Future<Map<String, dynamic>> getTestConfig(int instituteId) async {
    final token = await _token();
    final res = await http.get(
      Uri.parse('${ApiConstants.baseUrl}/institutes/$instituteId/test-config'),
      headers: _headers(token),
    );
    return _parse(res);
  }

  static Future<String?> getToken() async => await _token();

  // Public parse — for use outside ApiService
  static Map<String, dynamic> parsePublic(http.Response res) => _parse(res);

  static Future<void> saveTestConfigSubjects(
      int instituteId, List<Map<String, dynamic>> items) async {
    final token = await _token();
    final res = await http.put(
      Uri.parse(
          '${ApiConstants.baseUrl}/institutes/$instituteId/test-config/subjects'),
      headers: _headers(token),
      body: jsonEncode({
        'items': items
            .map((e) => {
                  'label': e['label'],
                  'value': e['value'] ?? e['label'],
                  'icon': e['icon'] ?? ''
                })
            .toList()
      }),
    );
    _parse(res);
  }

  static Future<void> saveTestConfigPatterns(
      int instituteId, List<Map<String, dynamic>> items) async {
    final token = await _token();
    final res = await http.put(
      Uri.parse(
          '${ApiConstants.baseUrl}/institutes/$instituteId/test-config/exam-patterns'),
      headers: _headers(token),
      body: jsonEncode({
        'items': items
            .map((e) => {
                  'label': e['label'],
                  'value': e['value'] ?? e['label'],
                  'icon': e['icon'] ?? ''
                })
            .toList()
      }),
    );
    _parse(res);
  }

  // ── PDF Upload ────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> uploadPdfForTest(
      int instituteId, List<int> bytes, String filename) async {
    final token = await _token();
    final uri = Uri.parse(
        '${ApiConstants.baseUrl}/tests/upload-pdf?institute_id=$instituteId');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer ${token ?? ""}'
      ..files
          .add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
    final streamed = await request.send().timeout(const Duration(seconds: 120));
    final res = await http.Response.fromStream(streamed);
    return _parse(res);
  }

  // ── Test Templates ────────────────────────────────────────────────────────

  static Future<List<dynamic>> getTestTemplates(int instituteId) async {
    final token = await _token();
    final res = await http.get(
      Uri.parse(
          '${ApiConstants.baseUrl}/institutes/$instituteId/test-templates'),
      headers: _headers(token),
    );
    final data = _parse(res);
    return data['templates'] as List;
  }

  static Future<Map<String, dynamic>> saveTestTemplate(
      int instituteId, Map<String, dynamic> body) async {
    final token = await _token();
    final res = await http.post(
      Uri.parse(
          '${ApiConstants.baseUrl}/institutes/$instituteId/test-templates'),
      headers: _headers(token),
      body: jsonEncode(body),
    );
    return _parse(res);
  }

  static Future<void> deleteTestTemplate(int templateId) async {
    final token = await _token();
    final res = await http.delete(
      Uri.parse('${ApiConstants.baseUrl}/test-templates/$templateId'),
      headers: _headers(token),
    );
    _parse(res);
  }

  static Future<Map<String, dynamic>> generateFromTemplate(
      int templateId, int instituteId,
      {String title = '', int? batchId}) async {
    final token = await _token();
    var url =
        '${ApiConstants.baseUrl}/test-templates/$templateId/use?institute_id=$instituteId';
    if (title.isNotEmpty) url += '&title=${Uri.encodeComponent(title)}';
    if (batchId != null) url += '&batch_id=$batchId';
    final res = await http.post(Uri.parse(url), headers: _headers(token));
    return _parse(res);
  }

  // ── Adaptive Test ─────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> generateAdaptiveTest(
      int instituteId, int studentId, String examType,
      {int count = 20}) async {
    final token = await _token();
    final res = await http.post(
      Uri.parse('${ApiConstants.baseUrl}/tests/generate-adaptive'),
      headers: _headers(token),
      body: jsonEncode({
        'institute_id': instituteId,
        'student_id': studentId,
        'exam_type': examType,
        'count': count,
        'language': 'Hindi',
      }),
    );
    return _parse(res);
  }

  static Future<Map<String, dynamic>> getStudentTopicPerformance(int studentId,
      {String examType = ''}) async {
    final token = await _token();
    var url = '${ApiConstants.baseUrl}/students/$studentId/topic-performance';
    if (examType.isNotEmpty)
      url += '?exam_type=${Uri.encodeComponent(examType)}';
    final res = await http.get(Uri.parse(url), headers: _headers(token));
    return _parse(res);
  }

  // Plans (public)
  static Future<Map<String, dynamic>> getAvailablePlans() async {
    final res = await http.get(
      Uri.parse('${ApiConstants.baseUrl}/plans/available'),
    );
    return _parse(res);
  }

  // Exam Blueprints
  static Future<List<dynamic>> getExamBlueprints() async {
    final res = await http.get(
      Uri.parse('${ApiConstants.baseUrl}/exams/blueprints'),
    );
    final data = _parse(res);
    return data['blueprints'] as List;
  }

  // QR attendance
  static Future<Map<String, dynamic>> getQrToken(int batchId) async {
    final token = await _token();
    final res = await http.get(
      Uri.parse(ApiConstants.batchQrToken(batchId)),
      headers: _headers(token),
    );
    return _parse(res);
  }

  static Future<Map<String, dynamic>> qrCheckIn(
      Map<String, dynamic> payload) async {
    final prefs = await SharedPreferences.getInstance();
    final studentToken = prefs.getString('student_token');
    final res = await http.post(
      Uri.parse(ApiConstants.qrCheckin()),
      headers: _headers(studentToken),
      body: jsonEncode(payload),
    );
    return _parse(res);
  }

  // Student subscription
  static Future<Map<String, dynamic>> getStudentSubscription() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('student_token') ?? prefs.getString('token');
    final res = await http.get(
      Uri.parse(ApiConstants.studentSubscription()),
      headers: _headers(token),
    );
    return _parse(res);
  }

  /// [plan] is a `subscription_plans.tier_key` for a paid tier — '999'
  /// (Plus) or '9999' (Elite). The backend stores the same value in
  /// `student_subscriptions.plan`, so display and billing never drift.
  /// [phone] is sent only when the account has no real number of its own —
  /// Google sign-in gives no phone, so those accounts carry a placeholder
  /// that Cashfree rejects. The backend saves whatever is supplied, so the
  /// student is asked once rather than on every purchase.
  // ── Student WhatsApp-OTP login ────────────────────────────────────────
  /// Sends a WhatsApp OTP. The endpoint 502s when Meta rejects the send, so a
  /// success here really does mean a code is on its way — it used to answer
  /// "sent" unconditionally.
  static Future<void> standaloneRequestOtp({required String phone, String name = ''}) async {
    final res = await http.post(
      Uri.parse('${ApiConstants.baseUrl}/student/standalone/request-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone, 'name': name}),
    );
    _parse(res);
  }

  /// Verifies and signs in, registering the number if it is new. `name` is
  /// required only for a new number; the server says so with a 422.
  static Future<Map<String, dynamic>> standaloneVerifyOtp({
    required String phone,
    required String otp,
    String name = '',
  }) async {
    final res = await http.post(
      Uri.parse('${ApiConstants.baseUrl}/student/standalone/verify-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone, 'otp': otp, 'name': name}),
    );
    return _parse(res);
  }

  /// Fills in profile fields. Accepts an explicit [token] because signup uses
  /// it in the same breath as verifying, before the token has been stored.
  static Future<void> updateMyProfile(Map<String, dynamic> body,
      {String token = ''}) async {
    var t = token;
    if (t.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      t = prefs.getString('student_token') ?? prefs.getString('token') ?? '';
    }
    final res = await http.put(
      Uri.parse('${ApiConstants.baseUrl}/student/me'),
      headers: _headers(t),
      body: jsonEncode(body),
    );
    _parse(res);
  }

  /// What WhatsApp messages exist, and what actually went out.
  static Future<Map<String, dynamic>> waOverview() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final res = await http.get(Uri.parse('${ApiConstants.baseUrl}/wa/overview'),
        headers: _headers(token));
    return _parse(res);
  }

  /// Pairs of accounts that look like one person.
  static Future<List<dynamic>> crmMergeCandidates() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final res = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/crm/merge/candidates'),
        headers: _headers(token));
    return (_parse(res)['candidates'] as List?) ?? [];
  }

  static Future<Map<String, dynamic>> crmMergePreview(int keepId, int mergeId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final res = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/crm/merge/preview'
            '?keep_id=$keepId&merge_id=$mergeId'),
        headers: _headers(token));
    return _parse(res);
  }

  static Future<Map<String, dynamic>> crmMerge(int keepId, int mergeId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final res = await http.post(Uri.parse('${ApiConstants.baseUrl}/crm/merge'),
        headers: _headers(token),
        body: jsonEncode({'keep_id': keepId, 'merge_id': mergeId}));
    return _parse(res);
  }

  /// Admin editing a student's own details from the CRM.
  static Future<void> crmUpdateStudent(int id, Map<String, dynamic> body) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final res = await http.put(
        Uri.parse('${ApiConstants.baseUrl}/crm/students/$id'),
        headers: _headers(token), body: jsonEncode(body));
    _parse(res);
  }

  // ── Admin-editable platform settings ──────────────────────────────────
  static Future<List<dynamic>> getAdminSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final res = await http.get(Uri.parse('${ApiConstants.baseUrl}/admin/settings'),
        headers: _headers(token));
    return (_parse(res)['settings'] as List?) ?? [];
  }

  static Future<void> setAdminSetting(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final res = await http.put(
        Uri.parse('${ApiConstants.baseUrl}/admin/settings/$key'),
        headers: _headers(token),
        body: jsonEncode({'value': value}));
    _parse(res);
  }

  // ── CRM ───────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> crmLeads({String stage = '', String q = ''}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final uri = Uri.parse('${ApiConstants.baseUrl}/crm/leads').replace(queryParameters: {
      if (stage.isNotEmpty) 'stage': stage,
      if (q.isNotEmpty) 'q': q,
    });
    final res = await http.get(uri, headers: _headers(token));
    return _parse(res);
  }

  static Future<Map<String, dynamic>> crmSummary() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final res = await http.get(Uri.parse('${ApiConstants.baseUrl}/crm/summary'),
        headers: _headers(token));
    return _parse(res);
  }

  static Future<Map<String, dynamic>> crmLead(String phone) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final res = await http.get(Uri.parse('${ApiConstants.baseUrl}/crm/leads/$phone'),
        headers: _headers(token));
    return _parse(res);
  }

  static Future<void> crmUpdateLead(String phone, Map<String, dynamic> body) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final res = await http.put(Uri.parse('${ApiConstants.baseUrl}/crm/leads/$phone'),
        headers: _headers(token), body: jsonEncode(body));
    _parse(res);
  }

  static Future<void> crmAddNote(String phone, String text) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final res = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/crm/leads/$phone/notes'),
        headers: _headers(token),
        body: jsonEncode({'text': text}));
    _parse(res);
  }

  // ── Roadmap curriculum admin ──────────────────────────────────────────
  static Future<List<dynamic>> adminGetRoadmaps() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final res = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/roadmaps-admin/all'),
        headers: _headers(token));
    return (_parse(res)['roadmaps'] as List?) ?? [];
  }

  /// The curriculum as a tree. The server nests it and rolls progress up, so
  /// the admin screen renders the same shape the student screen does.
  static Future<List<dynamic>> adminGetRoadmapSteps(int roadmapId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final res = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/roadmaps-admin/$roadmapId/steps'),
        headers: _headers(token));
    return (_parse(res)['steps'] as List?) ?? [];
  }

  /// Creates when [id] is null (needs [roadmapId]), updates otherwise.
  static Future<Map<String, dynamic>> adminSaveRoadmapStep(
      Map<String, dynamic> body, {int? id, int? roadmapId}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final res = id == null
        ? await http.post(
            Uri.parse('${ApiConstants.baseUrl}/roadmaps-admin/$roadmapId/steps'),
            headers: _headers(token),
            body: jsonEncode(body))
        : await http.put(
            Uri.parse('${ApiConstants.baseUrl}/roadmaps-admin/steps/$id'),
            headers: _headers(token),
            body: jsonEncode(body));
    return _parse(res);
  }

  static Future<void> adminDeleteRoadmapStep(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final res = await http.delete(
        Uri.parse('${ApiConstants.baseUrl}/roadmaps-admin/steps/$id'),
        headers: _headers(token));
    _parse(res);
  }

  // ── Showcase admin ────────────────────────────────────────────────────
  static Future<List<dynamic>> adminGetShowcase(String kind) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final res = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/showcase-admin/all?kind=$kind'),
        headers: _headers(token));
    return (_parse(res)['items'] as List?) ?? [];
  }

  static Future<Map<String, dynamic>> adminSaveShowcase(
      Map<String, dynamic> body, {int? id}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final url = id == null
        ? '${ApiConstants.baseUrl}/showcase-admin'
        : '${ApiConstants.baseUrl}/showcase-admin/$id';
    final res = id == null
        ? await http.post(Uri.parse(url), headers: _headers(token), body: jsonEncode(body))
        : await http.put(Uri.parse(url), headers: _headers(token), body: jsonEncode(body));
    return _parse(res);
  }

  static Future<void> adminDeleteShowcase(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final res = await http.delete(
        Uri.parse('${ApiConstants.baseUrl}/showcase-admin/$id'), headers: _headers(token));
    _parse(res);
  }

  static Future<Map<String, dynamic>> adminAddShowcaseMedia(
      int itemId, String mediaType, String url,
      {String caption = '', int orderIndex = 0}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final res = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/showcase-admin/$itemId/media'),
        headers: _headers(token),
        body: jsonEncode({
          'media_type': mediaType,
          'url': url,
          'caption': caption,
          'order_index': orderIndex,
        }));
    return _parse(res);
  }

  static Future<void> adminDeleteShowcaseMedia(int mediaId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final res = await http.delete(
        Uri.parse('${ApiConstants.baseUrl}/showcase-admin/media/$mediaId'),
        headers: _headers(token));
    _parse(res);
  }

  /// Admin-curated Top Stories or Lab Setups. Media comes down with the list
  /// so the rotating strip does not stutter on its first turn.
  static Future<List<dynamic>> getShowcase(String kind) async {
    final res = await http.get(Uri.parse(ApiConstants.showcase(kind)),
        headers: _headers());
    return (_parse(res)['items'] as List?) ?? [];
  }

  static Future<Map<String, dynamic>> getShowcaseItem(int id) async {
    final res = await safeGet(Uri.parse(ApiConstants.showcaseItem(id)),
        headers: _headers());
    return _parse(res);
  }

  /// The published roadmaps, with this student's progress when signed in.
  /// Public: seeing the path is the pitch, so a signed-out visitor gets the
  /// same list with progress simply absent.
  static Future<List<dynamic>> getRoadmaps() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('student_token') ?? prefs.getString('token');
    final res = await safeGet(Uri.parse(ApiConstants.roadmaps()), headers: _headers(token));
    return (_parse(res)['roadmaps'] as List?) ?? [];
  }

  /// Records a callback request. The lead is saved server-side before any
  /// WhatsApp message is attempted, so a failed send never costs us the lead.
  static Future<Map<String, dynamic>> requestCallback({
    required String name,
    required String phone,
    String email = '',
    String segment = '',
    String plan = '',
    String source = 'roadmap',
  }) async {
    final res = await safePost(
      Uri.parse('${ApiConstants.baseUrl}/callback'),
      headers: _headers(null),
      body: jsonEncode({
        'name': name,
        'phone': phone,
        'email': email,
        'segment': segment,
        'plan': plan,
        'source': source,
      }),
    );
    return _parse(res);
  }

  static Future<Map<String, dynamic>> getRoadmap(String slug) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('student_token') ?? prefs.getString('token');
    final res = await safeGet(Uri.parse(ApiConstants.roadmap(slug)), headers: _headers(token));
    return _parse(res);
  }

  /// Ticks or unticks one curriculum item. Returns the new state.
  static Future<Map<String, dynamic>> toggleRoadmapStep(int stepId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('student_token') ?? prefs.getString('token');
    final res = await safePost(Uri.parse(ApiConstants.roadmapStepToggle(stepId)),
        headers: _headers(token));
    return _parse(res);
  }

  /// Starts the free platform trial. [phone] is required when the account has
  /// no real number of its own — the trial is the one moment we can ask for
  /// one before any money is involved, and it is what makes a trial limitable
  /// to one per person rather than one per free Google account.
  static Future<Map<String, dynamic>> startFreeTrial({String phone = ''}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('student_token') ?? prefs.getString('token');
    final res = await http.post(
      Uri.parse(ApiConstants.studentTrialStart()),
      headers: _headers(token),
      body: jsonEncode({'phone': phone}),
    );
    return _parse(res);
  }

  /// Public feature flags. Served to signed-out visitors too, so the UI and
  /// the API always agree on what is available.
  static Future<Map<String, dynamic>> getPlatformFeatures() async {
    final res = await safeGet(Uri.parse(ApiConstants.platformFeatures()));
    return _parse(res);
  }

  /// Price for every paid tier at every duration, discount already applied.
  /// Public — the pricing page shows it before sign-in.
  static Future<Map<String, dynamic>> getSubscriptionQuotes() async {
    final res = await safeGet(Uri.parse(ApiConstants.studentSubscriptionQuotes()));
    return _parse(res);
  }

  static Future<Map<String, dynamic>> createStudentSubscriptionLink({
    required String plan,
    String phone = '',
    int months = 1,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('student_token') ?? prefs.getString('token');
    final res = await http.post(
      Uri.parse(ApiConstants.studentSubscribe()),
      headers: _headers(token),
      body: jsonEncode({'plan': plan, 'phone': phone, 'months': months}),
    );
    return _parse(res);
  }

  static Future<Map<String, dynamic>> verifyStudentSubscription() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('student_token') ?? prefs.getString('token');
    final res = await http.post(
      Uri.parse(ApiConstants.studentSubscriptionVerify()),
      headers: _headers(token),
    );
    return _parse(res);
  }

  // Push notifications (FCM)
  static Future<void> registerDeviceToken(String token,
      {String platform = 'android'}) async {
    final authToken = await _token();
    await http.post(
      Uri.parse(ApiConstants.pushRegister()),
      headers: _headers(authToken),
      body: jsonEncode({'token': token, 'platform': platform}),
    );
  }

  static Future<Map<String, dynamic>> getPushPrefs() async {
    final authToken = await _token();
    final res = await safeGet(
      Uri.parse(ApiConstants.pushPrefs()),
      headers: _headers(authToken),
    );
    return _parse(res);
  }

  static Future<Map<String, dynamic>> updatePushPrefs(
      Map<String, bool> prefs) async {
    final authToken = await _token();
    final res = await http.put(
      Uri.parse(ApiConstants.pushPrefs()),
      headers: _headers(authToken),
      body: jsonEncode(prefs),
    );
    return _parse(res);
  }

  static Future<Map<String, dynamic>> sendCustomPush(
      int instituteId, String title, String body,
      {int? batchId}) async {
    final authToken = await _token();
    final res = await http.post(
      Uri.parse(ApiConstants.pushSend()),
      headers: _headers(authToken),
      body: jsonEncode({
        'institute_id': instituteId,
        'batch_id': batchId,
        'title': title,
        'body': body,
      }),
    );
    return _parse(res);
  }

  // Cashfree online payments
  static Future<Map<String, dynamic>> createFeePaymentLink(int feeId,
      {bool sendLink = true}) async {
    final token = await _token();
    final url = Uri.parse(ApiConstants.feePaymentLink(feeId))
        .replace(queryParameters: {'send_link': sendLink.toString()});
    final res = await http.post(url, headers: _headers(token));
    return _parse(res);
  }

  static Future<Map<String, dynamic>> verifyFeePayment(int feeId) async {
    final token = await _token();
    final res = await http.post(
      Uri.parse(ApiConstants.feeVerifyPayment(feeId)),
      headers: _headers(token),
    );
    return _parse(res);
  }

  static Future<Map<String, dynamic>> createSubscriptionLink(
      int instituteId, String plan,
      {int durationMonths = 1}) async {
    final token = await _token();
    final url = Uri.parse(ApiConstants.instituteSubscribe(instituteId)).replace(
      queryParameters: {
        'plan': plan,
        'duration_months': durationMonths.toString(),
      },
    );
    final res = await http.post(url, headers: _headers(token));
    return _parse(res);
  }

  static Future<Map<String, dynamic>> verifySubscriptionPayment(
      int instituteId) async {
    final token = await _token();
    final res = await http.post(
      Uri.parse('${ApiConstants.instituteSubscribe(instituteId)}/verify'),
      headers: _headers(token),
    );
    return _parse(res);
  }

  // PWA branding
  static Future<Map<String, dynamic>> getBrand(String slug) async {
    final res = await safeGet(Uri.parse(ApiConstants.brand(slug)));
    return _parse(res);
  }

  static Future<Map<String, dynamic>> getInstituteBrand(int instituteId) async {
    final token = await _token();
    final res = await safeGet(
      Uri.parse(ApiConstants.instituteBrand(instituteId)),
      headers: _headers(token),
    );
    return _parse(res);
  }

  static Future<Map<String, dynamic>> updateBrand(int instituteId,
      {String? slug, String? brandColor, String? tagline}) async {
    final token = await _token();
    final url = Uri.parse(ApiConstants.instituteBrand(instituteId)).replace(
      queryParameters: {
        if (slug != null) 'slug': slug,
        if (brandColor != null) 'brand_color': brandColor,
        if (tagline != null) 'tagline': tagline,
      },
    );
    final res = await http.put(url, headers: _headers(token));
    return _parse(res);
  }

  static Future<Map<String, dynamic>> getSubscription(int instituteId) async {
    final token = await _token();
    final res = await safeGet(
      Uri.parse(ApiConstants.instituteSubscription(instituteId)),
      headers: _headers(token),
    );
    return _parse(res);
  }

  // New: Audit logs (enterprise/compliance feature from backend)
  static Future<List<dynamic>> getAudits(int instituteId,
      {int limit = 50}) async {
    final token = await _token();
    final res = await safeGet(
      Uri.parse(
          '${ApiConstants.baseUrl}/institutes/$instituteId/audits?limit=$limit'),
      headers: _headers(token),
    );
    final data = _parse(res);
    return data['audits'] as List? ?? [];
  }

  // Institute profile
  static Future<Map<String, dynamic>> getInstituteProfile(
      int instituteId) async {
    final token = await _token();
    final res = await safeGet(
      Uri.parse(ApiConstants.instituteProfile(instituteId)),
      headers: _headers(token),
    );
    return _parse(res);
  }

  static Future<Map<String, dynamic>> updateInstituteProfile(
      int instituteId, Map<String, dynamic> body) async {
    final token = await _token();
    final res = await http.put(
      Uri.parse(ApiConstants.instituteProfile(instituteId)),
      headers: _headers(token),
      body: jsonEncode(body),
    );
    return _parse(res);
  }

  static Future<Map<String, dynamic>> updateWaNumber(
      int instituteId, String number) async {
    final token = await _token();
    final url = Uri.parse(ApiConstants.instituteSettings(instituteId))
        .replace(queryParameters: {'wa_ai_number': number});
    final res = await http.put(url, headers: _headers(token));
    return _parse(res);
  }

  static Future<Map<String, dynamic>> postNotice(int instituteId, String title,
      {String content = '',
      String type = 'notice',
      String linkUrl = '',
      String category = 'general',
      String segment = 'all'}) async {
    final token = await _token();
    final params = <String, String>{
      'title': title,
      'content': content,
      'type': type,
      'category': category,
      'segment': segment,
    };
    if (linkUrl.isNotEmpty) params['link_url'] = linkUrl;
    final url = Uri.parse(ApiConstants.notices(instituteId))
        .replace(queryParameters: params);
    final res = await http.post(url, headers: _headers(token));
    return _parse(res);
  }

  // Institute AI generation usage
  static Future<Map<String, dynamic>> getGenerationUsage(
      int instituteId) async {
    final token = await _token();
    final res = await safeGet(
      Uri.parse(ApiConstants.instituteGenerationUsage(instituteId)),
      headers: _headers(token),
    );
    return _parse(res);
  }

  // Attendance
  static Future<Map<String, dynamic>> markAttendance(
      int batchId, Map<String, dynamic> body) async {
    final token = await _token();
    final res = await http.post(
      Uri.parse(ApiConstants.markAttendance(batchId)),
      headers: _headers(token),
      body: jsonEncode(body),
    );
    return _parse(res);
  }

  static Future<Map<String, dynamic>> getAttendance(
      int batchId, String date) async {
    final token = await _token();
    final res = await safeGet(
      Uri.parse(ApiConstants.getAttendance(batchId, date)),
      headers: _headers(token),
    );
    return _parse(res);
  }

  // Fees
  static Future<List<dynamic>> getPendingFees(int instituteId) async {
    final token = await _token();
    final res = await safeGet(
      Uri.parse(ApiConstants.pendingFees(instituteId)),
      headers: _headers(token),
    );
    final data = _parse(res);
    return data['fees'] as List;
  }

  static Future<List<dynamic>> getFees(int instituteId,
      {String? status}) async {
    final token = await _token();
    var url = ApiConstants.fees(instituteId);
    if (status != null) url += '?status=$status';
    final res = await safeGet(Uri.parse(url), headers: _headers(token));
    final data = _parse(res);
    return data['fees'] as List;
  }

  static Future<List<dynamic>> getStudentFees(int studentId) async {
    final token = await _token();
    final res = await safeGet(
      Uri.parse(ApiConstants.studentFees(studentId)),
      headers: _headers(token),
    );
    final data = _parse(res);
    return (data['fees'] as List?) ?? [];
  }

  static Future<Map<String, dynamic>> markFeePaid(
      int feeId, Map<String, dynamic> body) async {
    final token = await _token();
    final res = await http.post(
      Uri.parse(ApiConstants.markPaid(feeId)),
      headers: _headers(token),
      body: jsonEncode(body),
    );
    return _parse(res);
  }

  static Future<Map<String, dynamic>> addFee(
      int instituteId, Map<String, dynamic> body) async {
    final token = await _token();
    final res = await http.post(
      Uri.parse(ApiConstants.fees(instituteId)),
      headers: _headers(token),
      body: jsonEncode(body),
    );
    return _parse(res);
  }

  // Analytics
  static Future<Map<String, dynamic>> getAnalytics(int instituteId) async {
    final token = await _token();
    final res = await safeGet(
      Uri.parse(ApiConstants.analytics(instituteId)),
      headers: _headers(token),
    );
    return _parse(res);
  }

  // Broadcast
  static Future<Map<String, dynamic>> broadcast(int instituteId, String message,
      {int? batchId}) async {
    final token = await _token();
    final body = {
      'institute_id': instituteId,
      'message': message,
      if (batchId != null) 'batch_id': batchId,
    };
    final res = await http.post(
      Uri.parse(ApiConstants.broadcast()),
      headers: _headers(token),
      body: jsonEncode(body),
    );
    return _parse(res);
  }

  static Future<void> sendFeeReminder(int feeId) async {
    final token = await _token();
    await http.post(
      Uri.parse(ApiConstants.feeReminder()),
      headers: _headers(token),
      body: jsonEncode({'fee_id': feeId}),
    );
  }

  // ── Training Modules ──────────────────────────────────────────────────

  static Future<List<dynamic>> getTrainingModules(int instituteId) async {
    final token = await _token();
    final res = await safeGet(
      Uri.parse(ApiConstants.trainingModules(instituteId)),
      headers: _headers(token),
    );
    final data = _parse(res);
    return data['modules'] as List? ?? [];
  }

  // Student-facing variants — authenticate with student_token instead of
  // the educator/admin 'token', since both roles share the same endpoints.
  static Future<List<dynamic>> getStudentTrainingModules(
      int instituteId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('student_token');
    final res = await safeGet(
      Uri.parse(ApiConstants.trainingModules(instituteId)),
      headers: _headers(token),
    );
    final data = _parse(res);
    return data['modules'] as List? ?? [];
  }

  static Future<Map<String, dynamic>> getStudentTrainingModule(
      int moduleId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('student_token');
    final res = await safeGet(
      Uri.parse(ApiConstants.trainingModule(moduleId)),
      headers: _headers(token),
    );
    return _parse(res);
  }

  static Future<Map<String, dynamic>> getTrainingModule(int moduleId) async {
    final token = await _token();
    final res = await safeGet(
      Uri.parse(ApiConstants.trainingModule(moduleId)),
      headers: _headers(token),
    );
    return _parse(res);
  }

  static Future<Map<String, dynamic>> createTrainingModule(
      int instituteId, Map<String, dynamic> body) async {
    final token = await _token();
    final res = await safePost(
      Uri.parse(ApiConstants.trainingModules(instituteId)),
      headers: _headers(token),
      body: jsonEncode(body),
    );
    return _parse(res);
  }

  static Future<Map<String, dynamic>> updateTrainingModule(
      int moduleId, Map<String, dynamic> body) async {
    final token = await _token();
    final res = await http.put(
      Uri.parse(ApiConstants.trainingModule(moduleId)),
      headers: _headers(token),
      body: jsonEncode(body),
    );
    return _parse(res);
  }

  static Future<void> deleteTrainingModule(int moduleId) async {
    final token = await _token();
    final res = await http.delete(
      Uri.parse(ApiConstants.trainingModule(moduleId)),
      headers: _headers(token),
    );
    _parse(res);
  }

  // Topics
  static Future<Map<String, dynamic>> createTopic(
      int moduleId, Map<String, dynamic> body) async {
    final token = await _token();
    final res = await safePost(
      Uri.parse(ApiConstants.trainingModuleTopics(moduleId)),
      headers: _headers(token),
      body: jsonEncode(body),
    );
    return _parse(res);
  }

  static Future<Map<String, dynamic>> updateTopic(
      int topicId, Map<String, dynamic> body) async {
    final token = await _token();
    final res = await http.put(
      Uri.parse(ApiConstants.trainingModuleTopic(topicId)),
      headers: _headers(token),
      body: jsonEncode(body),
    );
    return _parse(res);
  }

  static Future<void> deleteTopic(int topicId) async {
    final token = await _token();
    final res = await http.delete(
      Uri.parse(ApiConstants.trainingModuleTopic(topicId)),
      headers: _headers(token),
    );
    _parse(res);
  }

  // Subtopics
  static Future<Map<String, dynamic>> createSubtopic(
      int topicId, Map<String, dynamic> body) async {
    final token = await _token();
    final res = await safePost(
      Uri.parse(ApiConstants.trainingModuleSubtopics(topicId)),
      headers: _headers(token),
      body: jsonEncode(body),
    );
    return _parse(res);
  }

  static Future<void> deleteSubtopic(int subtopicId) async {
    final token = await _token();
    final res = await http.delete(
      Uri.parse(ApiConstants.trainingModuleSubtopic(subtopicId)),
      headers: _headers(token),
    );
    _parse(res);
  }

  // Content items
  static Future<Map<String, dynamic>> createContent(
      int subtopicId, Map<String, dynamic> body) async {
    final token = await _token();
    final res = await safePost(
      Uri.parse(ApiConstants.trainingModuleContent(subtopicId)),
      headers: _headers(token),
      body: jsonEncode(body),
    );
    return _parse(res);
  }

  static Future<Map<String, dynamic>> updateContent(
      int contentId, Map<String, dynamic> body) async {
    final token = await _token();
    final res = await http.put(
      Uri.parse(ApiConstants.trainingModuleContentItem(contentId)),
      headers: _headers(token),
      body: jsonEncode(body),
    );
    return _parse(res);
  }

  static Future<void> deleteContent(int contentId) async {
    final token = await _token();
    final res = await http.delete(
      Uri.parse(ApiConstants.trainingModuleContentItem(contentId)),
      headers: _headers(token),
    );
    _parse(res);
  }

  // Student progress
  static Future<Map<String, dynamic>> getModuleProgress(int moduleId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('student_token') ?? prefs.getString('token');
    final res = await safeGet(
      Uri.parse(ApiConstants.moduleProgress(moduleId)),
      headers: _headers(token),
    );
    return _parse(res);
  }

  static Future<void> markContentComplete(int contentId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('student_token') ?? prefs.getString('token');
    await safePost(
      Uri.parse(ApiConstants.markContentComplete(contentId)),
      headers: _headers(token),
    );
  }

  // ── Experiments (Experimental Training Platform) ──────────────────────────

  static Future<List<dynamic>> getExperimentsAdmin(int instituteId) async {
    final token = await _token();
    final res = await safeGet(
      Uri.parse(ApiConstants.experimentsAdmin(instituteId)),
      headers: _headers(token),
    );
    return _parse(res)['experiments'] as List? ?? [];
  }

  static Future<List<dynamic>> getExperimentsStudent(int instituteId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('student_token');
    final res = await safeGet(
      Uri.parse(ApiConstants.experimentsStudent(instituteId)),
      headers: _headers(token),
    );
    return _parse(res)['experiments'] as List? ?? [];
  }

  static Future<Map<String, dynamic>> getExperimentStudent(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('student_token');
    final res = await safeGet(
      Uri.parse(ApiConstants.experimentStudent(id)),
      headers: _headers(token),
    );
    return _parse(res);
  }

  static Future<Map<String, dynamic>> createExperiment(
      int instituteId, Map<String, dynamic> body) async {
    final token = await _token();
    final res = await safePost(
      Uri.parse(ApiConstants.experimentsAdmin(instituteId)),
      headers: _headers(token),
      body: jsonEncode(body),
    );
    return _parse(res);
  }

  static Future<Map<String, dynamic>> updateExperiment(
      int id, Map<String, dynamic> body) async {
    final token = await _token();
    final res = await http.put(
      Uri.parse(ApiConstants.experiment(id)),
      headers: _headers(token),
      body: jsonEncode(body),
    );
    return _parse(res);
  }

  static Future<void> deleteExperiment(int id) async {
    final token = await _token();
    final res = await http.delete(
      Uri.parse(ApiConstants.experiment(id)),
      headers: _headers(token),
    );
    _parse(res);
  }

  static Future<Map<String, dynamic>> submitExperimentAttempt(
      int id, Map<String, dynamic> resultData, {String notes = ''}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('student_token');
    final res = await safePost(
      Uri.parse(ApiConstants.experimentAttempt(id)),
      headers: _headers(token),
      body: jsonEncode({'result_data': resultData, 'notes': notes}),
    );
    return _parse(res);
  }

  static Future<List<dynamic>> getMyExperimentAttempts(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('student_token');
    final res = await safeGet(
      Uri.parse(ApiConstants.experimentAttempts(id)),
      headers: _headers(token),
    );
    return _parse(res)['attempts'] as List? ?? [];
  }

  // ── Company Profile (public marketing site) ──────────────────────────────

  static Future<Map<String, dynamic>> getCompanyPage(String slug) async {
    final res = await safeGet(Uri.parse(ApiConstants.companyPage(slug)));
    return _parse(res);
  }

  static Future<List<dynamic>> getCompanyItems({String? category}) async {
    final res = await safeGet(Uri.parse(ApiConstants.companyItems(category: category)));
    return _parse(res)['items'] as List? ?? [];
  }

  static Future<List<dynamic>> getCompanyStats() async {
    final res = await safeGet(Uri.parse(ApiConstants.companyStats()));
    return _parse(res)['stats'] as List? ?? [];
  }

  static Future<Map<String, dynamic>> getCompanySocialLinks() async {
    final res = await safeGet(Uri.parse(ApiConstants.companySocialLinks()));
    return _parse(res)['links'] as Map<String, dynamic>? ?? {};
  }

  static Future<Map<String, dynamic>> updateCompanyPage(
      String slug, Map<String, dynamic> body) async {
    final token = await _token();
    final res = await http.put(
      Uri.parse(ApiConstants.companyPage(slug)),
      headers: _headers(token),
      body: jsonEncode(body),
    );
    return _parse(res);
  }

  static Future<List<dynamic>> getCompanyItemsAdmin({String? category}) async {
    final token = await _token();
    final res = await safeGet(
      Uri.parse(ApiConstants.companyAdminItems(category: category)),
      headers: _headers(token),
    );
    return _parse(res)['items'] as List? ?? [];
  }

  static Future<Map<String, dynamic>> createCompanyItem(Map<String, dynamic> body) async {
    final token = await _token();
    final res = await safePost(
      Uri.parse(ApiConstants.companyAdminItems()),
      headers: _headers(token),
      body: jsonEncode(body),
    );
    return _parse(res);
  }

  static Future<Map<String, dynamic>> updateCompanyItem(int id, Map<String, dynamic> body) async {
    final token = await _token();
    final res = await http.put(
      Uri.parse(ApiConstants.companyAdminItem(id)),
      headers: _headers(token),
      body: jsonEncode(body),
    );
    return _parse(res);
  }

  static Future<void> deleteCompanyItem(int id) async {
    final token = await _token();
    final res = await http.delete(
      Uri.parse(ApiConstants.companyAdminItem(id)),
      headers: _headers(token),
    );
    _parse(res);
  }

  static Future<Map<String, dynamic>> createCompanyStat(Map<String, dynamic> body) async {
    final token = await _token();
    final res = await safePost(
      Uri.parse(ApiConstants.companyAdminStats()),
      headers: _headers(token),
      body: jsonEncode(body),
    );
    return _parse(res);
  }

  static Future<Map<String, dynamic>> updateCompanyStat(int id, Map<String, dynamic> body) async {
    final token = await _token();
    final res = await http.put(
      Uri.parse(ApiConstants.companyAdminStat(id)),
      headers: _headers(token),
      body: jsonEncode(body),
    );
    return _parse(res);
  }

  static Future<void> deleteCompanyStat(int id) async {
    final token = await _token();
    final res = await http.delete(
      Uri.parse(ApiConstants.companyAdminStat(id)),
      headers: _headers(token),
    );
    _parse(res);
  }

  static Future<Map<String, dynamic>> updateCompanySocialLinks(Map<String, String> links) async {
    final token = await _token();
    final res = await http.put(
      Uri.parse(ApiConstants.companyAdminSocialLinks()),
      headers: _headers(token),
      body: jsonEncode({'links': links}),
    );
    return _parse(res);
  }

  // ── Test Series ───────────────────────────────────────────────────────────

  static Future<List<dynamic>> getTestSeriesAdmin(int instituteId) async {
    final token = await _token();
    final res = await safeGet(
      Uri.parse(ApiConstants.testSeriesAdmin(instituteId)),
      headers: _headers(token),
    );
    return _parse(res)['series'] as List? ?? [];
  }

  /// Returns {"series": [...], "module_tests": [...]} — series are curated
  /// admin groupings; module_tests are quizzes authored inside Training
  /// Modules, grouped by their parent module.
  static Future<Map<String, dynamic>> getTestSeriesStudent(int instituteId) async {
    final res = await safeGet(Uri.parse(ApiConstants.testSeriesStudent(instituteId)));
    return _parse(res);
  }

  /// Resolves the institute server-side from the student's token, falling
  /// back to the Altrobyte Lab institute. Use this instead of passing an
  /// institute id the app may not actually have.
  static Future<Map<String, dynamic>> getTestSeriesForStudent() async {
    final token = await _studentToken();
    final res = await safeGet(
      Uri.parse(ApiConstants.testSeriesForStudent()),
      headers: _headers(token),
    );
    return _parse(res);
  }

  static Future<Map<String, dynamic>> createTestSeries(
      int instituteId, Map<String, dynamic> body) async {
    final token = await _token();
    final res = await safePost(
      Uri.parse(ApiConstants.testSeriesAdmin(instituteId)),
      headers: _headers(token),
      body: jsonEncode(body),
    );
    return _parse(res);
  }

  static Future<Map<String, dynamic>> updateTestSeries(int id, Map<String, dynamic> body) async {
    final token = await _token();
    final res = await http.put(
      Uri.parse(ApiConstants.testSeries(id)),
      headers: _headers(token),
      body: jsonEncode(body),
    );
    return _parse(res);
  }

  static Future<void> deleteTestSeries(int id) async {
    final token = await _token();
    final res = await http.delete(
      Uri.parse(ApiConstants.testSeries(id)),
      headers: _headers(token),
    );
    _parse(res);
  }

  static Future<Map<String, dynamic>> assignTestToSeries(
      int testId, int? seriesId, {int seriesOrder = 0}) async {
    final token = await _token();
    final res = await http.put(
      Uri.parse(ApiConstants.assignTestSeries(testId)),
      headers: _headers(token),
      body: jsonEncode({'series_id': seriesId, 'series_order': seriesOrder}),
    );
    return _parse(res);
  }

  // ── Job Updates ──────────────────────────────────────────────────────────

  static Future<List<dynamic>> getJobs({
    String? category, String? domain, String? location, String? experienceLevel,
  }) async {
    final res = await safeGet(Uri.parse(ApiConstants.jobs(
      category: category, domain: domain, location: location, experienceLevel: experienceLevel,
    )));
    return _parse(res)['listings'] as List? ?? [];
  }

  static Future<List<dynamic>> getJobsAdmin({String? category}) async {
    final token = await _token();
    final res = await safeGet(
      Uri.parse(ApiConstants.jobsAdmin(category: category)),
      headers: _headers(token),
    );
    return _parse(res)['listings'] as List? ?? [];
  }

  static Future<Map<String, dynamic>> createJob(Map<String, dynamic> body) async {
    final token = await _token();
    final res = await safePost(
      Uri.parse(ApiConstants.jobsAdmin()),
      headers: _headers(token),
      body: jsonEncode(body),
    );
    return _parse(res);
  }

  static Future<Map<String, dynamic>> updateJob(int id, Map<String, dynamic> body) async {
    final token = await _token();
    final res = await http.put(
      Uri.parse(ApiConstants.jobAdminItem(id)),
      headers: _headers(token),
      body: jsonEncode(body),
    );
    return _parse(res);
  }

  static Future<void> deleteJob(int id) async {
    final token = await _token();
    final res = await http.delete(
      Uri.parse(ApiConstants.jobAdminItem(id)),
      headers: _headers(token),
    );
    _parse(res);
  }

  static Future<Map<String, dynamic>> getJob(int id) async {
    final res = await safeGet(Uri.parse(ApiConstants.job(id)));
    return _parse(res);
  }

  static Future<Map<String, dynamic>> applyToJob(int id, {
    required String name, String phone = '', String email = '',
    String resumeUrl = '', String coverNote = '',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('student_token');
    final res = await safePost(
      Uri.parse(ApiConstants.jobApply(id)),
      headers: _headers(token),
      body: jsonEncode({
        'name': name, 'phone': phone, 'email': email,
        'resume_url': resumeUrl, 'cover_note': coverNote,
      }),
    );
    return _parse(res);
  }

  static Future<bool> hasAppliedToJob(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('student_token');
    final res = await safeGet(
      Uri.parse(ApiConstants.jobMyApplication(id)),
      headers: _headers(token),
    );
    return (_parse(res)['applied'] as bool?) ?? false;
  }

  static Future<List<dynamic>> getJobApplications(int id) async {
    final token = await _token();
    final res = await safeGet(
      Uri.parse(ApiConstants.jobApplications(id)),
      headers: _headers(token),
    );
    return _parse(res)['applications'] as List? ?? [];
  }

  static Future<void> updateJobApplicationStatus(int applicationId, String status) async {
    final token = await _token();
    final res = await http.put(
      Uri.parse(ApiConstants.jobApplicationStatus(applicationId)),
      headers: _headers(token),
      body: jsonEncode({'status': status}),
    );
    _parse(res);
  }

  // ── Events ───────────────────────────────────────────────────────────────

  static Future<List<dynamic>> getEvents() async {
    final res = await safeGet(Uri.parse(ApiConstants.events()));
    return _parse(res)['events'] as List? ?? [];
  }

  static Future<Map<String, dynamic>> getEvent(int id) async {
    final res = await safeGet(Uri.parse(ApiConstants.event(id)));
    return _parse(res);
  }

  static Future<Map<String, dynamic>> registerForEvent(
      int id, {required String name, String phone = '', String email = ''}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('student_token');
    final res = await safePost(
      Uri.parse(ApiConstants.eventRegister(id)),
      headers: _headers(token),
      body: jsonEncode({'name': name, 'phone': phone, 'email': email}),
    );
    return _parse(res);
  }

  static Future<bool> isRegisteredForEvent(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('student_token');
    final res = await safeGet(
      Uri.parse(ApiConstants.eventMyRegistration(id)),
      headers: _headers(token),
    );
    return (_parse(res)['registered'] as bool?) ?? false;
  }

  static Future<List<dynamic>> getEventsAdmin() async {
    final token = await _token();
    final res = await safeGet(
      Uri.parse(ApiConstants.eventsAdmin()),
      headers: _headers(token),
    );
    return _parse(res)['events'] as List? ?? [];
  }

  static Future<Map<String, dynamic>> createEvent(Map<String, dynamic> body) async {
    final token = await _token();
    final res = await safePost(
      Uri.parse(ApiConstants.eventAdminCreate()),
      headers: _headers(token),
      body: jsonEncode(body),
    );
    return _parse(res);
  }

  static Future<Map<String, dynamic>> updateEvent(int id, Map<String, dynamic> body) async {
    final token = await _token();
    final res = await http.put(
      Uri.parse(ApiConstants.eventAdminItem(id)),
      headers: _headers(token),
      body: jsonEncode(body),
    );
    return _parse(res);
  }

  static Future<void> deleteEvent(int id) async {
    final token = await _token();
    final res = await http.delete(
      Uri.parse(ApiConstants.eventAdminItem(id)),
      headers: _headers(token),
    );
    _parse(res);
  }

  static Future<List<dynamic>> getEventAttendees(int id) async {
    final token = await _token();
    final res = await safeGet(
      Uri.parse(ApiConstants.eventAttendees(id)),
      headers: _headers(token),
    );
    return _parse(res)['attendees'] as List? ?? [];
  }

  // ── Live Sessions / Workshops ────────────────────────────────────────────

  static Future<List<dynamic>> getLiveSessions({bool featured = false}) async {
    final res = await safeGet(Uri.parse(ApiConstants.liveSessions(featured: featured)));
    return _parse(res)['sessions'] as List? ?? [];
  }

  static Future<Map<String, dynamic>> getLiveSession(int id) async {
    final res = await safeGet(Uri.parse(ApiConstants.liveSession(id)));
    return _parse(res);
  }

  static Future<Map<String, dynamic>> registerForLiveSession(int id, {
    required String name, required String phone, required String email,
    required String college, required String branch, required String address, required String city,
    String couponCode = '',
    bool forceNew = false,
    String returnUrl = '',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('student_token');
    final res = await safePost(
      Uri.parse(ApiConstants.liveSessionRegister(id)),
      headers: _headers(token),
      body: jsonEncode({
        'name': name, 'phone': phone, 'email': email,
        'college': college, 'branch': branch, 'address': address, 'city': city,
        'coupon_code': couponCode,
        'force_new': forceNew,
        'return_url': returnUrl,
      }),
    );
    return _parse(res);
  }

  /// Read-only preview — does not consume a coupon use.
  static Future<Map<String, dynamic>> validateLiveSessionCoupon(int id, String couponCode) async {
    final res = await safePost(
      Uri.parse(ApiConstants.liveSessionValidateCoupon(id)),
      headers: _headers(null),
      body: jsonEncode({'coupon_code': couponCode}),
    );
    return _parse(res);
  }

  static Future<bool> isRegisteredForLiveSession(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('student_token');
    final res = await safeGet(
      Uri.parse(ApiConstants.liveSessionMyRegistration(id)),
      headers: _headers(token),
    );
    return (_parse(res)['registered'] as bool?) ?? false;
  }

  static Future<Map<String, dynamic>> getLiveSessionMyRegistration(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('student_token');
    final res = await safeGet(
      Uri.parse(ApiConstants.liveSessionMyRegistration(id)),
      headers: _headers(token),
    );
    return _parse(res);
  }

  static Future<Map<String, dynamic>> verifyLiveSessionPayment(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('student_token');
    final res = await safePost(
      Uri.parse(ApiConstants.liveSessionVerifyPayment(id)),
      headers: _headers(token),
    );
    return _parse(res);
  }

  static Future<Map<String, dynamic>> getLiveSessionReceipt(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('student_token');
    final res = await safeGet(
      Uri.parse(ApiConstants.liveSessionReceipt(id)),
      headers: _headers(token),
    );
    return _parse(res);
  }

  static Future<List<dynamic>> getLiveSessionsAdmin() async {
    final token = await _token();
    final res = await safeGet(
      Uri.parse(ApiConstants.liveSessionsAdmin()),
      headers: _headers(token),
    );
    return _parse(res)['sessions'] as List? ?? [];
  }

  static Future<Map<String, dynamic>> createLiveSession(Map<String, dynamic> body) async {
    final token = await _token();
    final res = await safePost(
      Uri.parse(ApiConstants.liveSessionAdminCreate()),
      headers: _headers(token),
      body: jsonEncode(body),
    );
    return _parse(res);
  }

  static Future<Map<String, dynamic>> updateLiveSession(int id, Map<String, dynamic> body) async {
    final token = await _token();
    final res = await http.put(
      Uri.parse(ApiConstants.liveSessionAdminItem(id)),
      headers: _headers(token),
      body: jsonEncode(body),
    );
    return _parse(res);
  }

  static Future<void> deleteLiveSession(int id) async {
    final token = await _token();
    final res = await http.delete(
      Uri.parse(ApiConstants.liveSessionAdminItem(id)),
      headers: _headers(token),
    );
    _parse(res);
  }

  static Future<Map<String, dynamic>> markLiveSessionAttendeePaid(int sessionId, int registrationId) async {
    final token = await _token();
    final res = await http.put(
      Uri.parse('${ApiConstants.liveSessionAttendee(sessionId, registrationId)}/mark-paid'),
      headers: _headers(token),
    );
    return _parse(res);
  }

  static Future<List<dynamic>> getAllTrainingModulesLite() async {
    final token = await _token();
    final res = await safeGet(
      Uri.parse(ApiConstants.allTrainingModulesLite()),
      headers: _headers(token),
    );
    return _parse(res)['modules'] as List? ?? [];
  }

  static Future<void> deleteLiveSessionAttendee(int sessionId, int registrationId) async {
    final token = await _token();
    final res = await http.delete(
      Uri.parse(ApiConstants.liveSessionAttendee(sessionId, registrationId)),
      headers: _headers(token),
    );
    _parse(res);
  }

  static Future<List<dynamic>> getLiveSessionAttendees(int id) async {
    final token = await _token();
    final res = await safeGet(
      Uri.parse(ApiConstants.liveSessionAttendees(id)),
      headers: _headers(token),
    );
    return _parse(res)['attendees'] as List? ?? [];
  }

  // ── Training module purchase (student) ──────────────────────────────────

  static Future<Map<String, dynamic>> registerForModule(int moduleId, {
    required String name, required String phone, required String email,
    String couponCode = '',
    bool forceNew = false,
    String returnUrl = '',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('student_token');
    final res = await safePost(
      Uri.parse(ApiConstants.moduleRegister(moduleId)),
      headers: _headers(token),
      body: jsonEncode({
        'name': name, 'phone': phone, 'email': email,
        'coupon_code': couponCode,
        'force_new': forceNew,
        'return_url': returnUrl,
      }),
    );
    return _parse(res);
  }

  /// Read-only preview — does not consume a coupon use.
  static Future<Map<String, dynamic>> validateModuleCoupon(int moduleId, String couponCode) async {
    final res = await safePost(
      Uri.parse(ApiConstants.moduleValidateCoupon(moduleId)),
      headers: _headers(null),
      body: jsonEncode({'coupon_code': couponCode}),
    );
    return _parse(res);
  }

  static Future<Map<String, dynamic>> verifyModulePayment(int moduleId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('student_token');
    final res = await safePost(
      Uri.parse(ApiConstants.moduleVerifyPayment(moduleId)),
      headers: _headers(token),
    );
    return _parse(res);
  }

  static Future<Map<String, dynamic>> getModuleMyEnrollment(int moduleId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('student_token');
    final res = await safeGet(
      Uri.parse(ApiConstants.moduleMyEnrollment(moduleId)),
      headers: _headers(token),
    );
    return _parse(res);
  }

  static Future<Map<String, dynamic>> getModuleReceipt(int moduleId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('student_token');
    final res = await safeGet(
      Uri.parse(ApiConstants.moduleReceipt(moduleId)),
      headers: _headers(token),
    );
    return _parse(res);
  }

  static Future<Map<String, dynamic>> markModuleEnrollmentPaid(int moduleId, int purchaseId) async {
    final token = await _token();
    final res = await http.put(
      Uri.parse('${ApiConstants.moduleEnrollmentAction(moduleId, purchaseId)}/mark-paid'),
      headers: _headers(token),
    );
    return _parse(res);
  }

  static Future<void> deleteModuleEnrollment(int moduleId, int purchaseId) async {
    final token = await _token();
    final res = await http.delete(
      Uri.parse(ApiConstants.moduleEnrollmentAction(moduleId, purchaseId)),
      headers: _headers(token),
    );
    _parse(res);
  }

  static Future<List<dynamic>> getModuleEnrollments(int moduleId) async {
    final token = await _token();
    final res = await safeGet(
      Uri.parse(ApiConstants.moduleEnrollments(moduleId)),
      headers: _headers(token),
    );
    return _parse(res)['enrollments'] as List? ?? [];
  }

  // ── Platform Users (student_users) — admin roster + activity drill-down ──

  static Future<List<dynamic>> getPlatformUsers() async {
    final token = await _token();
    final res = await safeGet(
      Uri.parse(ApiConstants.platformUsers()),
      headers: _headers(token),
    );
    return _parse(res)['students'] as List? ?? [];
  }

  static Future<Map<String, dynamic>> getPlatformUserActivity(int id) async {
    final token = await _token();
    final res = await safeGet(
      Uri.parse(ApiConstants.platformUserActivity(id)),
      headers: _headers(token),
    );
    return _parse(res);
  }

  // ── Institute Onboarding Enquiries ──────────────────────────────────────

  static Future<Map<String, dynamic>> submitEnquiry(Map<String, dynamic> body) async {
    final res = await safePost(
      Uri.parse(ApiConstants.enquiries()),
      headers: _headers(),
      body: jsonEncode(body),
    );
    return _parse(res);
  }

  static Future<List<dynamic>> getEnquiriesAdmin() async {
    final token = await _token();
    final res = await safeGet(
      Uri.parse(ApiConstants.enquiriesAdmin()),
      headers: _headers(token),
    );
    return _parse(res)['enquiries'] as List? ?? [];
  }

  static Future<Map<String, dynamic>> updateEnquiryStatus(int id, String status) async {
    final token = await _token();
    final res = await http.put(
      Uri.parse(ApiConstants.enquiryAdminItem(id)),
      headers: _headers(token),
      body: jsonEncode({'status': status}),
    );
    return _parse(res);
  }

  // ── AI Mock Interview ────────────────────────────────────────────────────

  static Future<String?> _studentToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('student_token');
  }

  static Future<List<dynamic>> getMockInterviewRoles() async {
    final res = await safeGet(Uri.parse(ApiConstants.mockInterviewRoles()));
    return _parse(res)['roles'] as List? ?? [];
  }

  static Future<Map<String, dynamic>> startMockInterview(String role, {int questionCount = 5}) async {
    final token = await _studentToken();
    final res = await safePost(
      Uri.parse(ApiConstants.mockInterviewStart()),
      headers: _headers(token),
      body: jsonEncode({'role': role, 'question_count': questionCount}),
    );
    return _parse(res);
  }

  static Future<Map<String, dynamic>> submitMockInterviewAnswer(
      int sessionId, int questionId, String answer) async {
    final token = await _studentToken();
    final res = await safePost(
      Uri.parse(ApiConstants.mockInterviewAnswer(sessionId)),
      headers: _headers(token),
      body: jsonEncode({'question_id': questionId, 'answer': answer}),
    );
    return _parse(res);
  }

  static Future<Map<String, dynamic>> finishMockInterview(int sessionId) async {
    final token = await _studentToken();
    final res = await safePost(
      Uri.parse(ApiConstants.mockInterviewFinish(sessionId)),
      headers: _headers(token),
    );
    return _parse(res);
  }

  static Future<List<dynamic>> getMockInterviewHistory() async {
    final token = await _studentToken();
    final res = await safeGet(
      Uri.parse(ApiConstants.mockInterviewHistory()),
      headers: _headers(token),
    );
    return _parse(res)['sessions'] as List? ?? [];
  }

  static Future<Map<String, dynamic>> getMockInterviewSession(int sessionId) async {
    final token = await _studentToken();
    final res = await safeGet(
      Uri.parse(ApiConstants.mockInterviewSession(sessionId)),
      headers: _headers(token),
    );
    return _parse(res);
  }

  // ── Subscription Plans (pricing page) ───────────────────────────────────

  static Future<List<dynamic>> getSubscriptionPlans() async {
    final res = await safeGet(Uri.parse(ApiConstants.subscriptionPlans()));
    return _parse(res)['plans'] as List? ?? [];
  }

  static Future<List<dynamic>> getSubscriptionPlansAdmin() async {
    final token = await _token();
    final res = await safeGet(
      Uri.parse(ApiConstants.subscriptionPlansAdmin()),
      headers: _headers(token),
    );
    return _parse(res)['plans'] as List? ?? [];
  }

  static Future<Map<String, dynamic>> updateSubscriptionPlan(
      String tierKey, Map<String, dynamic> body) async {
    final token = await _token();
    final res = await http.put(
      Uri.parse(ApiConstants.subscriptionPlanAdmin(tierKey)),
      headers: _headers(token),
      body: jsonEncode(body),
    );
    return _parse(res);
  }

  // ── Student Activity Summary ────────────────────────────────────────────

  /// AI practice tests have no `tests` row, so a finished one is recorded
  /// here rather than through submitAttempt.
  static Future<void> recordPracticeAttempt(Map<String, dynamic> body) async {
    final token = await _studentToken();
    await http.post(
      Uri.parse(ApiConstants.practiceAttempts()),
      headers: _headers(token),
      body: jsonEncode(body),
    );
  }

  static Future<List<dynamic>> getPracticeAttempts() async {
    final token = await _studentToken();
    final res = await safeGet(
      Uri.parse(ApiConstants.practiceAttempts()),
      headers: _headers(token),
    );
    return _parse(res)['attempts'] as List? ?? [];
  }

  static Future<Map<String, dynamic>> getStudentActivitySummary() async {
    final token = await _studentToken();
    final res = await safeGet(
      Uri.parse(ApiConstants.studentActivitySummary()),
      headers: _headers(token),
    );
    return _parse(res);
  }

  // ── Challenges ────────────────────────────────────────────────────────────

  static Future<List<dynamic>> getChallenges() async {
    final token = await _studentToken();
    final res = await safeGet(Uri.parse(ApiConstants.challenges()), headers: _headers(token));
    return _parse(res)['challenges'] as List? ?? [];
  }

  static Future<Map<String, dynamic>> getChallenge(int id) async {
    final token = await _studentToken();
    final res = await safeGet(Uri.parse(ApiConstants.challenge(id)), headers: _headers(token));
    return _parse(res);
  }

  static Future<Map<String, dynamic>> submitChallenge(int id, {
    required String name, String submissionText = '', String submissionUrl = '',
  }) async {
    final token = await _studentToken();
    final res = await safePost(
      Uri.parse(ApiConstants.challengeSubmit(id)),
      headers: _headers(token),
      body: jsonEncode({'name': name, 'submission_text': submissionText, 'submission_url': submissionUrl}),
    );
    return _parse(res);
  }

  static Future<List<dynamic>> getMyChallengeSubmissions() async {
    final token = await _studentToken();
    final res = await safeGet(Uri.parse(ApiConstants.myChallengeSubmissions()), headers: _headers(token));
    return _parse(res)['submissions'] as List? ?? [];
  }

  static Future<List<dynamic>> getChallengesAdmin() async {
    final token = await _token();
    final res = await safeGet(Uri.parse(ApiConstants.challengesAdmin()), headers: _headers(token));
    return _parse(res)['challenges'] as List? ?? [];
  }

  static Future<Map<String, dynamic>> createChallenge(Map<String, dynamic> body) async {
    final token = await _token();
    final res = await safePost(
      Uri.parse(ApiConstants.challengeAdminCreate()),
      headers: _headers(token),
      body: jsonEncode(body),
    );
    return _parse(res);
  }

  static Future<Map<String, dynamic>> updateChallenge(int id, Map<String, dynamic> body) async {
    final token = await _token();
    final res = await http.put(
      Uri.parse(ApiConstants.challengeAdminItem(id)),
      headers: _headers(token),
      body: jsonEncode(body),
    );
    return _parse(res);
  }

  static Future<void> deleteChallenge(int id) async {
    final token = await _token();
    final res = await http.delete(Uri.parse(ApiConstants.challengeAdminItem(id)), headers: _headers(token));
    _parse(res);
  }

  static Future<List<dynamic>> getChallengeSubmissionsAdmin(int challengeId) async {
    final token = await _token();
    final res = await safeGet(Uri.parse(ApiConstants.challengeAdminSubmissions(challengeId)), headers: _headers(token));
    return _parse(res)['submissions'] as List? ?? [];
  }

  static Future<Map<String, dynamic>> reviewChallengeSubmission(int submissionId, Map<String, dynamic> body) async {
    final token = await _token();
    final res = await http.put(
      Uri.parse(ApiConstants.challengeAdminReviewSubmission(submissionId)),
      headers: _headers(token),
      body: jsonEncode(body),
    );
    return _parse(res);
  }

  // ── Home strip + activity feed ──────────────────────────────────────────

  static Future<List<dynamic>> getHomeStrip() async {
    final res = await safeGet(Uri.parse(ApiConstants.homeStrip()));
    return _parse(res)['items'] as List? ?? [];
  }

  static Future<List<dynamic>> getHomeStripAdmin() async {
    final token = await _token();
    final res = await safeGet(Uri.parse(ApiConstants.homeStripAdmin()), headers: _headers(token));
    return _parse(res)['items'] as List? ?? [];
  }

  static Future<Map<String, dynamic>> createHomeStripItem(Map<String, dynamic> body) async {
    final token = await _token();
    final res = await safePost(Uri.parse(ApiConstants.homeStripAdmin()), headers: _headers(token), body: jsonEncode(body));
    return _parse(res);
  }

  static Future<Map<String, dynamic>> updateHomeStripItem(int id, Map<String, dynamic> body) async {
    final token = await _token();
    final res = await http.put(Uri.parse(ApiConstants.homeStripAdminItem(id)), headers: _headers(token), body: jsonEncode(body));
    return _parse(res);
  }

  static Future<void> deleteHomeStripItem(int id) async {
    final token = await _token();
    final res = await http.delete(Uri.parse(ApiConstants.homeStripAdminItem(id)), headers: _headers(token));
    _parse(res);
  }

  static Future<List<dynamic>> getActivityFeed({int limit = 15}) async {
    final res = await safeGet(Uri.parse(ApiConstants.activityFeed(limit: limit)));
    return _parse(res)['activity'] as List? ?? [];
  }

  static Future<List<dynamic>> getActivityFeedAdmin({int limit = 30}) async {
    final token = await _token();
    final res = await safeGet(Uri.parse(ApiConstants.activityFeedAdmin(limit: limit)), headers: _headers(token));
    return _parse(res)['activity'] as List? ?? [];
  }
}
