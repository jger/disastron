import 'dart:developer' as developer;

/// Debug console traces for chat / Gemma init (web reload hangs).
void chatInitLog(String step, [Object? detail]) {
  final String message = detail == null ? step : '$step | $detail';
  developer.log(message, name: 'disastron.chat_init');
}
