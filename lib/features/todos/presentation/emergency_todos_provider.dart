import 'dart:convert';

import 'package:disastron/core/preferences/prefs_keys.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'emergency_todos_provider.g.dart';

class EmergencyTodo {
  const EmergencyTodo({
    required this.id,
    required this.title,
    required this.done,
    required this.createdAtMs,
  });

  factory EmergencyTodo.fromJson(Map<String, dynamic> json) {
    return EmergencyTodo(
      id: json['id'] as String,
      title: json['title'] as String,
      done: json['done'] as bool? ?? false,
      createdAtMs:
          json['createdAtMs'] as int? ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  final String id;
  final String title;
  final bool done;
  final int createdAtMs;

  EmergencyTodo copyWith({String? title, bool? done}) {
    return EmergencyTodo(
      id: id,
      title: title ?? this.title,
      done: done ?? this.done,
      createdAtMs: createdAtMs,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'title': title,
    'done': done,
    'createdAtMs': createdAtMs,
  };
}

@Riverpod(keepAlive: true)
class EmergencyTodos extends _$EmergencyTodos {
  @override
  Future<List<EmergencyTodo>> build() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(PrefsKeys.emergencyTodos);
    if (raw == null || raw.isEmpty) {
      return <EmergencyTodo>[];
    }
    final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((dynamic e) => EmergencyTodo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  List<EmergencyTodo> _current() {
    return List<EmergencyTodo>.from(state.value ?? <EmergencyTodo>[]);
  }

  Future<void> _save(List<EmergencyTodo> next) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      PrefsKeys.emergencyTodos,
      jsonEncode(next.map((EmergencyTodo e) => e.toJson()).toList()),
    );
    state = AsyncValue<List<EmergencyTodo>>.data(next);
  }

  Future<void> add(String title) async {
    final String t = title.trim();
    if (t.isEmpty) {
      return;
    }
    final List<EmergencyTodo> list = _current();
    final EmergencyTodo todo = EmergencyTodo(
      id: '${DateTime.now().microsecondsSinceEpoch}-${list.length}',
      title: t,
      done: false,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    await _save(<EmergencyTodo>[...list, todo]);
  }

  Future<void> setDone(String id, {required bool done}) async {
    final List<EmergencyTodo> list = _current();
    await _save(
      list
          .map((EmergencyTodo e) => e.id == id ? e.copyWith(done: done) : e)
          .toList(),
    );
  }

  Future<void> remove(String id) async {
    final List<EmergencyTodo> list = _current();
    await _save(list.where((EmergencyTodo e) => e.id != id).toList());
  }

  Future<void> applyOps(List<Map<String, dynamic>> ops) async {
    List<EmergencyTodo> next = _current();
    for (final Map<String, dynamic> op in ops) {
      final String kind = op['op'] as String? ?? '';
      if (kind == 'add') {
        final String title = op['title'] as String? ?? '';
        if (title.trim().isEmpty) {
          continue;
        }
        next = <EmergencyTodo>[
          ...next,
          EmergencyTodo(
            id: '${DateTime.now().microsecondsSinceEpoch}-${next.length}',
            title: title.trim(),
            done: false,
            createdAtMs: DateTime.now().millisecondsSinceEpoch,
          ),
        ];
      } else if (kind == 'setDone') {
        final String? id = op['id'] as String?;
        final bool done = op['done'] as bool? ?? true;
        if (id == null) {
          continue;
        }
        next = next
            .map((EmergencyTodo e) => e.id == id ? e.copyWith(done: done) : e)
            .toList();
      } else if (kind == 'remove') {
        final String? id = op['id'] as String?;
        if (id != null) {
          next = next.where((EmergencyTodo e) => e.id != id).toList();
        }
      }
    }
    await _save(next);
  }
}
