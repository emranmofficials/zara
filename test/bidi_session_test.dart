import 'package:flutter_test/flutter_test.dart';
import 'package:zara/core/services/bidi_session.dart';
import 'package:zara/core/services/language_policy.dart';

void main() {
  test('Bidi setup frame uses public fields and Bengali language lock', () {
    final frame = BidiSession.buildSetup(
      const BidiConfig(
        model: 'test-live-model',
        systemInstruction: LanguagePolicy.systemPrompt,
        toolBudget: 6,
        resumeHandle: 'resume-123',
      ),
    );
    final setup = frame['setup'] as Map<String, dynamic>;

    expect(setup['model'], 'test-live-model');
    final generation = setup['generationConfig'] as Map<String, dynamic>;
    expect(generation['responseModalities'], ['AUDIO']);
    final speech = setup['speechConfig'] as Map<String, dynamic>;
    expect(speech['languageCode'], LanguagePolicy.ttsLanguage);
    expect(setup['inputAudioTranscription'], isA<Map>());
    expect(setup['outputAudioTranscription'], isA<Map>());
    expect(
      (setup['systemInstruction'] as Map)['parts'].first['text'],
      LanguagePolicy.systemPrompt,
    );
    final tools = setup['tools'] as List;
    expect(tools.length, 1);
    expect(
      (tools.first as Map)['functionDeclarations'].length,
      6,
    );
    expect(
      (setup['sessionResumption'] as Map)['handle'],
      'resume-123',
    );
    expect(setup.containsKey('tools'), isTrue);
  });

  test('manual activity mode declares turn coverage', () {
    final setup = BidiSession.buildSetup(
      const BidiConfig(
        model: 'test-live-model',
        systemInstruction: LanguagePolicy.systemPrompt,
        automaticActivity: false,
      ),
    )['setup'] as Map<String, dynamic>;
    final config = setup['realtimeInputConfig'] as Map<String, dynamic>;
    expect(
      (config['automaticActivityDetection'] as Map)['disabled'],
      isTrue,
    );
    expect(config['turnCoverage'], 'TURN_INCLUDES_ONLY_ACTIVITY');
    expect(setup.containsKey('sessionResumption'), isFalse);
  });
}
