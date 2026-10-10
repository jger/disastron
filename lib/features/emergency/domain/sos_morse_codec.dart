// SPDX-License-Identifier: MIT
// Copyright (c) 2024-2026 Jannis Gerardis

/// Paris-ish dit (one unit) length bounds for the speed slider (ms).
const int kSosMorseUnitMsSlow = 500;
const int kSosMorseUnitMsFastFloor = 72;

/// ITU Morse patterns (dot/dash).
const Map<String, String> kSosMorsePattern = <String, String>{
  'A': '.-',
  'B': '-...',
  'C': '-.-.',
  'D': '-..',
  'E': '.',
  'F': '..-.',
  'G': '--.',
  'H': '....',
  'I': '..',
  'J': '.---',
  'K': '-.-',
  'L': '.-..',
  'M': '--',
  'N': '-.',
  'O': '---',
  'P': '.--.',
  'Q': '--.-',
  'R': '.-.',
  'S': '...',
  'T': '-',
  'U': '..-',
  'V': '...-',
  'W': '.--',
  'X': '-..-',
  'Y': '-.--',
  'Z': '--..',
  '0': '-----',
  '1': '.----',
  '2': '..---',
  '3': '...--',
  '4': '....-',
  '5': '.....',
  '6': '-....',
  '7': '--...',
  '8': '---..',
  '9': '----.',
};

enum SosMorseTokenType { dit, dah, symbolGap, letterGap, wordGap }

class SosMorseToken {
  const SosMorseToken(this.type, this.charIndex, this.ditDahIndex);

  final SosMorseTokenType type;
  final int charIndex;
  final int? ditDahIndex;
}

/// Builds the timed Morse token stream for [raw] (A–Z, 0–9, spaces).
List<SosMorseToken> buildSosMorseSequence(String raw) {
  final List<SosMorseToken> tokens = <SosMorseToken>[];
  final String msg = raw.toUpperCase().trim();
  if (msg.isEmpty) {
    return tokens;
  }

  bool prevLetter = false;
  for (int i = 0; i < msg.length; i++) {
    final String c = msg[i];
    if (c == ' ') {
      if (prevLetter) {
        tokens.add(SosMorseToken(SosMorseTokenType.wordGap, i, null));
        prevLetter = false;
      }
      continue;
    }
    final String? pat = kSosMorsePattern[c];
    if (pat == null) {
      continue;
    }
    if (prevLetter) {
      tokens.add(SosMorseToken(SosMorseTokenType.letterGap, i, null));
    }
    for (int j = 0; j < pat.length; j++) {
      final String sym = pat[j];
      if (sym == '.') {
        tokens.add(SosMorseToken(SosMorseTokenType.dit, i, j));
      } else if (sym == '-') {
        tokens.add(SosMorseToken(SosMorseTokenType.dah, i, j));
      }
      if (j < pat.length - 1) {
        tokens.add(SosMorseToken(SosMorseTokenType.symbolGap, i, null));
      }
    }
    prevLetter = true;
  }
  return tokens;
}
