import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('hi')
  ];

  /// No description provided for @navDashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get navDashboard;

  /// No description provided for @navStudents.
  ///
  /// In en, this message translates to:
  /// **'Students'**
  String get navStudents;

  /// No description provided for @navBatches.
  ///
  /// In en, this message translates to:
  /// **'Batches'**
  String get navBatches;

  /// No description provided for @navTestGenerator.
  ///
  /// In en, this message translates to:
  /// **'Test Generator'**
  String get navTestGenerator;

  /// No description provided for @navAttendance.
  ///
  /// In en, this message translates to:
  /// **'Attendance'**
  String get navAttendance;

  /// No description provided for @navFeeManagement.
  ///
  /// In en, this message translates to:
  /// **'Fee Management'**
  String get navFeeManagement;

  /// No description provided for @navAnalytics.
  ///
  /// In en, this message translates to:
  /// **'Analytics'**
  String get navAnalytics;

  /// No description provided for @navBroadcast.
  ///
  /// In en, this message translates to:
  /// **'Broadcast'**
  String get navBroadcast;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @navLogout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get navLogout;

  /// No description provided for @roleAdmin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get roleAdmin;

  /// No description provided for @roleManager.
  ///
  /// In en, this message translates to:
  /// **'Manager'**
  String get roleManager;

  /// No description provided for @roleSuperAdmin.
  ///
  /// In en, this message translates to:
  /// **'Super Admin'**
  String get roleSuperAdmin;

  /// No description provided for @poweredByAltrobyte.
  ///
  /// In en, this message translates to:
  /// **'Powered by Altrobyte'**
  String get poweredByAltrobyte;

  /// No description provided for @dashboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboardTitle;

  /// No description provided for @dashboardWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome, {name}!'**
  String dashboardWelcome(String name);

  /// No description provided for @dashboardRecentActivity.
  ///
  /// In en, this message translates to:
  /// **'Recent Activity'**
  String get dashboardRecentActivity;

  /// No description provided for @dashboardNoActivity.
  ///
  /// In en, this message translates to:
  /// **'No recent activity'**
  String get dashboardNoActivity;

  /// No description provided for @dashboardQuickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get dashboardQuickActions;

  /// No description provided for @statsTotalStudents.
  ///
  /// In en, this message translates to:
  /// **'Total Students'**
  String get statsTotalStudents;

  /// No description provided for @statsActiveBatches.
  ///
  /// In en, this message translates to:
  /// **'Active Batches'**
  String get statsActiveBatches;

  /// No description provided for @statsFeePending.
  ///
  /// In en, this message translates to:
  /// **'Fee Pending'**
  String get statsFeePending;

  /// No description provided for @statsTestsToday.
  ///
  /// In en, this message translates to:
  /// **'Tests Today'**
  String get statsTestsToday;

  /// No description provided for @statsEnrolledStudents.
  ///
  /// In en, this message translates to:
  /// **'Enrolled students'**
  String get statsEnrolledStudents;

  /// No description provided for @statsRunningBatches.
  ///
  /// In en, this message translates to:
  /// **'Running batches'**
  String get statsRunningBatches;

  /// No description provided for @statsStudentsPending.
  ///
  /// In en, this message translates to:
  /// **'Students pending'**
  String get statsStudentsPending;

  /// No description provided for @statsGeneratedToday.
  ///
  /// In en, this message translates to:
  /// **'Generated today'**
  String get statsGeneratedToday;

  /// No description provided for @actionAddStudent.
  ///
  /// In en, this message translates to:
  /// **'Add Student'**
  String get actionAddStudent;

  /// No description provided for @actionGenerateTest.
  ///
  /// In en, this message translates to:
  /// **'Generate Test'**
  String get actionGenerateTest;

  /// No description provided for @actionMarkAttendance.
  ///
  /// In en, this message translates to:
  /// **'Mark Attendance'**
  String get actionMarkAttendance;

  /// No description provided for @actionManageFees.
  ///
  /// In en, this message translates to:
  /// **'Manage Fees'**
  String get actionManageFees;

  /// No description provided for @actionBroadcast.
  ///
  /// In en, this message translates to:
  /// **'Broadcast'**
  String get actionBroadcast;

  /// No description provided for @bottomNavHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get bottomNavHome;

  /// No description provided for @bottomNavStudents.
  ///
  /// In en, this message translates to:
  /// **'Students'**
  String get bottomNavStudents;

  /// No description provided for @bottomNavTests.
  ///
  /// In en, this message translates to:
  /// **'Tests'**
  String get bottomNavTests;

  /// No description provided for @bottomNavAttendance.
  ///
  /// In en, this message translates to:
  /// **'Attend.'**
  String get bottomNavAttendance;

  /// No description provided for @bottomNavSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get bottomNavSettings;

  /// No description provided for @testGenTabGenerate.
  ///
  /// In en, this message translates to:
  /// **'Generate'**
  String get testGenTabGenerate;

  /// No description provided for @testGenTabMyTests.
  ///
  /// In en, this message translates to:
  /// **'My Tests'**
  String get testGenTabMyTests;

  /// No description provided for @testGenAITitle.
  ///
  /// In en, this message translates to:
  /// **'AI Test Generator'**
  String get testGenAITitle;

  /// No description provided for @testGenAIPowered.
  ///
  /// In en, this message translates to:
  /// **'Powered by Altron AI'**
  String get testGenAIPowered;

  /// No description provided for @testGenTestTitle.
  ///
  /// In en, this message translates to:
  /// **'Test Title (optional)'**
  String get testGenTestTitle;

  /// No description provided for @testGenTestTitleHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. SSC GD Mock Test 1'**
  String get testGenTestTitleHint;

  /// No description provided for @testGenSubject.
  ///
  /// In en, this message translates to:
  /// **'Subject *'**
  String get testGenSubject;

  /// No description provided for @testGenTopic.
  ///
  /// In en, this message translates to:
  /// **'Topic'**
  String get testGenTopic;

  /// No description provided for @testGenTopicHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Percentage & Profit Loss'**
  String get testGenTopicHint;

  /// No description provided for @testGenTopicHelper.
  ///
  /// In en, this message translates to:
  /// **'Leave empty for random topics'**
  String get testGenTopicHelper;

  /// No description provided for @testGenDifficulty.
  ///
  /// In en, this message translates to:
  /// **'Difficulty'**
  String get testGenDifficulty;

  /// No description provided for @testGenExamPattern.
  ///
  /// In en, this message translates to:
  /// **'Exam Pattern'**
  String get testGenExamPattern;

  /// No description provided for @testGenQuestionCount.
  ///
  /// In en, this message translates to:
  /// **'Number of Questions'**
  String get testGenQuestionCount;

  /// No description provided for @testGenBatch.
  ///
  /// In en, this message translates to:
  /// **'Batch (for sending)'**
  String get testGenBatch;

  /// No description provided for @testGenNoBatch.
  ///
  /// In en, this message translates to:
  /// **'No specific batch'**
  String get testGenNoBatch;

  /// No description provided for @testGenLanguage.
  ///
  /// In en, this message translates to:
  /// **'Test Language'**
  String get testGenLanguage;

  /// No description provided for @testGenLangHindi.
  ///
  /// In en, this message translates to:
  /// **'Hindi (हिंदी)'**
  String get testGenLangHindi;

  /// No description provided for @testGenLangEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get testGenLangEnglish;

  /// No description provided for @testGenLangBoth.
  ///
  /// In en, this message translates to:
  /// **'Both (Bilingual)'**
  String get testGenLangBoth;

  /// No description provided for @testGenGenerateBtn.
  ///
  /// In en, this message translates to:
  /// **'Generate Test with AI'**
  String get testGenGenerateBtn;

  /// No description provided for @testGenGenerating.
  ///
  /// In en, this message translates to:
  /// **'AI is generating questions...'**
  String get testGenGenerating;

  /// No description provided for @testGenEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Configure and generate your test'**
  String get testGenEmptyTitle;

  /// No description provided for @testGenEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'AI will create questions in seconds!'**
  String get testGenEmptySubtitle;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsInstituteName.
  ///
  /// In en, this message translates to:
  /// **'Institute Name'**
  String get settingsInstituteName;

  /// No description provided for @settingsInstituteId.
  ///
  /// In en, this message translates to:
  /// **'Institute ID'**
  String get settingsInstituteId;

  /// No description provided for @settingsNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get settingsNotSet;

  /// No description provided for @settingsEnrollmentCode.
  ///
  /// In en, this message translates to:
  /// **'Student Enrollment Code'**
  String get settingsEnrollmentCode;

  /// No description provided for @settingsEnrollmentCodeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Share this code with students so they can join your institute.'**
  String get settingsEnrollmentCodeSubtitle;

  /// No description provided for @settingsAiTutorNumber.
  ///
  /// In en, this message translates to:
  /// **'AI Tutor WhatsApp Number'**
  String get settingsAiTutorNumber;

  /// No description provided for @settingsAiTutorSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Students will be redirected to this number when they tap \"Chat with AI\". Enter with country code (e.g. 919876543210).'**
  String get settingsAiTutorSubtitle;

  /// No description provided for @settingsPhoneWithCode.
  ///
  /// In en, this message translates to:
  /// **'Phone number with country code'**
  String get settingsPhoneWithCode;

  /// No description provided for @settingsWaSaved.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp number saved!'**
  String get settingsWaSaved;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language / भाषा'**
  String get settingsLanguage;

  /// No description provided for @settingsLangEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get settingsLangEnglish;

  /// No description provided for @settingsLangHindi.
  ///
  /// In en, this message translates to:
  /// **'हिंदी'**
  String get settingsLangHindi;

  /// No description provided for @settingsLogout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get settingsLogout;

  /// No description provided for @settingsVersion.
  ///
  /// In en, this message translates to:
  /// **'v1.0.0 • Powered by Altrobyte Automation'**
  String get settingsVersion;

  /// No description provided for @settingsCodeCopied.
  ///
  /// In en, this message translates to:
  /// **'Code copied to clipboard!'**
  String get settingsCodeCopied;

  /// No description provided for @settingsSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get settingsSave;

  /// No description provided for @settingsProfile.
  ///
  /// In en, this message translates to:
  /// **'Institute Profile'**
  String get settingsProfile;

  /// No description provided for @settingsOwnerName.
  ///
  /// In en, this message translates to:
  /// **'Owner Name'**
  String get settingsOwnerName;

  /// No description provided for @settingsOwnerPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get settingsOwnerPhone;

  /// No description provided for @settingsEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get settingsEmail;

  /// No description provided for @settingsCity.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get settingsCity;

  /// No description provided for @settingsEditProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get settingsEditProfile;

  /// No description provided for @settingsProfileSaved.
  ///
  /// In en, this message translates to:
  /// **'Profile updated!'**
  String get settingsProfileSaved;

  /// No description provided for @settingsNoticeTitle.
  ///
  /// In en, this message translates to:
  /// **'Post a Notice'**
  String get settingsNoticeTitle;

  /// No description provided for @settingsNoticeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Send an announcement to all your students. It appears in their app instantly.'**
  String get settingsNoticeSubtitle;

  /// No description provided for @settingsNoticeHeading.
  ///
  /// In en, this message translates to:
  /// **'Notice title'**
  String get settingsNoticeHeading;

  /// No description provided for @settingsNoticeBody.
  ///
  /// In en, this message translates to:
  /// **'Details (optional)'**
  String get settingsNoticeBody;

  /// No description provided for @settingsNoticeSend.
  ///
  /// In en, this message translates to:
  /// **'Post Notice'**
  String get settingsNoticeSend;

  /// No description provided for @settingsNoticeSent.
  ///
  /// In en, this message translates to:
  /// **'Notice posted to students!'**
  String get settingsNoticeSent;

  /// No description provided for @settingsHelp.
  ///
  /// In en, this message translates to:
  /// **'Help & About'**
  String get settingsHelp;

  /// No description provided for @settingsContactSupport.
  ///
  /// In en, this message translates to:
  /// **'Contact Support'**
  String get settingsContactSupport;

  /// No description provided for @settingsPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get settingsPrivacyPolicy;

  /// No description provided for @settingsDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get settingsDeleteAccount;

  /// No description provided for @settingsAppVersion.
  ///
  /// In en, this message translates to:
  /// **'App Version'**
  String get settingsAppVersion;

  /// No description provided for @broadcastTitle.
  ///
  /// In en, this message translates to:
  /// **'Broadcast'**
  String get broadcastTitle;

  /// No description provided for @broadcastAllStudents.
  ///
  /// In en, this message translates to:
  /// **'All Students'**
  String get broadcastAllStudents;

  /// No description provided for @broadcastSelectBatch.
  ///
  /// In en, this message translates to:
  /// **'Select Batch'**
  String get broadcastSelectBatch;

  /// No description provided for @broadcastMessage.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get broadcastMessage;

  /// No description provided for @broadcastSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get broadcastSend;

  /// No description provided for @broadcastTemplateTestReminder.
  ///
  /// In en, this message translates to:
  /// **'Test Reminder'**
  String get broadcastTemplateTestReminder;

  /// No description provided for @broadcastTemplateFeeReminder.
  ///
  /// In en, this message translates to:
  /// **'Fee Reminder'**
  String get broadcastTemplateFeeReminder;

  /// No description provided for @broadcastTemplateResult.
  ///
  /// In en, this message translates to:
  /// **'Result'**
  String get broadcastTemplateResult;

  /// No description provided for @broadcastTemplateHoliday.
  ///
  /// In en, this message translates to:
  /// **'Holiday'**
  String get broadcastTemplateHoliday;

  /// No description provided for @studentPortalTestsAvailable.
  ///
  /// In en, this message translates to:
  /// **'Tests Available'**
  String get studentPortalTestsAvailable;

  /// No description provided for @studentPortalRecentResults.
  ///
  /// In en, this message translates to:
  /// **'Recent Results'**
  String get studentPortalRecentResults;

  /// No description provided for @studentPortalNotices.
  ///
  /// In en, this message translates to:
  /// **'Notices'**
  String get studentPortalNotices;

  /// No description provided for @studentPortalNothingYet.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get studentPortalNothingYet;

  /// No description provided for @studentPortalNothingYetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your teacher will publish tests and notices here.'**
  String get studentPortalNothingYetSubtitle;

  /// No description provided for @studentPortalChatAI.
  ///
  /// In en, this message translates to:
  /// **'Chat with AI'**
  String get studentPortalChatAI;

  /// No description provided for @studentPortalAskAI.
  ///
  /// In en, this message translates to:
  /// **'Ask AI Tutor'**
  String get studentPortalAskAI;

  /// No description provided for @studentPortalAskAISubtitle.
  ///
  /// In en, this message translates to:
  /// **'Get instant help on WhatsApp'**
  String get studentPortalAskAISubtitle;

  /// No description provided for @studentPortalErrorLoad.
  ///
  /// In en, this message translates to:
  /// **'Failed to load feed. Check your connection.'**
  String get studentPortalErrorLoad;

  /// No description provided for @studentPortalRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get studentPortalRetry;

  /// No description provided for @studentPortalMin.
  ///
  /// In en, this message translates to:
  /// **'min'**
  String get studentPortalMin;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get commonEdit;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get commonSend;

  /// No description provided for @navTrainingModules.
  ///
  /// In en, this message translates to:
  /// **'Training Modules'**
  String get navTrainingModules;

  /// No description provided for @trainingModulesTitle.
  ///
  /// In en, this message translates to:
  /// **'Training Modules'**
  String get trainingModulesTitle;

  /// No description provided for @trainingModulesNew.
  ///
  /// In en, this message translates to:
  /// **'New Module'**
  String get trainingModulesNew;

  /// No description provided for @trainingModulesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No Training Modules Yet'**
  String get trainingModulesEmpty;

  /// No description provided for @trainingModulesEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create your first module to organize notes, tests, and videos for your students.'**
  String get trainingModulesEmptySubtitle;

  /// No description provided for @trainingModulesPublished.
  ///
  /// In en, this message translates to:
  /// **'Published'**
  String get trainingModulesPublished;

  /// No description provided for @trainingModulesDraft.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get trainingModulesDraft;

  /// No description provided for @trainingModulesTopics.
  ///
  /// In en, this message translates to:
  /// **'Topics'**
  String get trainingModulesTopics;

  /// No description provided for @trainingModulesSubtopics.
  ///
  /// In en, this message translates to:
  /// **'Subtopics'**
  String get trainingModulesSubtopics;

  /// No description provided for @trainingModulesItems.
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get trainingModulesItems;

  /// No description provided for @trainingModulesAddTopic.
  ///
  /// In en, this message translates to:
  /// **'Add Topic'**
  String get trainingModulesAddTopic;

  /// No description provided for @trainingModulesAddSubtopic.
  ///
  /// In en, this message translates to:
  /// **'Add Subtopic'**
  String get trainingModulesAddSubtopic;

  /// No description provided for @trainingModulesAddContent.
  ///
  /// In en, this message translates to:
  /// **'Add Content'**
  String get trainingModulesAddContent;

  /// No description provided for @trainingModulesNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get trainingModulesNotes;

  /// No description provided for @trainingModulesTest.
  ///
  /// In en, this message translates to:
  /// **'Test Series'**
  String get trainingModulesTest;

  /// No description provided for @trainingModulesVideo.
  ///
  /// In en, this message translates to:
  /// **'YouTube Video'**
  String get trainingModulesVideo;

  /// No description provided for @trainingModulesYourPath.
  ///
  /// In en, this message translates to:
  /// **'Your Learning Path'**
  String get trainingModulesYourPath;

  /// No description provided for @trainingModulesCompleted.
  ///
  /// In en, this message translates to:
  /// **'completed'**
  String get trainingModulesCompleted;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'hi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'hi':
      return AppLocalizationsHi();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
