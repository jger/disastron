import 'package:disastron/features/inference/domain/model_install_activity_kind.dart';
import 'package:disastron/features/inference/domain/predefined_models.dart';
import 'package:disastron/features/inference/presentation/local_gemma_model_provider.dart';
import 'package:easy_localization/easy_localization.dart';

class InstallStatusCopy {
  const InstallStatusCopy({required this.title, this.subtitle});

  final String title;
  final String? subtitle;
}

String _modelDisplayName(LocalGemmaModelUi ui) {
  if (ui.pendingPresetId != null) {
    final PredefinedInferenceModel? model = presetInferenceModelById(
      ui.pendingPresetId!,
    );
    if (model != null) {
      return model.title;
    }
  }
  if (ui.pendingDownloadUrl != null) {
    final String urlOrPath = ui.pendingDownloadUrl!;
    final Uri uri = urlOrPath.contains('://')
        ? Uri.parse(urlOrPath)
        : Uri.file(urlOrPath);
    if (uri.pathSegments.isNotEmpty) {
      return uri.pathSegments.last;
    }
    return urlOrPath;
  }
  return 'model_display_fallback'.tr();
}

bool _hasConcreteModelName(LocalGemmaModelUi ui) {
  return ui.pendingPresetId != null || ui.pendingDownloadUrl != null;
}

/// User-facing copy when a network download was interrupted but can be resumed.
InstallStatusCopy interruptedDownloadStatusCopy(LocalGemmaModelUi ui) {
  final String name = _modelDisplayName(ui);
  final int p = (ui.pendingProgress ?? ui.progress).clamp(0, 100);
  final String sub = 'install_interrupted_sub'.tr();
  if (p > 0) {
    return InstallStatusCopy(
      title: 'install_interrupted_at'.tr(args: <String>[name, '$p']),
      subtitle: sub,
    );
  }
  return InstallStatusCopy(
    title: 'install_interrupted'.tr(args: <String>[name]),
    subtitle: sub,
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
      if (p == 0) {
        return InstallStatusCopy(
          title: 'install_prep_download'.tr(args: <String>[name]),
          subtitle: 'install_prep_download_sub'.tr(),
        );
      }
      if (p < 100) {
        return InstallStatusCopy(
          title: 'install_downloading'.tr(args: <String>[name]),
          subtitle: model?.sizeMb != null
              ? 'install_downloading_size_sub'.tr(
                  args: <String>['${model!.sizeMb}'],
                )
              : 'install_downloading_sub'.tr(),
        );
      }
      return InstallStatusCopy(
        title: 'install_finishing'.tr(args: <String>[name]),
        subtitle: 'install_finishing_sub'.tr(),
      );
    case ModelInstallActivityKind.importLocalFile:
      final String name = _modelDisplayName(ui);
      if (p == 0) {
        return InstallStatusCopy(
          title: 'install_reading'.tr(args: <String>[name]),
          subtitle: 'install_reading_sub'.tr(),
        );
      }
      if (p < 100) {
        return InstallStatusCopy(
          title: 'install_importing'.tr(args: <String>[name]),
          subtitle: 'install_importing_sub'.tr(),
        );
      }
      return InstallStatusCopy(
        title: 'install_finishing'.tr(args: <String>[name]),
        subtitle: 'install_finishing_sub'.tr(),
      );
    case ModelInstallActivityKind.restoreSaved:
      final String name = _modelDisplayName(ui);
      if (p == 0) {
        return InstallStatusCopy(
          title: 'install_restoring'.tr(args: <String>[name]),
          subtitle: 'install_restoring_sub'.tr(),
        );
      }
      if (p < 100) {
        return InstallStatusCopy(
          title: 'install_loading_saved'.tr(args: <String>[name]),
          subtitle: 'install_loading_saved_sub'.tr(),
        );
      }
      return InstallStatusCopy(
        title: 'install_finishing_restore'.tr(args: <String>[name]),
        subtitle: 'install_finishing_restore_sub'.tr(),
      );
    case ModelInstallActivityKind.activateExisting:
      final String name = _modelDisplayName(ui);
      if (p == 0) {
        return InstallStatusCopy(
          title: 'install_switching'.tr(args: <String>[name]),
          subtitle: 'install_switching_sub'.tr(),
        );
      }
      if (p < 100) {
        return InstallStatusCopy(
          title: 'install_loading'.tr(args: <String>[name]),
          subtitle: 'install_loading_sub'.tr(),
        );
      }
      return InstallStatusCopy(
        title: 'install_finishing_activate'.tr(args: <String>[name]),
        subtitle: 'install_finishing_activate_sub'.tr(),
      );
    case ModelInstallActivityKind.unknown:
      final String name = _modelDisplayName(ui);
      if (p == 0) {
        return InstallStatusCopy(
          title: 'install_preparing'.tr(),
          subtitle: 'install_preparing_sub'.tr(),
        );
      }
      if (p < 100) {
        return InstallStatusCopy(
          title: _hasConcreteModelName(ui)
              ? 'install_working_on'.tr(args: <String>[name])
              : 'install_working'.tr(),
          subtitle: 'install_working_sub'.tr(),
        );
      }
      return InstallStatusCopy(
        title: 'install_almost'.tr(),
        subtitle: 'install_almost_sub'.tr(),
      );
  }
}
