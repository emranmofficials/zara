import 'dart:convert';

import 'package:http/http.dart' as http;

/// Saved-key states used by the setup guide.
///
/// The states deliberately mirror the observable behaviour of a real AI-key
/// onboarding flow (missing, malformed, refused, denied, rate-limited, offline)
/// without embedding any vendor-specific key or licence logic.
enum GeminiKeyStatus {
  missing,
  invalidFormat,
  ready,
  rejected,
  denied,
  busy,
  noInternet,
  serverHasNone,
}

class GeminiKeyCheck {
  final GeminiKeyStatus status;
  final String message;
  final String model;

  const GeminiKeyCheck._({
    required this.status,
    required this.message,
    this.model = '',
  });

  bool get ok => status == GeminiKeyStatus.ready;

  factory GeminiKeyCheck.missing() => const GeminiKeyCheck._(
        status: GeminiKeyStatus.missing,
        message: 'API key দেওয়া হয়নি।',
      );

  factory GeminiKeyCheck.invalidFormat() => const GeminiKeyCheck._(
        status: GeminiKeyStatus.invalidFormat,
        message: 'KEY ফরম্যাট ঠিক নেই — AI Studio থেকে নেওয়া KEY টি সম্পূর্ণ পেস্ট করুন।',
      );

  factory GeminiKeyCheck.ready(String model) => GeminiKeyCheck._(
        status: GeminiKeyStatus.ready,
        message: 'KEY কাজ করছে — $model মডেল পাওয়া গেছে।',
        model: model,
      );

  factory GeminiKeyCheck.rejected() => const GeminiKeyCheck._(
        status: GeminiKeyStatus.rejected,
        message: 'KEY reject হয়েছে। নতুন KEY বানিয়ে আবার দিন।',
      );

  factory GeminiKeyCheck.denied() => const GeminiKeyCheck._(
        status: GeminiKeyStatus.denied,
        message: 'এই KEY দিয়ে মডেল ব্যবহার করার অনুমতি নেই।',
      );

  factory GeminiKeyCheck.busy() => const GeminiKeyCheck._(
        status: GeminiKeyStatus.busy,
        message: 'এখন সার্ভার ব্যস্ত — কিছুক্ষণ পর আবার চেষ্টা করুন।',
      );

  factory GeminiKeyCheck.noInternet() => const GeminiKeyCheck._(
        status: GeminiKeyStatus.noInternet,
        message: 'ইন্টারনেটে পৌঁছানো যায়নি — KEY প্রবেশ করানো হয়েছে, পরে আবার পরীক্ষা করুন।',
      );

  factory GeminiKeyCheck.serverHasNone() => const GeminiKeyCheck._(
        status: GeminiKeyStatus.serverHasNone,
        message: 'সার্ভারে কোনো মডেল পাওয়া যায়নি — পরে আবার চেষ্টা করুন।',
      );
}

/// Sanitises and validates a bring-your-own AI key.
///
/// A key is never logged. UI layers receive only a short hint and a status.
abstract final class GeminiKeyGuard {
  static const aiStudioUrl = 'https://aistudio.google.com/apikey';
  static const modelsUrl =
      'https://generativelanguage.googleapis.com/v1beta/models?pageSize=1';

  /// Generic token shape: single long token, no spaces/newlines. No vendor
  /// prefix or proprietary format is encoded here.
  static final RegExp keyPattern = RegExp(r'[A-Za-z0-9_.-]{20,}');

  /// Removes quotes/whitespace and accepts a pasted key even when the user
  /// copied a surrounding phrase. Returns an empty string for invalid input.
  static String sanitize(String raw) {
    final cleaned = raw
        .replaceAll(RegExp("[\\\"'`\\s]+"), ' ')
        .trim();
    final match = keyPattern.firstMatch(cleaned);
    return match?.group(0) ?? '';
  }

  /// A non-reversible display hint. Never returns the full key.
  static String hint(String raw) {
    final key = sanitize(raw);
    if (key.isEmpty) return '';
    return '${key.substring(0, key.length < 4 ? key.length : 4)}••••'
        '${key.length > 4 ? key.substring(key.length - 4) : ''}';
  }

  static Future<GeminiKeyCheck> check(
    String raw, {
    http.Client? client,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final key = sanitize(raw);
    if (key.isEmpty) {
      final trimmed = raw.trim();
      return trimmed.isEmpty ? GeminiKeyCheck.missing() : GeminiKeyCheck.invalidFormat();
    }

    final httpClient = client ?? http.Client();
    try {
      final response = await httpClient
          .get(
            Uri.parse(modelsUrl),
            headers: {'x-goog-api-key': key},
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final models = data['models'] as List? ?? const [];
        if (models.isEmpty) return GeminiKeyCheck.serverHasNone();
        final first = models.first;
        final name = first is Map ? first['name']?.toString() ?? '' : '';
        return GeminiKeyCheck.ready(name.replaceFirst('models/', ''));
      }
      if (response.statusCode == 400 || response.statusCode == 401) {
        return GeminiKeyCheck.rejected();
      }
      if (response.statusCode == 403) return GeminiKeyCheck.denied();
      if (response.statusCode == 429) return GeminiKeyCheck.busy();
      return GeminiKeyCheck.noInternet();
    } on http.ClientException {
      return GeminiKeyCheck.noInternet();
    } on Exception {
      return GeminiKeyCheck.noInternet();
    } finally {
      if (client == null) httpClient.close();
    }
  }
}
