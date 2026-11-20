import 'dart:convert';

import 'package:http/http.dart' as http;

import '../agent/tool_registry.dart';
import '../keys/key_store.dart';
import '../models/models.dart';

/// Gemini client with two modes:
/// 1. Backend proxy (if a backend URL is configured in Settings)
/// 2. Bring-your-own-key, direct to Google
///
/// Also supports tool calling via [respondWithTools].
class GeminiClient {
  GeminiClient._();
  static final GeminiClient instance = GeminiClient._();

  static const _model = 'gemini-2.0-flash';

  Future<String> respond(String prompt, {String persona = 'ZaRa'}) async {
    final backend = await KeyStore.instance.read(KeyStoreKeys.backendUrl);
    if (backend != null && backend.trim().isNotEmpty) {
      return _viaBackend(backend.trim(), prompt, persona);
    }
    return _direct(prompt);
  }

  /// Ask the model with tool declarations. Returns text OR a tool call.
  Future<BrainResponse> respondWithTools(
    String prompt, {
    String persona = 'ZaRa',
    int toolBudget = 8,
  }) async {
    final key = await KeyStore.instance.read(KeyStoreKeys.gemini);
    final backend = await KeyStore.instance.read(KeyStoreKeys.backendUrl);

    if (backend != null && backend.trim().isNotEmpty) {
      // Backend mode: ask for JSON with an optional "tool" object.
      final answer = await _viaBackend(
        backend.trim(),
        '$prompt\n\nAgar koi tool chahiye to JSON do: {"tool":"name","args":{...}} '
        'warna seedha jawab do.',
        persona,
      );
      return _parseBackendTool(answer);
    }

    if (key == null || key.trim().isEmpty) {
      return BrainResponse.text('Gemini key nahi hai — Settings me key ya backend URL daalo.');
    }

    final declarations = ToolRegistry.budget(toolBudget)
        .map((t) => {
              'functionDeclarations': [
                {
                  'name': t.name,
                  'description': t.description,
                  'parameters': {
                    'type': 'OBJECT',
                    'properties': {
                      'query': {'type': 'STRING'},
                      'to': {'type': 'STRING'},
                      'chat': {'type': 'STRING'},
                      'fact': {'type': 'STRING'},
                      'time': {'type': 'STRING'},
                      'text': {'type': 'STRING'},
                    },
                  },
                }
              ]
            })
        .toList();

    final uri = Uri.https('generativelanguage.googleapis.com',
        '/v1beta/models/$_model:generateContent', {'key': key.trim()});
    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {'role': 'user', 'parts': [
              {'text': 'You are $persona, a concise voice assistant. '
                  'Reply in the user\'s language. Use tools when needed.\n\n$prompt'}
            ]}
          ],
          'tools': declarations,
          'generationConfig': {'temperature': 0.4, 'maxOutputTokens': 1024},
        }),
      ).timeout(const Duration(seconds: 25));

      if (response.statusCode != 200) {
        return BrainResponse.text('Gemini error ${response.statusCode}: ${_short(response.body)}');
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final parts = data['candidates']?[0]?['content']?['parts'] as List?;
      if (parts == null || parts.isEmpty) {
        return BrainResponse.text('Kuch jawab nahi mila.');
      }
      for (final part in parts) {
        final call = part['functionCall'];
        if (call != null) {
          return BrainResponse.tool(ToolCall.fromMap(Map<String, dynamic>.from(call)));
        }
      }
      final text = parts.firstWhere((p) => p['text'] != null, orElse: () => {})['text'];
      return BrainResponse.text(text?.toString() ?? 'Kuch nahi mila.');
    } catch (e) {
      return BrainResponse.text('Connection issue: $e');
    }
  }

  /// Translate a short reply into the target chat language.
  Future<String> translateReply({
    required String text,
    required String targetLanguage,
    required String chat,
  }) async {
    return respond(
      'Translate this reply into $targetLanguage for a WhatsApp chat with $chat. '
      'Return ONLY the translated text, no explanation, no quotes.\n\n$text',
    );
  }

  BrainResponse _parseBackendTool(String answer) {
    final trimmed = answer.trim();
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      try {
        final map = jsonDecode(trimmed) as Map<String, dynamic>;
        final name = map['tool'] as String?;
        if (name != null && name.isNotEmpty) {
          return BrainResponse.tool(ToolCall.fromMap({
            'name': name,
            'args': map['args'] ?? const {},
          }));
        }
      } catch (_) {
        // Not JSON - treat as plain answer.
      }
    }
    return BrainResponse.text(answer);
  }

  Future<String> _viaBackend(String base, String prompt, String persona) async {
    final uri = Uri.parse('${base.replaceAll(RegExp(r'/+$'), '')}/chat');
    final token = await KeyStore.instance.read(KeyStoreKeys.backendToken);
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null && token.trim().isNotEmpty) {
      headers['Authorization'] = 'Bearer ${token.trim()}';
    }
    try {
      final response = await http.post(
        uri,
        headers: headers,
        body: jsonEncode({'message': prompt, 'persona': persona}),
      ).timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        return 'Backend error ${response.statusCode}: ${_short(response.body)}';
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['reply']?.toString() ?? 'Kuch jawab nahi mila.';
    } catch (e) {
      return 'Backend connection issue: $e';
    }
  }

  Future<String> _direct(String prompt) async {
    final key = await KeyStore.instance.read(KeyStoreKeys.gemini);
    if (key == null || key.trim().isEmpty) {
      return 'Gemini key nahi hai — Settings me key ya backend URL daalo.';
    }
    final uri = Uri.https('generativelanguage.googleapis.com',
        '/v1beta/models/$_model:generateContent', {'key': key.trim()});
    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {'role': 'user', 'parts': [
              {'text': 'You are ZaRa, a concise voice assistant. Reply in the user\'s language.\n\n$prompt'}
            ]}
          ],
          'generationConfig': {'temperature': 0.4, 'maxOutputTokens': 1024},
        }),
      ).timeout(const Duration(seconds: 25));
      if (response.statusCode != 200) {
        return 'Gemini error ${response.statusCode}: ${_short(response.body)}';
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = data['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) return 'Kuch jawab nahi mila.';
      return candidates[0]['content']['parts'][0]['text']?.toString() ?? 'Kuch nahi mila.';
    } catch (e) {
      return 'Connection issue: $e';
    }
  }

  String _short(String s) => s.length > 120 ? '${s.substring(0, 120)}…' : s;
}
