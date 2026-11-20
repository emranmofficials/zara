class ToolSpec {
  final String name;
  final String description;
  final bool requiresConfirm;
  final bool licensed;
  final int tier;

  const ToolSpec({
    required this.name,
    required this.description,
    this.requiresConfirm = false,
    this.licensed = true,
    this.tier = 1,
  });
}

/// A small, original tool catalogue (scaffolding for the dispatcher).
const kTools = <ToolSpec>[
  ToolSpec(name: 'get_time', description: 'current time', licensed: false, tier: 0),
  ToolSpec(name: 'search_web', description: 'search the web', licensed: false, tier: 0),
  ToolSpec(name: 'find_tool', description: 'suggest a tool by name', licensed: false, tier: 0),
  ToolSpec(name: 'remember_fact', description: 'store a memory', tier: 0),
  ToolSpec(name: 'recall_memory', description: 'recall a memory', tier: 0),
  ToolSpec(name: 'chat_text', description: 'send a chat message', tier: 1),
  ToolSpec(name: 'reply_to_chat', description: 'reply to last chat', requiresConfirm: true, tier: 1),
  ToolSpec(name: 'send_sms', description: 'send an SMS', requiresConfirm: true, tier: 1),
  ToolSpec(name: 'make_call', description: 'place a call', requiresConfirm: true, tier: 1),
  ToolSpec(name: 'send_email', description: 'send an email', requiresConfirm: true, tier: 2),
  ToolSpec(name: 'set_alarm', description: 'set an alarm', tier: 1),
  ToolSpec(name: 'play_music', description: 'play music', tier: 1),
];

abstract final class ToolRegistry {
  /// Budget-limited list sent to the model (tier 0 first).
  static List<ToolSpec> budget(int max) {
    final sorted = [...kTools]..sort((a, b) => a.tier.compareTo(b.tier));
    return sorted.take(max).toList();
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
    for (var j = 0; j <= b.length; j++) dp[0][j] = j;
    for (var i = 1; i <= a.length; i++) {
      for (var j = 1; j <= b.length; j++) {
        dp[i][j] = a[i - 1] == b[j - 1]
            ? dp[i - 1][j - 1]
            : 1 + [dp[i - 1][j], dp[i][j - 1], dp[i - 1][j - 1]].reduce((x, y) => x < y ? x : y);
      }
    }
    return dp[a.length][b.length];
  }
}
