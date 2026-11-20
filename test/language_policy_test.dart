import 'package:flutter_test/flutter_test.dart';
import 'package:zara/core/services/language_policy.dart';

void main() {
  group('Bengali-only speech policy', () {
    test('ASR locales are Bengali dialects only', () {
      expect(LanguagePolicy.localeId, 'bn_IN');
      expect(LanguagePolicy.locales.map((e) => e.$1),
          everyElement(startsWith('bn_')));
      expect(LanguagePolicy.locales.length, 2);
    });

    test('TTS locale and wake words are Bengali', () {
      expect(LanguagePolicy.ttsLanguage, 'bn-IN');
      for (final word in LanguagePolicy.wakeWords) {
        expect(word.contains('জারা'), isTrue, reason: word);
      }
    });

    test('model prompts forbid English/Hinglish output', () {
      expect(LanguagePolicy.systemPrompt, contains('শুদ্ধ বাংলা'));
      expect(LanguagePolicy.systemPrompt, contains('Hinglish ব্যবহার করো না'));
      expect(LanguagePolicy.toolPrompt, contains('বাংলা উত্তর'));
      expect(LanguagePolicy.forPersona('ZaRa'), contains('persona: ZaRa'));
    });

    test('notification replies are always polished into Bengali', () {
      final prompt = LanguagePolicy.translatePrompt(
        chat: 'friends',
        detectedLanguage: 'Hinglish',
      );
      expect(prompt, contains('বাংলা'));
      expect(prompt, contains('উপেক্ষা করো'));
    });
  });
}
