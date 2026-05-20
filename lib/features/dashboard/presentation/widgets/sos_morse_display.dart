/// ***************************************************************************
/// Copyright (c) 2024 [Jannis Gerardis]
///
/// All rights reserved.
/// ***************************************************************************

library;

import 'package:disastron/features/dashboard/domain/sos_morse_codec.dart';
import 'package:flutter/material.dart';

/// Live Morse visualization for the SOS overlay message field.
class SosMorseDisplay extends StatelessWidget {
  const SosMorseDisplay({
    required this.messageUpper,
    required this.sequence,
    required this.tokenIndex,
    super.key,
  });

  final String messageUpper;
  final List<SosMorseToken> sequence;
  final int tokenIndex;

  bool _isSpanActive(int charIndex, int ditDahIndex) {
    if (sequence.isEmpty || tokenIndex >= sequence.length) {
      return false;
    }
    final SosMorseToken t = sequence[tokenIndex];
    if (t.type != SosMorseTokenType.dit && t.type != SosMorseTokenType.dah) {
      return false;
    }
    return t.charIndex == charIndex && t.ditDahIndex == ditDahIndex;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final String msg = messageUpper;
    if (msg.isEmpty) {
      return Text(
        'Enter A–Z / 0–9',
        style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
      );
    }

    final List<Widget> letterCols = <Widget>[];
    for (int i = 0; i < msg.length; i++) {
      final String ch = msg[i];
      if (ch == ' ') {
        letterCols.add(const SizedBox(width: 16));
        continue;
      }
      final String? pat = kSosMorsePattern[ch];
      if (pat == null) {
        continue;
      }
      final List<InlineSpan> spans = <InlineSpan>[];
      for (int j = 0; j < pat.length; j++) {
        final String sym = pat[j];
        final bool active = _isSpanActive(i, j);
        final TextStyle style = TextStyle(
          fontWeight: active ? FontWeight.w900 : FontWeight.w500,
          color: active ? scheme.error : scheme.onSurface,
          fontSize: 18,
          height: 1.2,
        );
        final String visual = sym == '.' ? '·' : '―';
        spans.add(TextSpan(text: visual, style: style));
        if (j < pat.length - 1) {
          spans.add(TextSpan(text: ' ', style: style));
        }
      }
      letterCols.add(
        Padding(
          padding: const EdgeInsets.only(right: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                ch,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              RichText(text: TextSpan(children: spans)),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: letterCols,
      ),
    );
  }
}
