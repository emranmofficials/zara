import 'package:flutter_test/flutter_test.dart';
import 'package:zara/core/agent/tool_registry.dart';

void main() {
  group('ToolRegistry', () {
    test('catalogue is non-empty and unique', () {
      expect(kTools.isNotEmpty, isTrue);
      expect(kTools.map((t) => t.name).toSet().length, kTools.length);
    });

    test('budget returns tier-0 tools first and respects the limit', () {
      final budget = ToolRegistry.budget(4);
      expect(budget.length, 4);
      expect(budget.every((t) => t.tier == 0), isTrue);
      expect(ToolRegistry.budget(0), isEmpty);
      expect(ToolRegistry.budget(100).length, kTools.length);
    });

    test('confirm-required tools are the messaging/calling ones', () {
      final names = kTools.where((t) => t.requiresConfirm).map((t) => t.name).toList();
      expect(names, contains('reply_to_chat'));
      expect(names, contains('send_sms'));
      expect(names, contains('make_call'));
      expect(names, contains('send_email'));
      expect(names, isNot(contains('get_time')));
    });

    test('declarations are one tools entry with per-tool schemas', () {
      final declarations = ToolRegistry.declarations(8);
      expect(declarations.length, 8);
      final sms = declarations.firstWhere((d) => d['name'] == 'send_sms');
      final parameters = sms['parameters'] as Map<String, dynamic>;
      final properties = parameters['properties'] as Map<String, dynamic>;
      expect(properties['to'], {'type': 'STRING'});
      expect(parameters['required'], contains('to'));
      expect(sms['description'], contains('confirmation'));
    });

    test('normalize folds packed args and alias keys', () {
      final args = ToolRegistry.normalize('reply_to_chat', <String, dynamic>{
        'args_json': '{"chat":"friends","text_arg":"সালাম"}',
      });
      expect(args['chat'], 'friends');
      expect(args['text'], 'সালাম');
      expect(args.containsKey('text_arg'), isFalse);
    });

    test('fuzzy suggest tolerates typos', () {
      expect(ToolRegistry.suggest('get_tiem').first, 'get_time');
      expect(ToolRegistry.suggest('recall_memroy').first, 'recall_memory');
      expect(ToolRegistry.suggest(''), isEmpty);
    });
  });
}
