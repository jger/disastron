// SPDX-License-Identifier: MIT
// Copyright (c) 2024-2026 Jannis Gerardis

import 'package:auto_route/auto_route.dart';
import 'package:disastron/features/todos/presentation/emergency_todos_provider.dart';
import 'package:easy_localization/easy_localization.dart';
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
            'todos_heading'.tr(),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'todos_subtitle'.tr(),
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
                      'todos_empty'.tr(),
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
                        'todos_id_prefix'.tr(
                          namedArgs: <String, String>{'id': t.id},
                        ),
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
            label: Text('todos_add'.tr()),
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
          title: Text('todos_add_dialog_title'.tr()),
          content: TextField(
            controller: c,
            autofocus: true,
            decoration: InputDecoration(hintText: 'todos_add_hint'.tr()),
            onSubmitted: (String s) => Navigator.pop(ctx, s),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('cancel'.tr()),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, c.text),
              child: Text('todos_add_confirm'.tr()),
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
