class ApiConstants {
  // Production-grade: configurable via --dart-define for different environments
  // Example: flutter build web --release --dart-define=API_BASE_URL=https://your-staging.up.railway.app
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://altrocoach-backend-production.up.railway.app',
  );
  static const botkoUrl = 'https://botko-api-production-8da7.up.railway.app';

  // institutes
  static String registerInstitute() => '$baseUrl/institutes/register';
  static String brand(String slug) => '$baseUrl/institute/brand/$slug';
  static String instituteBrand(int id) => '$baseUrl/institutes/$id/brand';
  static String dashboard(int id) => '$baseUrl/institutes/$id/dashboard';
  static String analytics(int id) => '$baseUrl/institutes/$id/analytics';

  // students
  static String students(int id) => '$baseUrl/institutes/$id/students';
  static String student(int id) => '$baseUrl/students/$id';
  static String studentFees(int id) => '$baseUrl/students/$id/fees';
  static String bulkImport(int id) => '$baseUrl/institutes/$id/students/bulk-json';
  static String studentAnalytics(int id) => '$baseUrl/students/$id/analytics';

  // batches
  static String batches(int id) => '$baseUrl/institutes/$id/batches';
  static String batch(int id) => '$baseUrl/batches/$id';

  // tests
  static String generateTest() => '$baseUrl/tests/generate';
  static String tests(int id) => '$baseUrl/institutes/$id/tests';
  static String test(int id) => '$baseUrl/tests/$id';
  static String testAttempt(int id) => '$baseUrl/tests/$id/attempt';
  static String testResults(int id) => '$baseUrl/tests/$id/results';

  // attendance
  static String markAttendance(int batchId) => '$baseUrl/batches/$batchId/attendance';
  static String batchQrToken(int batchId) => '$baseUrl/batches/$batchId/qr-token';
  static String qrCheckin() => '$baseUrl/attendance/checkin';
  static String getAttendance(int batchId, String date) =>
      '$baseUrl/batches/$batchId/attendance/$date';

  // fees
  static String fees(int id) => '$baseUrl/institutes/$id/fees';
  static String pendingFees(int id) => '$baseUrl/institutes/$id/fees/pending';
  static String markPaid(int id) => '$baseUrl/fees/$id/mark-paid';
  static String feePaymentLink(int id) => '$baseUrl/fees/$id/payment-link';
  static String feeVerifyPayment(int id) => '$baseUrl/fees/$id/verify-payment';
  static String instituteSubscribe(int id) => '$baseUrl/institutes/$id/subscribe';

  // notify
  static String broadcast() => '$baseUrl/notify/broadcast';
  static String feeReminder() => '$baseUrl/notify/fee-reminder';
  static String testResultNotify() => '$baseUrl/notify/test-result';

  // manager
  static String managerLogin() => '$baseUrl/manager/login';
  static String managerMe() => '$baseUrl/manager/me';
  static String managers(int id) => '$baseUrl/institutes/$id/managers';

  // super admin
  static String superSetup() => '$baseUrl/super/setup';
  static String superLogin() => '$baseUrl/super/login';
  static String superDebugAutoLogin() => '$baseUrl/super/debug/auto-login';
  static String superInstitutes() => '$baseUrl/super/institutes';
  static String superStats() => '$baseUrl/super/stats';
  static String superRevenue() => '$baseUrl/super/revenue';
  static String superRequestOtp() => '$baseUrl/super/request-otp';
  static String superVerifyOtp() => '$baseUrl/super/verify-otp';
  static String superInstituteDetail(int id) => '$baseUrl/super/institutes/$id';
  static String superInstitutePayments(int id) => '$baseUrl/super/institutes/$id/payments';
  static String superRecordPayment(int id) => '$baseUrl/super/institutes/$id/payment';
  static String superChangePlan(int id) => '$baseUrl/super/institutes/$id/plan';
  static String superAutoSuspend() => '$baseUrl/super/auto-suspend';

  // commissions
  static String commissionSummary() => '$baseUrl/super/commissions/summary';
  static String commissions() => '$baseUrl/super/commissions/';
  static String calculateCommissions() => '$baseUrl/super/commissions/calculate';
  static String markCommissionPaid(int id) => '$baseUrl/super/commissions/$id/mark-paid';

  // auth
  static String login() => '$baseUrl/auth/login';
  static String debugAutoLogin() => '$baseUrl/auth/debug/auto-login';
  static String register() => '$baseUrl/auth/register';
  static String logout() => '$baseUrl/auth/logout';
  static String me() => '$baseUrl/auth/me';
  static String forgotPassword() => '$baseUrl/auth/forgot-password';
  static String resetPassword() => '$baseUrl/auth/reset-password';
  static String requestOtp() => '$baseUrl/auth/request-otp';
  static String verifyOtp() => '$baseUrl/auth/verify-otp';

  // student auth
  static String studentRegister() => '$baseUrl/student/register';
  static String studentLogin() => '$baseUrl/student/login';
  static String studentFeed() => '$baseUrl/student/feed';
  static String studentMe() => '$baseUrl/student/me';
  static String studentLogout() => '$baseUrl/student/logout';
  static String studentRequestOtp() => '$baseUrl/student/request-otp';
  static String studentLinkCoaching() => '$baseUrl/student/link-coaching';
  static String standaloneRequestOtp() => '$baseUrl/student/standalone/request-otp';
  static String standaloneVerifyOtp() => '$baseUrl/student/standalone/verify-otp';
  static String onboardingConfig() => '$baseUrl/platform/onboarding-config';

  // student subscription
  static String studentSubscription() => '$baseUrl/student/subscription';
  static String studentSubscribe() => '$baseUrl/student/subscribe';
  static String studentSubscriptionVerify() => '$baseUrl/student/subscription/verify';

  // student self-practice generation
  static String studentGenerateTest() => '$baseUrl/student/tests/generate';

  // institute AI generation usage (admin quota meter)
  static String instituteGenerationUsage(int id) =>
      '$baseUrl/institutes/$id/generation-usage';

  // super admin — settings & incentives
  static String superSettings() => '$baseUrl/super/settings';
  static String superSettingUpdate(String key) => '$baseUrl/super/settings/$key';
  static String superIncentives() => '$baseUrl/super/incentives';

  // push notifications
  static String pushRegister() => '$baseUrl/push/register';
  static String pushUnregister() => '$baseUrl/push/unregister';
  static String pushPrefs() => '$baseUrl/push/prefs';
  static String pushSend() => '$baseUrl/push/send';

  // institute extras
  static String instituteCode(int id) => '$baseUrl/institutes/$id/code';
  static String instituteProfile(int id) => '$baseUrl/institutes/$id/profile';
  static String instituteSubscription(int id) => '$baseUrl/institutes/$id/subscription';
  static String instituteSettings(int id) => '$baseUrl/institutes/$id/settings';
  static String publishTest(int id) => '$baseUrl/tests/$id/publish';
  static String deleteTest(int id) => '$baseUrl/tests/$id';
  static String notices(int id) => '$baseUrl/institutes/$id/notices';

  // training modules
  static String trainingModules(int id) =>
      '$baseUrl/institutes/$id/training-modules';
  static String trainingModule(int id) => '$baseUrl/training-modules/$id';
  static String trainingModuleTopics(int moduleId) =>
      '$baseUrl/training-modules/$moduleId/topics';
  static String trainingModuleTopic(int topicId) =>
      '$baseUrl/training-modules/topics/$topicId';
  static String trainingModuleSubtopics(int topicId) =>
      '$baseUrl/training-modules/topics/$topicId/subtopics';
  static String trainingModuleSubtopic(int subtopicId) =>
      '$baseUrl/training-modules/subtopics/$subtopicId';
  static String trainingModuleContent(int subtopicId) =>
      '$baseUrl/training-modules/subtopics/$subtopicId/content';
  static String trainingModuleContentItem(int contentId) =>
      '$baseUrl/training-modules/content/$contentId';
  static String moduleProgress(int moduleId) =>
      '$baseUrl/training-modules/$moduleId/progress';
  static String markContentComplete(int contentId) =>
      '$baseUrl/training-modules/content/$contentId/complete';
}
