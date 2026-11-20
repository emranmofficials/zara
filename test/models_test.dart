import 'package:flutter_test/flutter_test.dart';
import 'package:zara/core/models/models.dart';

void main() {
  group('models', () {
    test('ChatMessage factories set isUser and serialise for history sync', () {
      final user = ChatMessage.user('namaste');
      final bot = ChatMessage.assistant('namaste bataiye');
      expect(user.isUser, isTrue);
      expect(bot.isUser, isFalse);
      expect(user.id, isNotEmpty);
      final map = user.toMap();
      expect(map['text'], 'namaste');
      expect(map['is_user'], isTrue);
      expect(map['at'], isA<String>());
    });

    test('ToolCall.fromMap tolerates missing args', () {
      final call = ToolCall.fromMap({'name': 'get_time'});
      expect(call.name, 'get_time');
      expect(call.args, isEmpty);
      final withArgs = ToolCall.fromMap({'name': 'send_sms', 'args': {'to': '123'}});
      expect(withArgs.args['to'], '123');
    });

    test('BrainResponse distinguishes text from tool calls', () {
      final text = BrainResponse.text('hello');
      final tool = BrainResponse.tool(const ToolCall(name: 'get_time', args: {}));
      expect(text.isTool, isFalse);
      expect(text.text, 'hello');
      expect(tool.isTool, isTrue);
      expect(tool.toolCall?.name, 'get_time');
    });

    test('reply confirmation models keep the RemoteInput token', () {
      const offer = VoiceReplyOffer(chat: 'Family', language: 'Hinglish', token: 'tok-1');
      const pending = PendingReply(
        chat: 'Family',
        language: 'Hinglish',
        original: 'kal miloge?',
        reply: 'Kal milte hain!',
        token: 'tok-1',
      );
      expect(offer.token, pending.token);
      expect(pending.reply, 'Kal milte hain!');
    });
  });
}
