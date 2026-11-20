import 'dart:convert';

import 'package:http/http.dart' as http;

import '../agent/tool_registry.dart';
import '../keys/key_store.dart';
import '../models/models.dart';
import 'gemini_key_guard.dart';
import 'language_policy.dart';
import 'model_catalog.dart';

/// Result of a single generation attempt across the model fallback chain.
class _Generation {
  final String? text;
  final ToolCall? toolCall;
  final String? error;

  const _Generation._({this.text, this.toolCall, this.error});

  factory _Generation.text(String text) => _Generation._(text: text);
  factory _Generation.tool(ToolCall call) => _Generation._(toolCall: call);
  factory _Generation.error(String message) => _Generation._(error: message);

  bool get ok => error == null;
}

/// Gemini client with two modes:
/// 1. Backend proxy (if a backend URL is configured in Settings)
/// 2. Bring-your-own-key, direct to Google
///
/// Backend is preferred when configured, but a failed proxy request falls back
/// to a saved local key. Direct requests try the pinned model first, then the
/// clean-room fallback catalogue, and translate every error into Bengali.
class GeminiClient {
  GeminiClient._();
  static final GeminiClient instance = GeminiClient._();

  /// Validate a pasted key with the public models probe. Never stores it.
  Future<GeminiKeyCheck> testKey(
    String raw, {
    http.Client? client,
  }) =>
      GeminiKeyGuard.check(raw, client: client);

  /// Non-reversible hint for Settings. Returns empty when no key is saved.
  Future<String> savedKeyHint() async {
    final hint = await KeyStore.instance.read(KeyStoreKeys.geminiKeyHint);
    if (hint != null && hint.trim().isNotEmpty) return hint.trim();
    final raw = await KeyStore.instance.read(KeyStoreKeys.gemini);
    return GeminiKeyGuard.hint(raw ?? '');
  }

  Future<String> respond(String prompt, {String persona = 'ZaRa'}) async {
    final backend = await _backendBase();
    if (backend != null) {
      final reply = await _viaBackend(backend, prompt, persona);
      if (reply != null) return reply;
    }
    final result = await _generate(
      system: LanguagePolicy.forPersona(persona),
      prompt: prompt,
    );
    return result.text ?? result.error ?? 'কোনো উত্তর পাওয়া যায়নি।';
  }

  /// Ask the model with tool declarations. Returns text OR a tool call.
  Future<BrainResponse> respondWithTools(
    String prompt, {
    String persona = 'ZaRa',
    int toolBudget = 8,
  }) async {
    final backend = await _backendBase();
    if (backend != null) {
      final reply = await _viaBackend(
        backend,
        '$prompt\n\n${LanguagePolicy.toolPrompt}',
        persona,
      );
      if (reply != null) return _parseBackendTool(reply);
    }

    final result = await _generate(
      system: LanguagePolicy.forPersona(persona),
      prompt: prompt,
      toolBudget: toolBudget,
    );
    if (result.toolCall != null) return BrainResponse.tool(result.toolCall!);
    return BrainResponse.text(
      result.text ?? result.error ?? 'কোনো উত্তর পাওয়া যায়নি।',
    );
  }

  /// Polish a short reply as a sendable Bengali message.
  ///
  /// [targetLanguage] is kept for API compatibility with the voice-note offer
  /// model; the app is Bengali-only, so LanguagePolicy wins regardless.
  Future<String> translateReply({
    required String text,
    required String targetLanguage,
    required String chat,
  }) async {
    return respond(
      '${LanguagePolicy.translatePrompt(chat: chat, detectedLanguage: targetLanguage)}\n\n$text',
    );
  }

