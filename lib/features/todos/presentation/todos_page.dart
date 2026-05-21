// SPDX-License-Identifier: MIT
// Copyright (c) 2024-2026 Jannis Gerardis

import 'package:auto_route/auto_route.dart';
import 'package:disastron/features/todos/presentation/emergency_todos_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@RoutePage()
class TodosPage extends ConsumerWidget {
  const TodosPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<EmergencyTodo>> async =
        ref.watch(emergencyTodosProvider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Emergency checklist',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Items can be added here or by the assistant in Messages (via structured replies).',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: async.when(
              data: (List<EmergencyTodo> list) {
                if (list.isEmpty) {
                  return Center(
                    child: Text(
                      'No items yet.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (BuildContext context, int i) {
                    final EmergencyTodo t = list[i];
                    return CheckboxListTile(
                      title: Text(t.title),
                      subtitle: Text(
                        'id: ${t.id}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      value: t.done,
                      onChanged: (bool? v) {
                        if (v != null) {
                          ref
                              .read(emergencyTodosProvider.notifier)
                              .setDone(t.id, done: v);
                        }
                      },
                      secondary: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => ref
                            .read(emergencyTodosProvider.notifier)
                            .remove(t.id),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (Object e, StackTrace st) => Center(child: Text('$e')),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () => _promptAdd(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('Add item'),
          ),
        ],
      ),
    );
  }

  Future<void> _promptAdd(BuildContext context, WidgetRef ref) async {
    final String? text = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) {
        final TextEditingController c = TextEditingController();
        return AlertDialog(
          title: const Text('New checklist item'),
          content: TextField(
            controller: c,
            autofocus: true,
            decoration:
                const InputDecoration(hintText: 'Short actionable step'),
            onSubmitted: (String s) => Navigator.pop(ctx, s),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, c.text),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
    if (text != null && text.trim().isNotEmpty) {
      await ref.read(emergencyTodosProvider.notifier).add(text);
    }
  }
}
