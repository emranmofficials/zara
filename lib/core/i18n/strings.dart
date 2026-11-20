import 'package:flutter/material.dart';

/// UI-language scaffold. Only [AppLanguage.bn] is active for speech right now
/// (see `core/services/language_policy.dart`); the other locales are kept as
/// ZaRa's own translations for a future UI-language switch — no copied
/// resource text from the studied app.
enum AppLanguage { en, hi, bn, ne }

/// The single active locale until multi-language speech is enabled.
const AppLanguage activeAppLanguage = AppLanguage.bn;

extension AppLanguageX on AppLanguage {
  String get code => switch (this) {
        AppLanguage.en => 'en',
        AppLanguage.hi => 'hi',
        AppLanguage.bn => 'bn',
        AppLanguage.ne => 'ne',
      };

  String get label => switch (this) {
        AppLanguage.en => 'English',
        AppLanguage.hi => 'हिंदी',
        AppLanguage.bn => 'বাংলা',
        AppLanguage.ne => 'नेपाली',
      };

  Locale get locale => Locale(code);
}

class L10n {
  final AppLanguage language;
  const L10n(this.language);

  String get appTitle => 'ZaRa';

  String greeting(DateTime now) {
    final h = now.hour;
    final part = h < 5 ? 'late' : h < 12 ? 'morning' : h < 17 ? 'afternoon' : h < 21 ? 'evening' : 'night';
    final Map<String, List<String>> words = {
      'late': ['Still up', 'अभी जागे', 'এখনো জেগে', 'अझै ब्यूँझे'],
      'morning': ['Good morning', 'सुप्रभात', 'শুভ সকাল', 'शुभ बिहान'],
      'afternoon': ['Good afternoon', 'नमस्कार', 'শুভ দুপুর', 'नमस्कार'],
      'evening': ['Good evening', 'शुभ संध्या', 'শুভ সন্ধ্যা', 'शुभ साँझ'],
      'night': ['Good night', 'शुभ रात्रि', 'শুভ রাত্রি', 'शुभ रात'],
    };
    return words[part]![language.index];
  }

  String get home => _pick(['Home', 'होम', 'হোম', 'होम']);
  String get chat => _pick(['Chat', 'चैट', 'চ্যাট', 'च्याट']);
  String get yaadein => _pick(['Yaadein', 'यादें', 'ইয়াদ', 'यादहरू']);
  String get scanner => _pick(['Scanner', 'स्कैनर', 'স্ক্যানার', 'स्क्यानर']);
  String get settings => _pick(['Settings', 'सेटिंग्स', 'সেটিংস', 'सेटिङ्स']);
  String get vibes => _pick(['Vibes', 'वाइब्स', 'ভাইবস', 'भाइब्स']);
  String get live => _pick(['LIVE', 'लाइव', 'লাইভ', 'लाइभ']);
  String get history => _pick(['History', 'इतिहास', 'ইতিহাস', 'इतिहास']);
  String get clear => _pick(['Clear', 'साफ़', 'মুছুন', 'खाली']);
  String get cancel => _pick(['Cancel', 'रद्द', 'বাতিল', 'रद्द']);
  String get send => _pick(['Send', 'भेजें', 'পাঠান', 'पठाउनु']);
  String get confirm => _pick(['Confirm', 'पुष्टि', 'নিশ্চিত', 'पुष्टि']);
  String get energy => _pick(['Energy', 'ऊर्जा', 'শক্তি', 'ऊर्जा']);
  String get weather => _pick(['Weather', 'मौसम', 'আবহাওয়া', 'मौसम']);
  String get today => _pick(['Today', 'आज', 'আজ', 'आज']);
  String get quickActions => _pick(['Quick actions', 'त्वरित काम', 'দ্রুত কাজ', 'छिटो काम']);
  String get howDoYouFeel => _pick(['How do you feel?', 'कैसा लग रहा है?', 'কেমন লাগছে?', 'कस्तो लागिरहेको?']);
  String get askAnything => _pick(['Ask anything…', 'कुछ भी पूछें…', 'যেকোনো কিছু জিজ্ঞেস করুন…', 'केही पनि सोध्नुहोस्…']);
  String get replyHint => _pick(['Type your reply…', 'जवाब लिखें…', 'উত্তর লিখুন…', 'जवाफ लेख्नुहोस्…']);
  String get replyTarget => _pick(['Reply target', 'जवाब का लक्ष्य', 'উত্তরের গন্তব্য', 'जवाफको लक्ष्य']);
  String get meaning => _pick(['Meaning', 'अर्थ', 'অর্থ', 'अर्थ']);
  String get oldChat => _pick(['Old chat', 'पुरानी चैट', 'পুরনো চ্যাট', 'पुरानो च्याट']);
  String get clearHistoryTitle => _pick([
        'Clear all chat history?',
        'सभी चैट इतिहास साफ़ करें?',
        'সম্পূর্ণ চ্যাট ইতিহাস মুছবেন?',
        'सब च्याट इतिहास खाली गर्ने?',
      ]);
  String get clearHistoryBody => _pick([
        'Saved yaadein will remain.',
        'सहेजी गई यादें रहेंगी।',
        'সংরক্ষিত স্মৃতি থাকবে।',
        'सुरक्षित यादहरू रहनेछन्।',
      ]);
  String get languageLabel => _pick(['Language', 'भाषा', 'ভাষা', 'भाषा']);

