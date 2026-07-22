// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get navDashboard => 'डैशबोर्ड';

  @override
  String get navStudents => 'छात्र';

  @override
  String get navBatches => 'बैच';

  @override
  String get navTestGenerator => 'टेस्ट जनरेटर';

  @override
  String get navAttendance => 'उपस्थिति';

  @override
  String get navFeeManagement => 'शुल्क प्रबंधन';

  @override
  String get navAnalytics => 'विश्लेषण';

  @override
  String get navBroadcast => 'प्रसारण';

  @override
  String get navSettings => 'सेटिंग्स';

  @override
  String get navLogout => 'लॉगआउट';

  @override
  String get roleAdmin => 'व्यवस्थापक';

  @override
  String get roleManager => 'प्रबंधक';

  @override
  String get roleSuperAdmin => 'सुपर एडमिन';

  @override
  String get poweredByAltrobyte => 'Altrobyte द्वारा';

  @override
  String get dashboardTitle => 'डैशबोर्ड';

  @override
  String dashboardWelcome(String name) {
    return 'नमस्ते, $name!';
  }

  @override
  String get dashboardRecentActivity => 'हाल की गतिविधि';

  @override
  String get dashboardNoActivity => 'कोई हाल की गतिविधि नहीं';

  @override
  String get dashboardQuickActions => 'त्वरित क्रियाएं';

  @override
  String get statsTotalStudents => 'कुल छात्र';

  @override
  String get statsActiveBatches => 'सक्रिय बैच';

  @override
  String get statsFeePending => 'शुल्क बकाया';

  @override
  String get statsTestsToday => 'आज के टेस्ट';

  @override
  String get statsEnrolledStudents => 'नामांकित छात्र';

  @override
  String get statsRunningBatches => 'चल रहे बैच';

  @override
  String get statsStudentsPending => 'बकाया छात्र';

  @override
  String get statsGeneratedToday => 'आज बनाए गए';

  @override
  String get actionAddStudent => 'छात्र जोड़ें';

  @override
  String get actionGenerateTest => 'टेस्ट बनाएं';

  @override
  String get actionMarkAttendance => 'उपस्थिति लें';

  @override
  String get actionManageFees => 'शुल्क प्रबंधित करें';

  @override
  String get actionBroadcast => 'प्रसारण';

  @override
  String get bottomNavHome => 'होम';

  @override
  String get bottomNavStudents => 'छात्र';

  @override
  String get bottomNavTests => 'टेस्ट';

  @override
  String get bottomNavAttendance => 'उपस्थि.';

  @override
  String get bottomNavSettings => 'सेटिंग्स';

  @override
  String get testGenTabGenerate => 'उत्पन्न करें';

  @override
  String get testGenTabMyTests => 'मेरे टेस्ट';

  @override
  String get testGenAITitle => 'AI टेस्ट जनरेटर';

  @override
  String get testGenAIPowered => 'Altron AI द्वारा';

  @override
  String get testGenTestTitle => 'टेस्ट शीर्षक (वैकल्पिक)';

  @override
  String get testGenTestTitleHint => 'जैसे: SSC GD मॉक टेस्ट 1';

  @override
  String get testGenSubject => 'विषय *';

  @override
  String get testGenTopic => 'टॉपिक';

  @override
  String get testGenTopicHint => 'जैसे: प्रतिशत और लाभ-हानि';

  @override
  String get testGenTopicHelper => 'यादृच्छिक टॉपिक के लिए खाली छोड़ें';

  @override
  String get testGenDifficulty => 'कठिनाई स्तर';

  @override
  String get testGenExamPattern => 'परीक्षा पैटर्न';

  @override
  String get testGenQuestionCount => 'प्रश्नों की संख्या';

  @override
  String get testGenBatch => 'बैच (भेजने के लिए)';

  @override
  String get testGenNoBatch => 'कोई विशेष बैच नहीं';

  @override
  String get testGenLanguage => 'टेस्ट की भाषा';

  @override
  String get testGenLangHindi => 'हिंदी';

  @override
  String get testGenLangEnglish => 'English (अंग्रेज़ी)';

  @override
  String get testGenLangBoth => 'द्विभाषी (दोनों)';

  @override
  String get testGenGenerateBtn => 'AI से टेस्ट बनाएं';

  @override
  String get testGenGenerating => '🤖 AI प्रश्न बना रहा है...';

  @override
  String get testGenEmptyTitle => 'टेस्ट सेट करें और बनाएं';

  @override
  String get testGenEmptySubtitle => 'AI कुछ ही सेकंड में प्रश्न बनाएगा!';

  @override
  String get settingsTitle => 'सेटिंग्स';

  @override
  String get settingsInstituteName => 'संस्था का नाम';

  @override
  String get settingsInstituteId => 'संस्था ID';

  @override
  String get settingsNotSet => 'सेट नहीं है';

  @override
  String get settingsEnrollmentCode => 'छात्र नामांकन कोड';

  @override
  String get settingsEnrollmentCodeSubtitle =>
      'इस कोड को छात्रों के साथ शेयर करें ताकि वे आपकी संस्था से जुड़ सकें।';

  @override
  String get settingsAiTutorNumber => 'AI ट्यूटर WhatsApp नंबर';

  @override
  String get settingsAiTutorSubtitle =>
      'जब छात्र \"AI से बात करें\" टैप करते हैं तो उन्हें इस नंबर पर भेजा जाएगा। कंट्री कोड के साथ डालें (जैसे 919876543210)।';

  @override
  String get settingsPhoneWithCode => 'फ़ोन नंबर (कंट्री कोड सहित)';

  @override
  String get settingsWaSaved => 'WhatsApp नंबर सहेजा गया!';

  @override
  String get settingsLanguage => 'Language / भाषा';

  @override
  String get settingsLangEnglish => 'English';

  @override
  String get settingsLangHindi => 'हिंदी';

  @override
  String get settingsLogout => 'लॉगआउट';

  @override
  String get settingsVersion => 'v1.0.0 • Altrobyte Automation द्वारा';

  @override
  String get settingsCodeCopied => 'कोड कॉपी हो गया!';

  @override
  String get settingsSave => 'सहेजें';

  @override
  String get settingsProfile => 'संस्था प्रोफ़ाइल';

  @override
  String get settingsOwnerName => 'मालिक का नाम';

  @override
  String get settingsOwnerPhone => 'फ़ोन नंबर';

  @override
  String get settingsEmail => 'ईमेल';

  @override
  String get settingsCity => 'शहर';

  @override
  String get settingsEditProfile => 'प्रोफ़ाइल संपादित करें';

  @override
  String get settingsProfileSaved => 'प्रोफ़ाइल अपडेट हो गई!';

  @override
  String get settingsNoticeTitle => 'सूचना भेजें';

  @override
  String get settingsNoticeSubtitle =>
      'अपने सभी छात्रों को घोषणा भेजें। यह तुरंत उनके ऐप में दिखेगी।';

  @override
  String get settingsNoticeHeading => 'सूचना का शीर्षक';

  @override
  String get settingsNoticeBody => 'विवरण (वैकल्पिक)';

  @override
  String get settingsNoticeSend => 'सूचना भेजें';

  @override
  String get settingsNoticeSent => 'सूचना छात्रों को भेज दी गई!';

  @override
  String get settingsHelp => 'सहायता और जानकारी';

  @override
  String get settingsContactSupport => 'सहायता से संपर्क करें';

  @override
  String get settingsPrivacyPolicy => 'गोपनीयता नीति';

  @override
  String get settingsDeleteAccount => 'खाता हटाएं';

  @override
  String get settingsAppVersion => 'ऐप संस्करण';

  @override
  String get broadcastTitle => 'प्रसारण';

  @override
  String get broadcastAllStudents => 'सभी छात्र';

  @override
  String get broadcastSelectBatch => 'बैच चुनें';

  @override
  String get broadcastMessage => 'संदेश';

  @override
  String get broadcastSend => 'भेजें';

  @override
  String get broadcastTemplateTestReminder => 'टेस्ट रिमाइंडर';

  @override
  String get broadcastTemplateFeeReminder => 'शुल्क अनुस्मारक';

  @override
  String get broadcastTemplateResult => 'परिणाम';

  @override
  String get broadcastTemplateHoliday => 'अवकाश';

  @override
  String get studentPortalTestsAvailable => 'उपलब्ध टेस्ट';

  @override
  String get studentPortalRecentResults => 'हालिया परिणाम';

  @override
  String get studentPortalNotices => 'सूचनाएं';

  @override
  String get studentPortalNothingYet => 'अभी कुछ नहीं है';

  @override
  String get studentPortalNothingYetSubtitle =>
      'आपके शिक्षक यहाँ टेस्ट और सूचनाएं प्रकाशित करेंगे।';

  @override
  String get studentPortalChatAI => 'AI से बात करें';

  @override
  String get studentPortalAskAI => 'AI ट्यूटर से पूछें';

  @override
  String get studentPortalAskAISubtitle => 'WhatsApp पर तुरंत मदद पाएं';

  @override
  String get studentPortalErrorLoad => 'फ़ीड लोड नहीं हुआ। इंटरनेट जांचें।';

  @override
  String get studentPortalRetry => 'पुनः प्रयास करें';

  @override
  String get studentPortalMin => 'मिनट';

  @override
  String get commonSave => 'सहेजें';

  @override
  String get commonCancel => 'रद्द करें';

  @override
  String get commonDelete => 'हटाएं';

  @override
  String get commonEdit => 'संपादित करें';

  @override
  String get commonRetry => 'पुनः प्रयास';

  @override
  String get commonSend => 'भेजें';

  @override
  String get navTrainingModules => 'प्रशिक्षण मॉड्यूल';

  @override
  String get trainingModulesTitle => 'प्रशिक्षण मॉड्यूल';

  @override
  String get trainingModulesNew => 'नया मॉड्यूल';

  @override
  String get trainingModulesEmpty => 'अभी कोई प्रशिक्षण मॉड्यूल नहीं';

  @override
  String get trainingModulesEmptySubtitle =>
      'अपने छात्रों के लिए नोट्स, टेस्ट और वीडियो व्यवस्थित करने के लिए पहला मॉड्यूल बनाएं।';

  @override
  String get trainingModulesPublished => 'प्रकाशित';

  @override
  String get trainingModulesDraft => 'ड्राफ्ट';

  @override
  String get trainingModulesTopics => 'टॉपिक';

  @override
  String get trainingModulesSubtopics => 'सब-टॉपिक';

  @override
  String get trainingModulesItems => 'आइटम';

  @override
  String get trainingModulesAddTopic => 'टॉपिक जोड़ें';

  @override
  String get trainingModulesAddSubtopic => 'सब-टॉपिक जोड़ें';

  @override
  String get trainingModulesAddContent => 'कंटेंट जोड़ें';

  @override
  String get trainingModulesNotes => 'नोट्स';

  @override
  String get trainingModulesTest => 'टेस्ट सीरीज़';

  @override
  String get trainingModulesVideo => 'YouTube वीडियो';

  @override
  String get trainingModulesYourPath => 'आपका लर्निंग पथ';

  @override
  String get trainingModulesCompleted => 'पूर्ण';
}
