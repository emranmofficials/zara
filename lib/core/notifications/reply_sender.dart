import 'package:flutter/services.dart';

class ReplyTarget {
  final String token;
  final String chat;
  final String pkg;
  final int at;

  const ReplyTarget({
    required this.token,
    required this.chat,
    required this.pkg,
    required this.at,
  });

  factory ReplyTarget.fromMap(Map<dynamic, dynamic> m) => ReplyTarget(
        token: m['token'] as String? ?? '',
        chat: m['chat'] as String? ?? '',
        pkg: m['pkg'] as String? ?? '',
        at: (m['at'] as num?)?.toInt() ?? 0,
      );
}

/// Bridge to the Android NotificationListenerService via MethodChannel.
class ReplySender {
  static const _channel = MethodChannel('com.zaraai.app/notifications');

  static Future<List<ReplyTarget>> pendingReplies() async {
    try {
      final list = await _channel.invokeListMethod<dynamic>('getReplies') ?? [];
      return list
          .whereType<Map<dynamic, dynamic>>()
          .map(ReplyTarget.fromMap)
          .toList();
    } on MissingPluginException {
      return const [];
    }
  }

  static Future<bool> send(String token, String text) async {
    try {
      return await _channel.invokeMethod<bool>('sendReply', {
            'token': token,
            'text': text,
          }) ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<void> openNotificationSettings() async {
    try {
      await _channel.invokeMethod('openNotificationSettings');
    } on MissingPluginException {
      // Desktop / unsupported platform.
    }
  }
}
