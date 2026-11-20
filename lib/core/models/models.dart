import 'package:uuid/uuid.dart';

enum ChatMessageKind { text, voice, tool }

class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime at;
  final ChatMessageKind kind;

  ChatMessage({
    String? id,
    required this.text,
    required this.isUser,
    DateTime? at,
    this.kind = ChatMessageKind.text,
  })  : id = id ?? const Uuid().v4(),
        at = at ?? DateTime.now();

  ChatMessage.user(String text) : this(text: text, isUser: true);
  ChatMessage.assistant(String text) : this(text: text, isUser: false);
  ChatMessage.voice(String text)
      : this(text: text, isUser: true, kind: ChatMessageKind.voice);
  ChatMessage.tool(String text)
      : this(text: text, isUser: false, kind: ChatMessageKind.tool);

  Map<String, dynamic> toMap() => {
        'text': text,
        'is_user': isUser,
        'kind': kind.name,
        'at': at.toIso8601String(),
      };
}

class VoiceReplyOffer {
  final String chat;
  final String language;
  final String token;

  const VoiceReplyOffer({
    required this.chat,
    required this.language,
    required this.token,
  });
}

class PendingReply {
  final String chat;
  final String language;
  final String original;
  final String reply;
  final String token;

  const PendingReply({
    required this.chat,
    required this.language,
    required this.original,
    required this.reply,
    required this.token,
  });
}

/// A tool call requested by the model.
class ToolCall {
  final String name;
  final Map<String, dynamic> args;

  const ToolCall({required this.name, required this.args});

  factory ToolCall.fromMap(Map<String, dynamic> map) => ToolCall(
        name: map['name'] as String? ?? '',
        args: Map<String, dynamic>.from(map['args'] as Map? ?? const {}),
      );
}

/// Result of executing a tool. [needsConfirm] means a card must be shown first.
class ToolResult {
  final String tool;
  final String message;
  final bool needsConfirm;
  final Map<String, dynamic> pendingArgs;

  const ToolResult({
    required this.tool,
    required this.message,
    this.needsConfirm = false,
    this.pendingArgs = const {},
  });
}

/// A tool waiting for the user's Yes/No.
class PendingTool {
  final ToolCall call;
  final String description;

  const PendingTool({required this.call, required this.description});
}

/// Either a plain text answer or a tool call requested by the model.
class BrainResponse {
  final String? text;
  final ToolCall? toolCall;

  const BrainResponse._({this.text, this.toolCall});

  factory BrainResponse.text(String text) => BrainResponse._(text: text);
  factory BrainResponse.tool(ToolCall call) => BrainResponse._(toolCall: call);

  bool get isTool => toolCall != null;
}
