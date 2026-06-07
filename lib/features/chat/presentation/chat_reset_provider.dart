import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';

/// Provider containing the reset callback for the active chat session.
/// The AppAppBar reads this to render the reset button and trigger it.
final chatResetProvider = StateProvider<VoidCallback?>((ref) => null);
