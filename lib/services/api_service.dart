import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
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
        if (token != null) 'Authorization': 'Bearer $token',
      };

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
      {Map<String, String>? headers}) async {
    try {
      return await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 15));
    } on SocketException {
      throw ApiException('No internet connection. Check your network.');
    } on HttpException {
      throw ApiException('Server unreachable. Try again later.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Connection failed. Please try again.');
    }
  }

  static Future<http.Response> safePost(Uri uri,
      {Map<String, String>? headers, Object? body}) async {
    try {
      return await http
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 20));
    } on SocketException {
      throw ApiException('No internet connection. Check your network.');
    } on HttpException {
      throw ApiException('Server unreachable. Try again later.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Connection failed. Please try again.');
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

  static Future<Map<String, dynamic>> submitAttempt(
      int testId, Map<String, dynamic> body) async {
    final res = await http.post(
      Uri.parse(ApiConstants.testAttempt(testId)),
      headers: _headers(),
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

  static Future<Map<String, dynamic>> createStudentSubscriptionLink() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('student_token') ?? prefs.getString('token');
    final res = await http.post(
      Uri.parse(ApiConstants.studentSubscribe()),
      headers: _headers(token),
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
    final res = await http.get(
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
    final res = await http.get(Uri.parse(ApiConstants.brand(slug)));
    return _parse(res);
  }

  static Future<Map<String, dynamic>> getInstituteBrand(int instituteId) async {
    final token = await _token();
    final res = await http.get(
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
    final res = await http.get(
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
      String linkUrl = ''}) async {
    final token = await _token();
    final params = <String, String>{
      'title': title,
      'content': content,
      'type': type
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
    final res = await http.get(
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
    final res = await http.get(
      Uri.parse(ApiConstants.getAttendance(batchId, date)),
      headers: _headers(token),
    );
    return _parse(res);
  }

  // Fees
  static Future<List<dynamic>> getPendingFees(int instituteId) async {
    final token = await _token();
    final res = await http.get(
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
    final res = await http.get(Uri.parse(url), headers: _headers(token));
    final data = _parse(res);
    return data['fees'] as List;
  }

  static Future<List<dynamic>> getStudentFees(int studentId) async {
    final token = await _token();
    final res = await http.get(
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
    final res = await http.get(
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
}