  String mood(String key) {
    const map = <String, List<String>>{
      'happy': ['Happy', 'खुश', 'খুশি', 'खुसी'],
      'loving': ['Loving', 'प्यार भरा', 'স্নেহাতুর', 'मायालु'],
      'sulky': ['Sulky', 'रूठा', 'রাগী', 'रूठेको'],
      'angry': ['Angry', 'गुस्सा', 'রাগ', 'रिसाएको'],
    };
    return (map[key] ?? map['happy']!)[language.index];
  }

  String state(String key) {
    const map = <String, List<String>>{
      'ready': ['Ready', 'तैयार', 'প্রস্তুত', 'तयार'],
      'connecting': ['Connecting', 'कनेक्ट हो रहा', 'সংযোগ হচ্ছে', 'जोडिरहेको'],
      'listening': ['Listening', 'सुन रहा', 'শুনছি', 'सुनिरहेको'],
      'thinking': ['Thinking', 'सोच रहा', 'ভাবছি', 'सोचिरहेको'],
      'speaking': ['Speaking', 'बोल रहा', 'বলছি', 'बोलिरहेको'],
      'sharing': ['Sharing', 'साझा कर रहा', 'শেয়ার করছি', 'सेयर गर्दै'],
      'error': ['Error', 'त्रुटि', 'ত্রুটি', 'त्रुटि'],
    };
    return (map[key] ?? map['ready']!)[language.index];
  }

  String quick(String key) {
    const map = <String, List<String>>{
      'Reminder': ['Reminder', 'अनुस्मारक', 'রিমাইন্ডার', 'रिमाइन्डर'],
      'Tasks': ['Tasks', 'कार्य', 'কাজ', 'कार्य'],
      'News': ['News', 'समाचार', 'খবর', 'समाचार'],
      'Music': ['Music', 'संगीत', 'সঙ্গীত', 'संगीत'],
      'Gossip': ['Gossip', 'गपशप', 'গল্প', 'गपशप'],
      'Journal': ['Journal', 'डायरी', 'জার্নাল', 'डायरी'],
      'Study': ['Study', 'पढ़ाई', 'পড়াশোনা', 'पढाइ'],
      'Focus': ['Focus', 'फ़ोकस', 'ফোকাস', 'फोकस'],
      'Roast': ['Roast', 'मज़ाक', 'মজা', 'मजाक'],
      'Vent': ['Vent', 'मन खोलना', 'মন খোলা', 'मन खोल्ने'],
      'Smarthome': ['Smarthome', 'स्मार्ट होम', 'স্মার্ট হোম', 'स्मार्ट घर'],
      'Automation': ['Automation', 'स्वचालन', 'অটোমেশন', 'स्वचालन'],
    };
    return (map[key] ?? [key, key, key, key])[language.index];
  }

  String _pick(List<String> values) => values[language.index];
}
