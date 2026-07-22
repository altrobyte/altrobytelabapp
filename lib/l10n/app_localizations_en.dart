// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get navDashboard => 'Dashboard';

  @override
  String get navStudents => 'Students';

  @override
  String get navBatches => 'Batches';

  @override
  String get navTestGenerator => 'Test Generator';

  @override
  String get navAttendance => 'Attendance';

  @override
  String get navFeeManagement => 'Fee Management';

  @override
  String get navAnalytics => 'Analytics';

  @override
  String get navBroadcast => 'Broadcast';

  @override
  String get navSettings => 'Settings';

  @override
  String get navLogout => 'Logout';

  @override
  String get roleAdmin => 'Admin';

  @override
  String get roleManager => 'Manager';

  @override
  String get roleSuperAdmin => 'Super Admin';

  @override
  String get poweredByAltrobyte => 'Powered by Altrobyte';

  @override
  String get dashboardTitle => 'Dashboard';

  @override
  String dashboardWelcome(String name) {
    return 'Welcome, $name!';
  }

  @override
  String get dashboardRecentActivity => 'Recent Activity';

  @override
  String get dashboardNoActivity => 'No recent activity';

  @override
  String get dashboardQuickActions => 'Quick Actions';

  @override
  String get statsTotalStudents => 'Total Students';

  @override
  String get statsActiveBatches => 'Active Batches';

  @override
  String get statsFeePending => 'Fee Pending';

  @override
  String get statsTestsToday => 'Tests Today';

  @override
  String get statsEnrolledStudents => 'Enrolled students';

  @override
  String get statsRunningBatches => 'Running batches';

  @override
  String get statsStudentsPending => 'Students pending';

  @override
  String get statsGeneratedToday => 'Generated today';

  @override
  String get actionAddStudent => 'Add Student';

  @override
  String get actionGenerateTest => 'Generate Test';

  @override
  String get actionMarkAttendance => 'Mark Attendance';

  @override
  String get actionManageFees => 'Manage Fees';

  @override
  String get actionBroadcast => 'Broadcast';

  @override
  String get bottomNavHome => 'Home';

  @override
  String get bottomNavStudents => 'Students';

  @override
  String get bottomNavTests => 'Tests';

  @override
  String get bottomNavAttendance => 'Attend.';

  @override
  String get bottomNavSettings => 'Settings';

  @override
  String get testGenTabGenerate => 'Generate';

  @override
  String get testGenTabMyTests => 'My Tests';

  @override
  String get testGenAITitle => 'AI Test Generator';

  @override
  String get testGenAIPowered => 'Powered by Altron AI';

  @override
  String get testGenTestTitle => 'Test Title (optional)';

  @override
  String get testGenTestTitleHint => 'e.g. SSC GD Mock Test 1';

  @override
  String get testGenSubject => 'Subject *';

  @override
  String get testGenTopic => 'Topic';

  @override
  String get testGenTopicHint => 'e.g. Percentage & Profit Loss';

  @override
  String get testGenTopicHelper => 'Leave empty for random topics';

  @override
  String get testGenDifficulty => 'Difficulty';

  @override
  String get testGenExamPattern => 'Exam Pattern';

  @override
  String get testGenQuestionCount => 'Number of Questions';

  @override
  String get testGenBatch => 'Batch (for sending)';

  @override
  String get testGenNoBatch => 'No specific batch';

  @override
  String get testGenLanguage => 'Test Language';

  @override
  String get testGenLangHindi => 'Hindi (हिंदी)';

  @override
  String get testGenLangEnglish => 'English';

  @override
  String get testGenLangBoth => 'Both (Bilingual)';

  @override
  String get testGenGenerateBtn => 'Generate Test with AI';

  @override
  String get testGenGenerating => 'AI is generating questions...';

  @override
  String get testGenEmptyTitle => 'Configure and generate your test';

  @override
  String get testGenEmptySubtitle => 'AI will create questions in seconds!';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsInstituteName => 'Institute Name';

  @override
  String get settingsInstituteId => 'Institute ID';

  @override
  String get settingsNotSet => 'Not set';

  @override
  String get settingsEnrollmentCode => 'Student Enrollment Code';

  @override
  String get settingsEnrollmentCodeSubtitle =>
      'Share this code with students so they can join your institute.';

  @override
  String get settingsAiTutorNumber => 'AI Tutor WhatsApp Number';

  @override
  String get settingsAiTutorSubtitle =>
      'Students will be redirected to this number when they tap \"Chat with AI\". Enter with country code (e.g. 919876543210).';

  @override
  String get settingsPhoneWithCode => 'Phone number with country code';

  @override
  String get settingsWaSaved => 'WhatsApp number saved!';

  @override
  String get settingsLanguage => 'Language / भाषा';

  @override
  String get settingsLangEnglish => 'English';

  @override
  String get settingsLangHindi => 'हिंदी';

  @override
  String get settingsLogout => 'Logout';

  @override
  String get settingsVersion => 'v1.0.0 • Powered by Altrobyte Automation';

  @override
  String get settingsCodeCopied => 'Code copied to clipboard!';

  @override
  String get settingsSave => 'Save';

  @override
  String get settingsProfile => 'Institute Profile';

  @override
  String get settingsOwnerName => 'Owner Name';

  @override
  String get settingsOwnerPhone => 'Phone Number';

  @override
  String get settingsEmail => 'Email';

  @override
  String get settingsCity => 'City';

  @override
  String get settingsEditProfile => 'Edit Profile';

  @override
  String get settingsProfileSaved => 'Profile updated!';

  @override
  String get settingsNoticeTitle => 'Post a Notice';

  @override
  String get settingsNoticeSubtitle =>
      'Send an announcement to all your students. It appears in their app instantly.';

  @override
  String get settingsNoticeHeading => 'Notice title';

  @override
  String get settingsNoticeBody => 'Details (optional)';

  @override
  String get settingsNoticeSend => 'Post Notice';

  @override
  String get settingsNoticeSent => 'Notice posted to students!';

  @override
  String get settingsHelp => 'Help & About';

  @override
  String get settingsContactSupport => 'Contact Support';

  @override
  String get settingsPrivacyPolicy => 'Privacy Policy';

  @override
  String get settingsDeleteAccount => 'Delete Account';

  @override
  String get settingsAppVersion => 'App Version';

  @override
  String get broadcastTitle => 'Broadcast';

  @override
  String get broadcastAllStudents => 'All Students';

  @override
  String get broadcastSelectBatch => 'Select Batch';

  @override
  String get broadcastMessage => 'Message';

  @override
  String get broadcastSend => 'Send';

  @override
  String get broadcastTemplateTestReminder => 'Test Reminder';

  @override
  String get broadcastTemplateFeeReminder => 'Fee Reminder';

  @override
  String get broadcastTemplateResult => 'Result';

  @override
  String get broadcastTemplateHoliday => 'Holiday';

  @override
  String get studentPortalTestsAvailable => 'Tests Available';

  @override
  String get studentPortalRecentResults => 'Recent Results';

  @override
  String get studentPortalNotices => 'Notices';

  @override
  String get studentPortalNothingYet => 'Nothing here yet';

  @override
  String get studentPortalNothingYetSubtitle =>
      'Your teacher will publish tests and notices here.';

  @override
  String get studentPortalChatAI => 'Chat with AI';

  @override
  String get studentPortalAskAI => 'Ask AI Tutor';

  @override
  String get studentPortalAskAISubtitle => 'Get instant help on WhatsApp';

  @override
  String get studentPortalErrorLoad =>
      'Failed to load feed. Check your connection.';

  @override
  String get studentPortalRetry => 'Retry';

  @override
  String get studentPortalMin => 'min';

  @override
  String get commonSave => 'Save';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonSend => 'Send';

  @override
  String get navTrainingModules => 'Training Modules';

  @override
  String get trainingModulesTitle => 'Training Modules';

  @override
  String get trainingModulesNew => 'New Module';

  @override
  String get trainingModulesEmpty => 'No Training Modules Yet';

  @override
  String get trainingModulesEmptySubtitle =>
      'Create your first module to organize notes, tests, and videos for your students.';

  @override
  String get trainingModulesPublished => 'Published';

  @override
  String get trainingModulesDraft => 'Draft';

  @override
  String get trainingModulesTopics => 'Topics';

  @override
  String get trainingModulesSubtopics => 'Subtopics';

  @override
  String get trainingModulesItems => 'Items';

  @override
  String get trainingModulesAddTopic => 'Add Topic';

  @override
  String get trainingModulesAddSubtopic => 'Add Subtopic';

  @override
  String get trainingModulesAddContent => 'Add Content';

  @override
  String get trainingModulesNotes => 'Notes';

  @override
  String get trainingModulesTest => 'Test Series';

  @override
  String get trainingModulesVideo => 'YouTube Video';

  @override
  String get trainingModulesYourPath => 'Your Learning Path';

  @override
  String get trainingModulesCompleted => 'completed';
}
