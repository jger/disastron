// SPDX-License-Identifier: MIT
// Copyright (c) 2024-2026 Jannis Gerardis

import 'package:disastron/features/inference/data/huggingface_token_store.dart';
import 'package:disastron/features/inference/data/model_download_resume_service.dart';
import 'package:disastron/features/inference/data/predefined_models_loader.dart';
import 'package:flutter_edge_ai/flutter_edge_ai.dart';
import 'package:flutter_edge_ai_litertlm/flutter_edge_ai_litertlm.dart';
import 'package:flutter_edge_ai_mediapipe/flutter_edge_ai_mediapipe.dart';

/// Inference engine startup (called from main before runApp).
abstract final class InferenceBootstrap {
  InferenceBootstrap._();

  static Future<void> loadPredefinedInferenceModels() =>
      PredefinedInferenceModelsLoader.ensureLoaded();

  static Future<void> _initializeGemma(String? huggingFaceToken) async {
    await FlutterEdgeAi.initialize(
      huggingFaceToken: huggingFaceToken,
      inferenceEngines: const [LiteRtLmEngine(), MediaPipeEngine()],
    );
    await ModelDownloadResumeService.prepareOnStartup();
  }

  static Future<void> initializeGemma() async =>
      _initializeGemma(await HuggingfaceTokenStore().read());

  static Future<void> initializeGemmaWithToken(String? token) async {
    final String trimmed = token?.trim() ?? '';
    await _initializeGemma(trimmed.isEmpty ? null : trimmed);
  }
}
