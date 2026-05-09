import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'todo_tab_badge_provider.g.dart';

/// Count of todos added from assistant [[TODOS]] blocks since user opened Todos tab.
@Riverpod(keepAlive: true)
class TodoTabBadge extends _$TodoTabBadge {
  @override
  int build() => 0;

  void addFromAssistant(int n) {
    if (n <= 0) {
      return;
    }
    state = state + n;
  }

  void clear() {
    state = 0;
  }
}
