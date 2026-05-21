// SPDX-License-Identifier: MIT
// Copyright (c) 2024-2026 Jannis Gerardis

import 'package:flutter/material.dart';

/// Shared Hugging Face read-token field (settings + paste dialog).
class HuggingFaceTokenInput extends StatelessWidget {
  const HuggingFaceTokenInput({
    required this.controller,
    super.key,
    this.labelText,
    this.hintText = 'hf_…',
  });

  final TextEditingController controller;
  final String? labelText;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: true,
      autocorrect: false,
      enableSuggestions: false,
      decoration: InputDecoration(
        border: const OutlineInputBorder(),
        labelText: labelText,
        hintText: hintText,
        isDense: true,
      ),
    );
  }
}
