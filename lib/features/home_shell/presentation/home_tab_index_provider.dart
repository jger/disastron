/// Bottom nav index for the home tab shell (dashboard, todos, chat, wiki). Chat listens here.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

const int kHomeTabIndexChat = 2;

final StateProvider<int> homeBottomNavIndexProvider =
    StateProvider<int>((Ref ref) => 0);
