import 'package:disastron/features/chat/presentation/service/todo_action_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TodoActionParser Tests', () {
    test('Standard case: matching with correct tags', () {
      const String text = '''
Hello! I have created the checklist items for you.
[[TODOS]]
{"ops":[{"op":"add","title":"Call emergency services immediately"}]}
[[/TODOS]]
''';
      final parsed = parseTodoBlock(text);
      expect(
        parsed.displayText,
        equals('Hello! I have created the checklist items for you.'),
      );
      expect(parsed.ops, hasLength(1));
      expect(parsed.ops.first['op'], equals('add'));
      expect(
        parsed.ops.first['title'],
        equals('Call emergency services immediately'),
      );
    });

    test('Missing closing tag case', () {
      const String text = '''
Checklist created.
[[TODOS]]
{"ops":[{"op":"add","title":"Apply direct pressure to wound"}]}''';
      final parsed = parseTodoBlock(text);
      expect(parsed.displayText, equals('Checklist created.'));
      expect(parsed.ops, hasLength(1));
      expect(parsed.ops.first['op'], equals('add'));
      expect(
        parsed.ops.first['title'],
        equals('Apply direct pressure to wound'),
      );
    });

    test('Missing closing tag with trailing explanation text (JSON recovery)',
        () {
      const String text = '''
Here are the steps:
[[TODOS]]
{"ops":[{"op":"add","title":"Elevate the injured area"}]}
----
Let me know if you need more help!''';
      final parsed = parseTodoBlock(text);
      expect(parsed.displayText, equals('Here are the steps:'));
      expect(parsed.ops, hasLength(1));
      expect(parsed.ops.first['op'], equals('add'));
      expect(parsed.ops.first['title'], equals('Elevate the injured area'));
    });

    test('Empty or no block case', () {
      const String text = 'Hello world, no checklist here.';
      final parsed = parseTodoBlock(text);
      expect(parsed.displayText, equals('Hello world, no checklist here.'));
      expect(parsed.ops, isEmpty);
    });
  });
}
