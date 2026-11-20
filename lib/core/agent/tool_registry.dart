import 'dart:convert';

class ToolSpec {
  final String name;
  final String description;
  final bool requiresConfirm;
  final bool licensed;
  final int tier;
  final Map<String, String> argTypes;
  final List<String> requiredArgs;

  const ToolSpec({
    required this.name,
    required this.description,
    this.requiresConfirm = false,
    this.licensed = true,
    this.tier = 1,
    this.argTypes = const <String, String>{},
    this.requiredArgs = const <String>[],
  });
}

/// A small, original tool catalogue. Tier 0 tools are safe and always declared;
/// higher tiers are declared when the tool budget allows it.
const kTools = <ToolSpec>[
  ToolSpec(
    name: 'get_time',
    description: 'বর্তমান সময় বলো',
    licensed: false,
    tier: 0,
  ),
  ToolSpec(
    name: 'search_web',
    description: 'ইন্টারনেটে তথ্য খুঁজো',
    licensed: false,
    tier: 0,
    argTypes: <String, String>{'query': 'string'},
    requiredArgs: <String>['query'],
  ),
  ToolSpec(
    name: 'find_tool',
    description: 'নাম বা কাজ দিয়ে উপযুক্ত টুল খুঁজো',
    licensed: false,
    tier: 0,
    argTypes: <String, String>{'query': 'string'},
    requiredArgs: <String>['query'],
  ),
  ToolSpec(
    name: 'remember_fact',
    description: 'ব্যবহারকারীর একটি তথ্য মনে রাখো',
    tier: 0,
    argTypes: <String, String>{'fact': 'string'},
    requiredArgs: <String>['fact'],
  ),
  ToolSpec(
    name: 'recall_memory',
    description: 'আগে মনে রাখা তথ্য বের করো',
    tier: 0,
    argTypes: <String, String>{'query': 'string'},
  ),
  ToolSpec(
    name: 'chat_text',
    description: 'চ্যাটে বার্তা লেখো',
    tier: 1,
    argTypes: <String, String>{'to': 'string', 'text': 'string'},
    requiredArgs: <String>['to', 'text'],
  ),
  ToolSpec(
    name: 'reply_to_chat',
    description: 'সর্বশেষ চ্যাটে উত্তর দাও',
    requiresConfirm: true,
    tier: 1,
    argTypes: <String, String>{'chat': 'string', 'text': 'string'},
    requiredArgs: <String>['text'],
  ),
  ToolSpec(
    name: 'send_sms',
    description: 'এসএমএস পাঠাও',
    requiresConfirm: true,
    tier: 1,
    argTypes: <String, String>{'to': 'string', 'text': 'string'},
    requiredArgs: <String>['to', 'text'],
  ),
  ToolSpec(
    name: 'make_call',
    description: 'ফোন কল করো',
    requiresConfirm: true,
    tier: 1,
    argTypes: <String, String>{'to': 'string'},
    requiredArgs: <String>['to'],
  ),
  ToolSpec(
    name: 'send_email',
    description: 'ইমেইল পাঠাও',
    requiresConfirm: true,
    tier: 2,
    argTypes: <String, String>{
      'to': 'string',
      'subject': 'string',
      'text': 'string',
    },
    requiredArgs: <String>['to', 'text'],
  ),
  ToolSpec(
    name: 'set_alarm',
    description: 'অ্যালার্ম সেট করো',
    tier: 1,
    argTypes: <String, String>{'time': 'string'},
    requiredArgs: <String>['time'],
  ),
  ToolSpec(
    name: 'play_music',
    description: 'সঙ্গীত বাজাও',
    tier: 1,
    argTypes: <String, String>{'query': 'string'},
    requiredArgs: <String>['query'],
  ),
];

abstract final class ToolRegistry {
  /// Budget-limited list sent to the model (tier 0 first).
  static List<ToolSpec> budget(int max) {
    final sorted = [...kTools]..sort((a, b) => a.tier.compareTo(b.tier));
    return sorted.take(max).toList();
  }

  /// One `functionDeclarations` array for the whole `tools` entry, matching
  /// the shape expected by generateContent.
  static List<Map<String, dynamic>> declarations(int max) => budget(max)
      .map(
        (t) => <String, dynamic>{
          'name': t.name,
          'description': t.requiresConfirm
              ? '${t.description} (action needs user confirmation)'
              : t.description,
          'parameters': <String, dynamic>{
            'type': 'OBJECT',
            'properties': <String, dynamic>{
              for (final entry in t.argTypes.entries)
                entry.key: <String, dynamic>{
                  'type': entry.value.toUpperCase(),
                },
            },
            if (t.requiredArgs.isNotEmpty) 'required': t.requiredArgs,
          },
        },
      )
      .toList(growable: false);

  /// Coerce loosely-typed model arguments into the declared shape.
  ///
  /// Models sometimes return `args_json` as a string or use `text_arg`
  /// instead of `text`; both are folded into the declared schema before a tool
  /// is dispatched. This is the clean-room equivalent of tolerant arg parsing.
  static Map<String, dynamic> normalize(String name, Map<String, dynamic> args) {
    final spec = kTools.where((t) => t.name == name).cast<ToolSpec?>().firstWhere(
          (_) => true,
          orElse: () => null,
        );
    if (spec == null) return args;

    Map<String, dynamic> source = Map<String, dynamic>.from(args);
    final packed = source.remove('args_json') ?? source.remove('args');
    if (packed is String) {
      try {
        final decoded = jsonDecode(packed);
        if (decoded is Map) source = Map<String, dynamic>.from(decoded);
      } catch (_) {
        // Keep the original arguments when the string is not JSON.
      }
    }
    if (!source.containsKey('text') && source.containsKey('text_arg')) {
      source['text'] = source.remove('text_arg');
    }

    final result = <String, dynamic>{};
    for (final entry in source.entries) {
      final expected = spec.argTypes[entry.key];
      if (expected == 'string') {
        result[entry.key] = entry.value?.toString() ?? '';
      } else if (expected == 'number' && entry.value is! num) {
        result[entry.key] = num.tryParse(entry.value?.toString() ?? '');
      } else if (expected == 'boolean' && entry.value is! bool) {
        result[entry.key] = entry.value.toString().toLowerCase() == 'true';
      } else {
        result[entry.key] = entry.value;
      }
    }
    return result;
  }

  /// Lightweight fuzzy suggestion for unknown tool names.
  static List<String> suggest(String query) {
    final q = query.toLowerCase();
    final scored = kTools
        .map((t) => (name: t.name, score: _distance(q, t.name.toLowerCase())))
        .where((e) => e.score <= 4)
        .toList()
      ..sort((a, b) => a.score.compareTo(b.score));
    return scored.map((e) => e.name).toList();
  }

  static int _distance(String a, String b) {
    final dp = List.generate(a.length + 1, (i) => List<int>.filled(b.length + 1, i));
    for (var j = 0; j <= b.length; j++) {
      dp[0][j] = j;
    }
    for (var i = 1; i <= a.length; i++) {
      for (var j = 1; j <= b.length; j++) {
        dp[i][j] = a[i - 1] == b[j - 1]
            ? dp[i - 1][j - 1]
            : 1 + [dp[i - 1][j], dp[i][j - 1], dp[i - 1][j - 1]].reduce((x, y) {
                return x < y ? x : y;
              });
      }
    }
    return dp[a.length][b.length];
  }
}
