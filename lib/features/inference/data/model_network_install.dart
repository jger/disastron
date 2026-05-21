import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:disastron/features/inference/domain/predefined_inference_model.dart';
import 'package:flutter/material.dart';

/// Returns true when download may proceed. On non‑Wi‑Fi / non‑Ethernet, shows a
/// blocking confirmation dialog first.
Future<bool> confirmLargeDownloadIfNotLikelyUnmetered(
  BuildContext context, {
  PredefinedInferenceModel? preset,
}) async {
  final List<ConnectivityResult> results =
      await Connectivity().checkConnectivity();
  final bool unmeteredLikely = results.contains(ConnectivityResult.wifi) ||
      results.contains(ConnectivityResult.ethernet);
  if (unmeteredLikely) {
    return true;
  }
  if (!context.mounted) {
    return false;
  }
  final String? presetBlock = preset == null
      ? null
      : '${preset.title}\n${preset.downloadMetadataLine}\n\n';
  final bool? ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext ctx) => AlertDialog(
      title:
          Text(preset == null ? 'Large download' : 'Download ${preset.title}?'),
      content: Text(
        '${presetBlock ?? ''}'
        'You are not on Wi‑Fi. Downloading a model can use a large amount of '
        'mobile data. Continue?',
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Continue'),
        ),
      ],
    ),
  );
  return ok ?? false;
}
