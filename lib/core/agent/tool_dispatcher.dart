import '../models/models.dart';
import '../services/backend_client.dart';
import 'tool_registry.dart';

/// Executes tool calls produced by the model.
///
/// Prefers the optional Python backend (/execute); falls back to local stubs.
/// Tools that change something outside the app return [needsConfirm] = true;
/// AppState then shows a confirmation card before executing with confirmed=true.
class ToolDispatcher {
  const ToolDispatcher();

  ToolSpec? spec(String name) {
    for (final tool in kTools) {
      if (tool.name == name) return tool;
    }
    return null;
  }

  Future<ToolResult> execute(
    ToolCall call, {
    bool confirmed = false,
  }) async {
    final remote = await BackendClient.instance.execute(call, confirmed: confirmed);
    if (remote != null) return remote;
    return _executeLocal(call, confirmed: confirmed);
  }

  Future<ToolResult> _executeLocal(ToolCall call, {required bool confirmed}) async {
    final tool = spec(call.name);
    if (tool == null) {
      final suggestions = ToolRegistry.suggest(call.name);
      return ToolResult(
        tool: call.name,
        message: suggestions.isEmpty
            ? 'অজানা টুল: ${call.name}'
            : 'অজানা টুল: ${call.name}। হয়তো: ${suggestions.join(", ")}',
      );
    }

    if (tool.requiresConfirm && !confirmed) {
      return ToolResult(
        tool: tool.name,
        message: 'নিশ্চিত করুন: ${tool.description}?',
        needsConfirm: true,
        pendingArgs: call.args,
      );
    }

    switch (call.name) {
      case 'get_time':
        final now = DateTime.now();
        return ToolResult(
          tool: call.name,
          message: 'এখন ${now.hour.toString().padLeft(2, '0')}:'
              '${now.minute.toString().padLeft(2, '0')} বাজে।',
        );

      case 'find_tool':
        final query = call.args['query']?.toString() ?? '';
        final hits = ToolRegistry.suggest(query);
        return ToolResult(
          tool: call.name,
          message: hits.isEmpty ? 'কোনো টুল পাওয়া যায়নি।' : 'টুল: ${hits.join(", ")}',
        );

      case 'remember_fact':
        final fact = call.args['fact']?.toString();
        if (fact == null || fact.isEmpty) {
          return ToolResult(tool: call.name, message: 'কী মনে রাখব?');
        }
        return ToolResult(tool: call.name, message: 'মনে রাখব: $fact');

      case 'recall_memory':
        return ToolResult(tool: call.name, message: 'মেমরি স্টোর এখনো স্টাব।');

      case 'play_music':
        final song = call.args['query']?.toString() ?? 'সঙ্গীত';
        return ToolResult(tool: call.name, message: 'বাজাচ্ছি: $song');

      case 'set_alarm':
        final time = call.args['time']?.toString() ?? '?';
        return ToolResult(tool: call.name, message: '$time-এ অ্যালার্ম সেট করা হয়েছে।');

      case 'chat_text':
      case 'reply_to_chat':
      case 'send_sms':
      case 'make_call':
      case 'send_email':
        final target = call.args['to']?.toString() ??
            call.args['chat']?.toString() ??
            'unknown';
        return ToolResult(
          tool: call.name,
          message: '${tool.name} → $target (confirmed)',
        );

      default:
        return ToolResult(
          tool: call.name,
          message: 'টুল ${call.name} এখনো পাওয়া যাচ্ছে না।',
        );
    }
  }
}