  BrainResponse _parseBackendTool(String answer) {
    final trimmed = answer.trim();
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      try {
        final map = jsonDecode(trimmed) as Map<String, dynamic>;
        final name = map['tool'] as String?;
        if (name != null && name.isNotEmpty) {
          final args = Map<String, dynamic>.from(map['args'] as Map? ?? const {});
          return BrainResponse.tool(
            ToolCall(name: name, args: ToolRegistry.normalize(name, args)),
          );
        }
      } catch (_) {
        // Not JSON - treat as a plain answer.
      }
    }
    return BrainResponse.text(answer);
  }

  Future<String?> _backendBase() async {
    final backend = await KeyStore.instance.read(KeyStoreKeys.backendUrl);
    final base = backend?.trim();
    return (base == null || base.isEmpty) ? null : base.replaceAll(RegExp(r'/+$'), '');
  }

  /// Returns null when the proxy is unreachable so the caller can fall back to
  /// the on-device key. A successful empty reply is returned as an empty string.
  Future<String?> _viaBackend(String base, String prompt, String persona) async {
    final uri = Uri.parse('$base/chat');
    final token = await KeyStore.instance.read(KeyStoreKeys.backendToken);
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null && token.trim().isNotEmpty) {
      headers['Authorization'] = 'Bearer ${token.trim()}';
    }
    try {
      final response = await http
          .post(
            uri,
            headers: headers,
            body: jsonEncode({'message': prompt, 'persona': persona}),
          )
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['reply']?.toString() ?? '';
    } catch (_) {
      return null;
    }
  }

  Future<_Generation> _generate({
    required String system,
    required String prompt,
    int toolBudget = 0,
  }) async {
    final raw = await KeyStore.instance.read(KeyStoreKeys.gemini);
    final key = GeminiKeyGuard.sanitize(raw ?? '');
    if (key.isEmpty) {
      return _Generation.error('Gemini key নেই — Settings-এ key বা backend URL দিন।');
    }

    final pinned = await KeyStore.instance.read(KeyStoreKeys.geminiModel);
    final models = ModelCatalog.candidates(pinned);
    final body = <String, dynamic>{
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': '$system\n\n$prompt'},
          ],
        },
      ],
      'generationConfig': {'temperature': 0.4, 'maxOutputTokens': 1024},
    };
    if (toolBudget > 0) {
      body['tools'] = [
        {'functionDeclarations': ToolRegistry.declarations(toolBudget)},
      ];
      body['toolConfig'] = {
        'functionCallingConfig': {'mode': 'AUTO'},
      };
    }

    final client = http.Client();
    try {
      for (final model in models) {
        final uri = Uri.https(
          'generativelanguage.googleapis.com',
          '/v1beta/models/$model:generateContent',
          {'key': key},
        );
        late final http.Response response;
        try {
          response = await client
              .post(
                uri,
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode(body),
              )
              .timeout(const Duration(seconds: 25));
        } catch (_) {
          return _Generation.error('সংযোগে সমস্যা — ইন্টারনেট চেক করে আবার চেষ্টা করুন।');
        }

        if (response.statusCode == 200) {
          return _parseGeneration(response.body);
        }
        if (response.statusCode == 429 || response.statusCode >= 500) {
          // Quota or temporary outage: try the next clean-room candidate.
          continue;
        }
        return _Generation.error(_statusMessage(response.statusCode));
      }
      return _Generation.error('মডেল এখন ব্যস্ত — কিছুক্ষণ পর আবার চেষ্টা করুন।');
    } finally {
      client.close();
    }
  }

  _Generation _parseGeneration(String body) {
    try {
      final data = jsonDecode(body) as Map<String, dynamic>;
      final parts = data['candidates']?[0]?['content']?['parts'] as List?;
      if (parts == null || parts.isEmpty) {
        return _Generation.error('কোনো উত্তর পাওয়া যায়নি।');
      }
      for (final part in parts) {
        final call = part is Map ? part['functionCall'] : null;
        if (call is Map) {
          final name = call['name']?.toString() ?? '';
          final args = Map<String, dynamic>.from(call['args'] as Map? ?? const {});
          return _Generation.tool(
            ToolCall(name: name, args: ToolRegistry.normalize(name, args)),
          );
        }
      }
      for (final part in parts) {
        final text = part is Map ? part['text'] : null;
        if (text != null) return _Generation.text(text.toString());
      }
      return _Generation.error('কিছু পাওয়া যায়নি।');
    } catch (_) {
      return _Generation.error('উত্তর পড়তে সমস্যা হয়েছে।');
    }
  }

  String _statusMessage(int status) {
    if (status == 400 || status == 401) {
      return 'KEY reject হয়েছে — Settings-এ নতুন KEY দিন।';
    }
    if (status == 403) {
      return 'এই KEY দিয়ে মডেল ব্যবহার করার অনুমতি নেই।';
    }
    if (status == 429) return 'সার্ভার ব্যস্ত — কিছুক্ষণ পর আবার চেষ্টা করুন।';
    return 'Gemini ত্রুটি $status।';
  }
}
