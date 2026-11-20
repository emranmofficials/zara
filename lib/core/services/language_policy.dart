/// Single source of truth for the assistant's spoken/output language.
///
/// For now ZaRa is intentionally Bengali-only. ASR locale, TTS locale, wake
/// words, model prompts and local fallback replies all come from here so a
/// stray English/Hinglish answer cannot leak into the voice pipeline.
abstract final class LanguagePolicy {
  static const String name = 'বাংলা';
  static const String localeId = 'bn_IN';
  static const String ttsLanguage = 'bn-IN';

  /// Only Bengali recognition locales are offered in Settings.
  static const List<(String, String)> locales = <(String, String)>[
    ('bn_IN', 'বাংলা (ভারত)'),
    ('bn_BD', 'বাংলা (বাংলাদেশ)'),
  ];

  static const List<String> wakeWords = <String>[
    'ও জারা',
    'জারা',
    'জারা শোনো',
    'জারা শুন',
  ];

  static const String systemPrompt =
      'তুমি ZaRa, একজন সংক্ষিপ্ত বাংলা-ভাষী ভয়েস অ্যাসিস্ট্যান্ট। '
      'সবসময় শুদ্ধ বাংলা ভাষায় উত্তর দাও। ইংরেজি বা Hinglish ব্যবহার করো না। '
      'উত্তর ছোট, প্রাকৃতিক এবং কথ্য বাংলা রাখো। প্রয়োজনে টুল ব্যবহার করো।';

  static const String toolPrompt =
      'কোনো টুল লাগলে শুধু JSON দাও: {"tool":"name","args":{...}} — '
      'নাহলে সরাসরি বাংলা উত্তর দাও।';

  static String forPersona(String persona) =>
      '$systemPrompt বর্তমান persona: $persona।';

  /// Notification replies are always written in Bengali, even if the incoming
  /// voice note was detected as another language.
  static String translatePrompt({
    required String chat,
    String? detectedLanguage,
  }) {
    final detected = detectedLanguage == null || detectedLanguage.trim().isEmpty
        ? ''
        : ' মূল বার্তার ভাষা "$detectedLanguage" হলেও তা উপেক্ষা করো।';
    return 'নিচের বার্তাটি $chat চ্যাটের জন্য পাঠযোগ্য বাংলা উত্তর হিসেবে তৈরি করো।'
        '$detected শুধু বাংলা ভাষা ব্যবহার করো, কোনো ব্যাখ্যা বা উদ্ধৃতি নয়। '
        'শুধু অনুবাদিত পাঠ্য ফেরত দাও।';
  }

  static const Map<String, String> _actionLabels = <String, String>{
    'Reminder': 'রিমাইন্ডার',
    'Tasks': 'কাজ',
    'News': 'খবর',
    'Music': 'সঙ্গীত',
    'Gossip': 'গল্প',
    'Journal': 'জার্নাল',
    'Study': 'পড়াশোনা',
    'Focus': 'ফোকাস',
    'Roast': 'মজা',
    'Vent': 'মনখুলে কথা',
    'Smarthome': 'স্মার্ট হোম',
    'Automation': 'অটোমেশন',
  };

  /// Quick-action labels stay readable in the composer, but anything spoken
  /// back to the user is localised first.
  static String action(String label) => _actionLabels[label] ?? 'কাজ';
}
