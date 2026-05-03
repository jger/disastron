import 'dart:convert';

import 'package:disastron/features/home/todos/emergency_todos_provider.dart';
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
            await ref.read(emergencyTodosProvider.notifier).applyOps(maps);
            applied = maps.length;
          }
        }
      } on Object {
        // ignore malformed JSON; keep display stripped
      }
    }
  }

  return TodoApplyResult(displayText: display.trim(), appliedCount: applied);
}

class TodoApplyResult {
  const TodoApplyResult({
    required this.displayText,
    required this.appliedCount,
  });

  final String displayText;
  final int appliedCount;
}
