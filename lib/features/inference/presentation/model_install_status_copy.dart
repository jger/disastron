import 'package:disastron/features/inference/domain/model_install_activity_kind.dart';
import 'package:disastron/features/inference/domain/predefined_models.dart';
import 'package:disastron/features/inference/presentation/local_gemma_model_provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class InstallStatusCopy {
  const InstallStatusCopy({
    required this.title,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
}

String _modelDisplayName(LocalGemmaModelUi ui) {
  if (ui.pendingPresetId != null) {
    final PredefinedInferenceModel? model =
        presetInferenceModelById(ui.pendingPresetId!);
    if (model != null) {
      return model.title;
    }
  }
  if (ui.pendingDownloadUrl != null) {
    final String urlOrPath = ui.pendingDownloadUrl!;
    final Uri uri =
        urlOrPath.contains('://') ? Uri.parse(urlOrPath) : Uri.file(urlOrPath);
    if (uri.pathSegments.isNotEmpty) {
      return uri.pathSegments.last;
    }
    return urlOrPath;
  }
  return 'install_model_default'.tr();
}

/// User-facing copy when a network download was interrupted but can be resumed.
InstallStatusCopy interruptedDownloadStatusCopy(LocalGemmaModelUi ui) {
  final String name = _modelDisplayName(ui);
  final int p = (ui.pendingProgress ?? ui.progress).clamp(0, 100);
  final String subtitle = 'install_interrupted_resume_sub'.tr();
  if (p > 0) {
    return InstallStatusCopy(
      title: 'install_interrupted_at'.tr(
        namedArgs: <String, String>{
          'name': name,
          'percent': '$p',
        },
      ),
      subtitle: subtitle,
    );
  }
  return InstallStatusCopy(
    title: 'install_interrupted'.tr(namedArgs: <String, String>{'name': name}),
    subtitle: subtitle,
  );
}

/// User-facing lines from [ModelInstallActivityKind] + progress (plugin only reports 0–100).
InstallStatusCopy modelInstallStatusCopy(LocalGemmaModelUi ui) {
  if (ui.phase != LocalGemmaPhase.installing) {
    return const InstallStatusCopy(title: '');
  }
  final ModelInstallActivityKind k = ui.activity;
  final int p = ui.progress.clamp(0, 100);

  switch (k) {
    case ModelInstallActivityKind.downloadNetwork:
      final String name = _modelDisplayName(ui);
      final PredefinedInferenceModel? model = ui.pendingPresetId != null
          ? presetInferenceModelById(ui.pendingPresetId!)
          : null;
      final String? sizeHint =
          model?.sizeMb != null ? 'Approx. size: ~${model!.sizeMb} MB.' : null;
      if (kIsWeb && p < 100) {
        return InstallStatusCopy(
          title: p == 0
              ? 'install_downloading'
                  .tr(namedArgs: <String, String>{'name': name})
              : 'install_downloading_percent'.tr(
                  namedArgs: <String, String>{
                    'name': name,
                    'percent': '$p',
                  },
                ),
          subtitle: sizeHint != null
              ? 'install_downloading_web_sub_size'.tr(
                  namedArgs: <String, String>{'sizeHint': sizeHint},
                )
              : 'install_downloading_web_sub'.tr(),
        );
      }
      if (p == 0) {
        return InstallStatusCopy(
          title: 'install_preparing_download'.tr(
            namedArgs: <String, String>{'name': name},
          ),
          subtitle: 'install_preparing_download_sub'.tr(),
        );
      }
      if (p < 100) {
        return InstallStatusCopy(
          title: 'install_downloading'
              .tr(namedArgs: <String, String>{'name': name}),
          subtitle: model?.sizeMb != null
              ? 'install_downloading_sub_size'.tr(
                  namedArgs: <String, String>{'size': '${model!.sizeMb}'},
                )
              : 'install_downloading_sub_keep_open'.tr(),
        );
      }
      return InstallStatusCopy(
        title:
            'install_finishing'.tr(namedArgs: <String, String>{'name': name}),
        subtitle: 'install_finishing_sub'.tr(),
      );
    case ModelInstallActivityKind.importLocalFile:
      final String name = _modelDisplayName(ui);
      if (p == 0) {
        return InstallStatusCopy(
          title:
              'install_reading'.tr(namedArgs: <String, String>{'name': name}),
          subtitle: 'install_reading_sub'.tr(),
        );
      }
      if (p < 100) {
        return InstallStatusCopy(
          title: 'install_installing'
              .tr(namedArgs: <String, String>{'name': name}),
          subtitle: 'install_installing_sub'.tr(),
        );
      }
      return InstallStatusCopy(
        title:
            'install_finishing'.tr(namedArgs: <String, String>{'name': name}),
        subtitle: 'install_finishing_validate_sub'.tr(),
      );
    case ModelInstallActivityKind.restoreSaved:
      final String name = _modelDisplayName(ui);
      if (p == 0) {
        return InstallStatusCopy(
          title:
              'install_restoring'.tr(namedArgs: <String, String>{'name': name}),
          subtitle: 'install_restoring_sub'.tr(),
        );
      }
      if (p < 100) {
        return InstallStatusCopy(
          title:
              'install_loading'.tr(namedArgs: <String, String>{'name': name}),
          subtitle: 'install_loading_restore_sub'.tr(),
        );
      }
      return InstallStatusCopy(
        title: 'install_finishing_restore'.tr(
          namedArgs: <String, String>{'name': name},
        ),
        subtitle: 'install_finishing_activate_sub'.tr(),
      );
    case ModelInstallActivityKind.activateExisting:
      final String name = _modelDisplayName(ui);
      if (p == 0) {
        return InstallStatusCopy(
          title:
              'install_switching'.tr(namedArgs: <String, String>{'name': name}),
          subtitle: 'install_switching_sub'.tr(),
        );
      }
      if (p < 100) {
        return InstallStatusCopy(
          title:
              'install_loading'.tr(namedArgs: <String, String>{'name': name}),
          subtitle: 'install_loading_inference_sub'.tr(),
        );
      }
      return InstallStatusCopy(
        title: 'install_finishing_activation'.tr(
          namedArgs: <String, String>{'name': name},
        ),
        subtitle: 'install_finishing_selected_sub'.tr(),
      );
    case ModelInstallActivityKind.unknown:
      final String name = _modelDisplayName(ui);
      final String defaultName = 'install_model_default'.tr();
      if (p == 0) {
        return InstallStatusCopy(
          title: 'install_preparing'.tr(),
          subtitle: 'install_preparing_sub'.tr(),
        );
      }
      if (p < 100) {
        return InstallStatusCopy(
          title: name != defaultName
              ? 'install_working_named'
                  .tr(namedArgs: <String, String>{'name': name})
              : 'install_working'.tr(),
          subtitle: 'install_working_sub'.tr(),
        );
      }
      return InstallStatusCopy(
        title: 'install_finishing_generic'.tr(),
        subtitle: 'install_almost_done'.tr(),
      );
  }
}

String modelInstallStatusTitle(LocalGemmaModelUi ui) =>
    modelInstallStatusCopy(ui).title;

String? modelInstallStatusSubtitle(LocalGemmaModelUi ui) =>
    modelInstallStatusCopy(ui).subtitle;
