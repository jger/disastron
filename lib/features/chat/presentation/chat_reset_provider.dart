import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';

/// Provider containing the reset callback for the active chat session.
/// The AppAppBar reads this to render the reset button and trigger it.
final chatResetProvider = StateProvider<VoidCallback?>((ref) => null);

/// Provider to track whether Disastron context (weather, battery, location, etc.)
/// should be included in the LLM chat context.
final useDisastronContextProvider = StateProvider<bool>((ref) => true);
