import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

/// Bottom nav index aligned with HomePage destinations: Dashboard, Todos, Chat, Wiki.
const int kHomeTabIndexChat = 2;

final StateProvider<int> homeBottomNavIndexProvider =
    StateProvider<int>((Ref ref) => 0);
