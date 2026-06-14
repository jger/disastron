import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:disastron/features/inference/domain/predefined_inference_model.dart';
import 'package:easy_localization/easy_localization.dart';
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
      title: Text(
        preset == null
            ? 'install_metered_title'.tr()
            : 'install_metered_title_named'.tr(
                namedArgs: <String, String>{'name': preset.title},
              ),
      ),
      content: Text(
        '${presetBlock ?? ''}${'install_metered_body'.tr()}',
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text('cancel'.tr()),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text('continue'.tr()),
        ),
      ],
    ),
  );
  return ok ?? false;
}
