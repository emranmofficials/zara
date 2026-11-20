import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter_test/flutter_test.dart';
import 'package:zara/core/services/gemini_key_guard.dart';
import 'package:zara/core/services/model_catalog.dart';

class _FakeClient extends http.BaseClient {
  final int statusCode;
  final String body;

  _FakeClient(this.statusCode, this.body);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(body)),
      statusCode,
      request: request,
    );
  }
}

void main() {
  group('GeminiKeyGuard', () {
    test('sanitize extracts a pasted key and hint hides the middle', () {
      const raw = 'KEY: AIzaSyD1234567890abcdefghijklmnopqrstuvwxyz';
      final key = GeminiKeyGuard.sanitize(raw);
      expect(key, startsWith('AIza'));
      expect(key.length, greaterThanOrEqualTo(20));
      final hint = GeminiKeyGuard.hint(key);
      expect(hint, contains('••••'));
      expect(hint.contains(key.substring(4, 30)), isFalse);
    });

    test('missing and malformed keys are distinguished', () async {
      expect((await GeminiKeyGuard.check('')).status, GeminiKeyStatus.missing);
      expect(
        (await GeminiKeyGuard.check('not-a-key')).status,
        GeminiKeyStatus.invalidFormat,
      );
    });

    test('200 with models means the key is ready', () async {
      final check = await GeminiKeyGuard.check(
        'AIzaSyD1234567890abcdefghijklmnopqrstuvwxyz',
        client: _FakeClient(
          200,
          '{"models":[{"name":"models/gemini-2.0-flash"}]}',
        ),
      );
      expect(check.ok, isTrue);
      expect(check.model, 'gemini-2.0-flash');
    });

    test('status codes map to Bengali setup states', () async {
      const key = 'AIzaSyD1234567890abcdefghijklmnopqrstuvwxyz';
      for (final entry in {
        400: GeminiKeyStatus.rejected,
        401: GeminiKeyStatus.rejected,
        403: GeminiKeyStatus.denied,
        429: GeminiKeyStatus.busy,
        500: GeminiKeyStatus.noInternet,
      }.entries) {
        final check = await GeminiKeyGuard.check(
          key,
          client: _FakeClient(entry.key, '{}'),
        );
        expect(check.status, entry.value, reason: 'status ${entry.key}');
        expect(check.message, isNotEmpty);
      }
    });
  });

  group('ModelCatalog', () {
    test('pinned model is tried first, fallback list follows', () {
      final models = ModelCatalog.candidates('my-pinned-model');
      expect(models.first, 'my-pinned-model');
      expect(models.length, ModelCatalog.textFallback.length + 1);
      expect(models.toSet().length, models.length);
    });

    test('empty pin uses the clean-room defaults', () {
      expect(ModelCatalog.candidates(null), ModelCatalog.textFallback);
    });
  });
}
