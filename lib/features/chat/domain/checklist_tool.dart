// SPDX-License-Identifier: MIT
// Copyright (c) 2024-2026 Jannis Gerardis

import 'package:disastron/features/todos/todos.dart';
import 'package:flutter_edge_ai/flutter_edge_ai.dart';

/// Max open items injected per turn (keeps prefill small).
const int kChecklistSnapshotMaxItems = 15;

const String kUpdateChecklistToolName = 'update_checklist';

/// Appended to the system prompt on Gemma 4 when native tool calling is active.
const String kNativeChecklistToolSystemInstruction = '''
When you suggest actionable checklist items the user should track, call the update_checklist tool (ops: add, setDone, remove). Use ids from the checklist snapshot in the user message for setDone/remove. Keep titles short. Do not embed [[TODOS]] JSON in your reply.
''';

const Tool kUpdateChecklistTool = Tool(
  name: kUpdateChecklistToolName,
  description: 'Update the user emergency checklist: add items, mark done, or remove by id.',
  parameters: <String, dynamic>{
    'type': 'object',
    'properties': <String, dynamic>{
      'ops': <String, dynamic>{
        'type': 'array',
        'description': 'Checklist mutations to apply in order.',
        'items': <String, dynamic>{
          'type': 'object',
          'properties': <String, dynamic>{
            'op': <String, dynamic>{
              'type': 'string',
              'enum': <String>['add', 'setDone', 'remove'],
            },
            'title': <String, dynamic>{
              'type': 'string',
              'description': 'Required for add.',
            },
            'id': <String, dynamic>{
              'type': 'string',
              'description': 'Required for setDone and remove.',
            },
            'done': <String, dynamic>{
              'type': 'boolean',
              'description': 'Required for setDone.',
            },
          },
          'required': <String>['op'],
        },
      },
    },
    'required': <String>['ops'],
  },
);

bool modelSupportsNativeChecklistTools({
  required ModelType? modelType,
  required ModelFileType fileType,
}) => modelType == ModelType.gemma4 && fileType == ModelFileType.litertlm;

/// Prefix block for the next user turn (Gemma 4 tool path).
String formatChecklistSnapshotForUserTurn(List<EmergencyTodo> todos) {
  if (todos.isEmpty) {
    return '[Current checklist: empty — use add ops only unless ids appear later.]';
  }
  final List<EmergencyTodo> open = todos
      .where((EmergencyTodo t) => !t.done)
      .take(kChecklistSnapshotMaxItems)
      .toList();
  final StringBuffer b = StringBuffer(
    '[Current checklist — use these ids for setDone/remove:]',
  );
  for (final EmergencyTodo t in open) {
    b.writeln('- id=${t.id} title=${t.title} done=${t.done}');
  }
  final int omitted =
      todos.where((EmergencyTodo t) => !t.done).length - open.length;
  if (omitted > 0) {
    b.writeln('($omitted more open items omitted)');
  }
  return b.toString().trimRight();
}

List<Map<String, dynamic>> checklistOpsFromToolArgs(Map<String, dynamic> args) {
  final Object? raw = args['ops'];
  if (raw is! List<dynamic>) {
    return <Map<String, dynamic>>[];
  }
  return raw.map((dynamic e) => Map<String, dynamic>.from(e as Map)).toList();
}

/// Result of applying checklist ops during a native tool call (for UI + tests).
class ChecklistTurnResult {
  const ChecklistTurnResult({
    required this.appliedCount,
    required this.addedTodoCount,
  });

  final int appliedCount;
  final int addedTodoCount;
}
