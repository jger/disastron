import 'package:disastron/features/inference/data/model_network_install.dart';
import 'package:disastron/features/inference/domain/model_install_activity_kind.dart';
import 'package:disastron/features/inference/domain/predefined_models.dart';
import 'package:disastron/features/inference/presentation/huggingface_token_prompt_dialog.dart';
import 'package:disastron/features/inference/presentation/huggingface_token_provider.dart';
import 'package:disastron/features/inference/presentation/local_gemma_model_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shared preflight for dashboard + settings: token gate, metered confirm, install phase UI.
Future<bool> coordinateInferenceNetworkInstallPreflight({
  required BuildContext context,
  required WidgetRef ref,
  required PredefinedInferenceModel model,
  TextEditingController? tokenController,
}) async {
  ref
      .read(localGemmaModelProvider.notifier)
      .beginInstallFlow(ModelInstallActivityKind.downloadNetwork);
  if (model.requiresHuggingFaceToken) {
    final bool ok = await ensureHuggingFaceReadToken(
      context: context,
      ref: ref,
      tokenController: tokenController,
    );
    if (!ok) {
      ref.read(localGemmaModelProvider.notifier).abortInstallAttempt();
      return false;
    }
  }
  if (!context.mounted) {
    ref.read(localGemmaModelProvider.notifier).abortInstallAttempt();
    return false;
  }
  if (!await confirmLargeDownloadIfNotLikelyUnmetered(context)) {
    ref.read(localGemmaModelProvider.notifier).abortInstallAttempt();
    return false;
  }
  if (!context.mounted) {
    ref.read(localGemmaModelProvider.notifier).abortInstallAttempt();
    return false;
  }
  return true;
}

Future<bool> ensureHuggingFaceReadToken({
  required BuildContext context,
  required WidgetRef ref,
  TextEditingController? tokenController,
}) async {
  final String typed = tokenController?.text.trim() ?? '';
  if (typed.isNotEmpty) {
    return true;
  }
  final String? stored = await ref.read(huggingfaceTokenProvider.future);
  if (stored != null && stored.trim().isNotEmpty) {
    return true;
  }
  if (!context.mounted) {
    return false;
  }
  final String? pasted = await showHuggingFaceTokenPasteDialog(context);
  if (pasted == null || pasted.trim().isEmpty) {
    return false;
  }
  await ref.read(huggingfaceTokenProvider.notifier).save(pasted.trim());
  return context.mounted;
}

Future<bool> coordinateUrlInstallPreflight({
  required BuildContext context,
  required WidgetRef ref,
}) async {
  ref
      .read(localGemmaModelProvider.notifier)
      .beginInstallFlow(ModelInstallActivityKind.downloadNetwork);
  if (!await confirmLargeDownloadIfNotLikelyUnmetered(context)) {
    ref.read(localGemmaModelProvider.notifier).abortInstallAttempt();
    return false;
  }
  if (!context.mounted) {
    ref.read(localGemmaModelProvider.notifier).abortInstallAttempt();
    return false;
  }
  return true;
}
