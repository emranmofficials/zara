import 'package:flutter_test/flutter_test.dart';
import 'package:zara/core/services/wake_word_engine.dart';

void main() {
  group('KeywordWakeWordEngine', () {
    test('detects a phrase inside a partial transcript', () async {
      final engine = KeywordWakeWordEngine(words: const ['hey zara', 'zara']);
      final event = engine.detected.first;
      engine.feed('Hey, Zara!');
      await event.timeout(const Duration(seconds: 1));
      engine.dispose();
    });

    test('normalises case, punctuation and extra spaces', () async {
      final engine = KeywordWakeWordEngine(words: const ['hey zara']);
      final event = engine.detected.first;
      engine.feed('  HEY,,,   ZARA  ');
      await event.timeout(const Duration(seconds: 1));
      engine.dispose();
    });

    test('ignores unrelated text', () async {
      final engine = KeywordWakeWordEngine(words: const ['hey zara']);
      var hits = 0;
      engine.detected.listen((_) => hits++);
      engine.feed('what is the time');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(hits, 0);
      engine.dispose();
    });

    test('debounces repeated hits', () async {
      final engine = KeywordWakeWordEngine(
        words: const ['zara'],
        cooldown: const Duration(seconds: 5),
      );
      var hits = 0;
      engine.detected.listen((_) => hits++);
      engine.feed('zara');
      engine.feed('zara zara');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(hits, 1);
      engine.dispose();
    });

    test('updateWords changes the active phrases', () async {
      final engine = KeywordWakeWordEngine(words: const ['zara']);
      final event = engine.detected.first;
      engine.updateWords(const ['nova']);
      engine.feed('hello nova');
      await event.timeout(const Duration(seconds: 1));
      engine.dispose();
    });
  });

  group('ModelWakeWordEngine', () {
    test('fires only when the inference score passes the threshold', () async {
      var score = 0.2;
      final engine = ModelWakeWordEngine(
        infer: (features) async => score,
        threshold: 0.7,
      );
      var hits = 0;
      engine.detected.listen((_) => hits++);
      await engine.feedFeatures(Float32List.fromList([0.1, 0.2]));
      expect(hits, 0);
      // Reset armed state via a clearly sub-threshold score.
      score = 0.1;
      await engine.feedFeatures(Float32List.fromList([0.0]));
      score = 0.9;
      await engine.feedFeatures(Float32List.fromList([1.0]));
      expect(hits, 1);
      engine.dispose();
    });
  });
}
