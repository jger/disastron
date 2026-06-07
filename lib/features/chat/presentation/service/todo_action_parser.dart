import 'dart:convert';

import 'package:disastron/features/todos/presentation/emergency_todos_provider.dart';
import 'package:disastron/features/todos/presentation/todo_tab_badge_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final RegExp _todoBlock = RegExp(
  r'\[\[TODOS\]\]\s*([\s\S]*?)(?:\[\[/TODOS\]\]|$)',
);

class ParsedTodoBlock {
  const ParsedTodoBlock({
    required this.displayText,
    required this.ops,
    this.rawJson,
  });

  final String displayText;
  final String? rawJson;
  final List<Map<String, dynamic>> ops;
}

/// Parses the assistant text, extracts the todo block and retrieves operations.
/// Supports missing `[[/TODOS]]` closing tag and tries to recover JSON if trailing
/// text or formatting is appended before the end of the input.
ParsedTodoBlock parseTodoBlock(String assistantText) {
  final Match? m = _todoBlock.firstMatch(assistantText);
  String display = assistantText;
  List<Map<String, dynamic>> opsList = [];
  String? rawJson;

  if (m != null) {
    display = assistantText.replaceRange(m.start, m.end, '').trimRight();
    final String captured = m.group(1)?.trim() ?? '';
    if (captured.isNotEmpty) {
      rawJson = captured;
      Map<String, dynamic>? decodedMap;
      try {
        final Object? decoded = jsonDecode(captured);
        if (decoded is Map<String, dynamic>) {
          decodedMap = decoded;
        }
      } on Object {
        // Fallback recovery: if the block was cut off or followed by trailing text
        // (like a separator, explanation, etc.) without a closing tag, find the
        // last closing brace and try to decode that substring.
        final int lastBrace = captured.lastIndexOf('}');
        if (lastBrace != -1) {
          final String subJson = captured.substring(0, lastBrace + 1);
          try {
            final Object? decodedSub = jsonDecode(subJson);
            if (decodedSub is Map<String, dynamic>) {
              decodedMap = decodedSub;
            }
          } on Object {
            // keep decodedMap null
          }
        }
      }

      if (decodedMap != null) {
        final List<dynamic>? ops =
            (decodedMap['ops'] ?? decodedMap['aps']) as List<dynamic>?;
        if (ops != null) {
          opsList = ops
              .map((dynamic e) => Map<String, dynamic>.from(e as Map))
              .toList();
        }
      }
    }
  }

  return ParsedTodoBlock(
    displayText: display.trim(),
    rawJson: rawJson,
    ops: opsList,
  );
}

/// Returns assistant text with `[[TODOS]]` blocks removed and applies ops to [EmergencyTodos].
Future<TodoApplyResult> stripTodosAndApply(
  WidgetRef ref,
  String assistantText,
) async {
  final ParsedTodoBlock parsed = parseTodoBlock(assistantText);
  int applied = 0;
  int addedTodoCount = 0;

  if (parsed.ops.isNotEmpty) {
    for (final Map<String, dynamic> op in parsed.ops) {
      if ((op['op'] as String?) == 'add' &&
          ((op['title'] as String?)?.trim().isNotEmpty ?? false)) {
        addedTodoCount++;
      }
    }
    await ref.read(emergencyTodosProvider.notifier).applyOps(parsed.ops);
    applied = parsed.ops.length;
    if (addedTodoCount > 0) {
      ref.read(todoTabBadgeProvider.notifier).addFromAssistant(addedTodoCount);
    }
  }

  return TodoApplyResult(
    displayText: parsed.displayText,
    appliedCount: applied,
    addedTodoCount: addedTodoCount,
  );
}

class TodoApplyResult {
  const TodoApplyResult({
    required this.displayText,
    required this.appliedCount,
    required this.addedTodoCount,
  });

  final String displayText;
  final int appliedCount;

  /// `add` ops with non-empty title (drives tab badge).
  final int addedTodoCount;
}
