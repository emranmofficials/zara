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
            ? 'Unknown tool: ${call.name}'
            : 'Unknown tool: ${call.name}. Shayad: ${suggestions.join(", ")}',
      );
    }

    if (tool.requiresConfirm && !confirmed) {
      return ToolResult(
        tool: tool.name,
        message: 'Confirm karein: ${tool.description}?',
        needsConfirm: true,
        pendingArgs: call.args,
      );
    }

    switch (call.name) {
      case 'get_time':
        final now = DateTime.now();
        return ToolResult(
          tool: call.name,
          message: 'Abhi ${now.hour.toString().padLeft(2, '0')}:'
              '${now.minute.toString().padLeft(2, '0')} baja hai.',
        );

      case 'find_tool':
        final query = call.args['query']?.toString() ?? '';
        final hits = ToolRegistry.suggest(query);
        return ToolResult(
          tool: call.name,
          message: hits.isEmpty ? 'Koi tool nahi mila.' : 'Tools: ${hits.join(", ")}',
        );

      case 'remember_fact':
        final fact = call.args['fact']?.toString();
        if (fact == null || fact.isEmpty) {
          return ToolResult(tool: call.name, message: 'Kya yaad rakhoon?');
        }
        return ToolResult(tool: call.name, message: 'Yaad rakh lunga: $fact');

      case 'recall_memory':
        return ToolResult(tool: call.name, message: 'Memory store abhi stub hai.');

      case 'play_music':
        final song = call.args['query']?.toString() ?? 'music';
        return ToolResult(tool: call.name, message: 'Baja raha hoon: $song');

      case 'set_alarm':
        final time = call.args['time']?.toString() ?? '?';
        return ToolResult(tool: call.name, message: 'Alarm set for $time.');

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
          message: 'Tool ${call.name} abhi available nahi hai.',
        );
    }
  }
}
