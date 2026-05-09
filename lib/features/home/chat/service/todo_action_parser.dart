import 'dart:convert';

import 'package:disastron/features/home/todos/emergency_todos_provider.dart';
import 'package:disastron/features/home/todos/todo_tab_badge_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final RegExp _todoBlock = RegExp(
  r'\[\[TODOS\]\]\s*([\s\S]*?)\[\[/TODOS\]\]',
  multiLine: true,
);

/// Returns assistant text with `[[TODOS]]` blocks removed and applies ops to [EmergencyTodos].
Future<TodoApplyResult> stripTodosAndApply(
  WidgetRef ref,
  String assistantText,
) async {
  final Match? m = _todoBlock.firstMatch(assistantText);
  String display = assistantText;
  int applied = 0;
  int addedTodoCount = 0;

  if (m != null) {
    display =
        assistantText.replaceRange(m.start, m.end, '').trimRight();
    final String rawJson = m.group(1)?.trim() ?? '';
    if (rawJson.isNotEmpty) {
      try {
        final Object? decoded = jsonDecode(rawJson);
        if (decoded is Map<String, dynamic>) {
          final List<dynamic>? ops =
              (decoded['ops'] ?? decoded['aps']) as List<dynamic>?;
          if (ops != null && ops.isNotEmpty) {
            final List<Map<String, dynamic>> maps = ops
                .map((dynamic e) => Map<String, dynamic>.from(e as Map))
                .toList();
            for (final Map<String, dynamic> op in maps) {
              if ((op['op'] as String?) == 'add' &&
                  ((op['title'] as String?)?.trim().isNotEmpty ?? false)) {
                addedTodoCount++;
              }
            }
            await ref.read(emergencyTodosProvider.notifier).applyOps(maps);
            applied = maps.length;
            if (addedTodoCount > 0) {
              ref
                  .read(todoTabBadgeProvider.notifier)
                  .addFromAssistant(addedTodoCount);
            }
          }
        }
      } on Object {
        // ignore malformed JSON; keep display stripped
      }
    }
  }

  return TodoApplyResult(
    displayText: display.trim(),
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
