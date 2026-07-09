import 'package:disastron/features/inference/domain/model_install_activity_kind.dart';
import 'package:disastron/features/inference/domain/predefined_models.dart';
import 'package:disastron/features/inference/presentation/local_gemma_model_provider.dart';

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
  return 'Model';
}

/// User-facing copy when a network download was interrupted but can be resumed.
InstallStatusCopy interruptedDownloadStatusCopy(LocalGemmaModelUi ui) {
  final String name = _modelDisplayName(ui);
  final int p = (ui.pendingProgress ?? ui.progress).clamp(0, 100);
  if (p > 0) {
    return InstallStatusCopy(
      title: 'Download of $name interrupted at $p%',
      subtitle:
          'Resume continues from saved progress when possible. On Hugging Face, '
          'resume is best-effort; if it fails, discard and start again.',
    );
  }
  return InstallStatusCopy(
    title: 'Download of $name interrupted',
    subtitle:
        'Resume continues from saved progress when possible. On Hugging Face, '
        'resume is best-effort; if it fails, discard and start again.',
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
          title: 'Preparing download of $name…',
          subtitle:
              'Wi‑Fi check, Hugging Face auth, or connection setup. Progress appears when bytes flow.',
        );
      }
      if (p < 100) {
        return InstallStatusCopy(
          title: 'Downloading $name…',
          subtitle: model?.sizeMb != null
              ? 'Approx. size: ~${model!.sizeMb} MB. Please keep the app open.'
              : 'Please keep the app open and connected.',
        );
      }
      return InstallStatusCopy(
        title: 'Finishing install of $name…',
        subtitle: 'Validating files and activating the model.',
      );
    case ModelInstallActivityKind.importLocalFile:
      final String name = _modelDisplayName(ui);
      if (p == 0) {
        return InstallStatusCopy(
          title: 'Reading $name…',
          subtitle: 'Large files can take a moment before progress updates.',
        );
      }
      if (p < 100) {
        return InstallStatusCopy(
          title: 'Installing $name…',
          subtitle: 'Importing model file into secure local storage.',
        );
      }
      return InstallStatusCopy(
        title: 'Finishing install of $name…',
        subtitle: 'Validating and activating the model.',
      );
    case ModelInstallActivityKind.restoreSaved:
      final String name = _modelDisplayName(ui);
      if (p == 0) {
        return InstallStatusCopy(
          title: 'Restoring $name…',
          subtitle: 'Loading from device storage.',
        );
      }
      if (p < 100) {
        return InstallStatusCopy(
          title: 'Loading $name…',
          subtitle: 'Restoring previously installed model from storage.',
        );
      }
      return InstallStatusCopy(
        title: 'Finishing restore of $name…',
        subtitle: 'Activating the model.',
      );
    case ModelInstallActivityKind.activateExisting:
      final String name = _modelDisplayName(ui);
      if (p == 0) {
        return InstallStatusCopy(
          title: 'Switching to $name…',
          subtitle: 'Preparing the selected model.',
        );
      }
      if (p < 100) {
        return InstallStatusCopy(
          title: 'Loading $name…',
          subtitle: 'Preparing model for inference.',
        );
      }
      return InstallStatusCopy(
        title: 'Finishing activation of $name…',
        subtitle: 'Activating the selected model.',
      );
    case ModelInstallActivityKind.unknown:
      final String name = _modelDisplayName(ui);
      if (p == 0) {
        return const InstallStatusCopy(
          title: 'Preparing…',
          subtitle: 'Setup or transfer will show progress when it starts.',
        );
      }
      if (p < 100) {
        return InstallStatusCopy(
          title: name != 'Model' ? 'Working on $name…' : 'Working…',
          subtitle: 'Setup or transfer in progress.',
        );
      }
      return const InstallStatusCopy(
        title: 'Finishing…',
        subtitle: 'Almost done.',
      );
  }
}

String modelInstallStatusTitle(LocalGemmaModelUi ui) =>
    modelInstallStatusCopy(ui).title;

String? modelInstallStatusSubtitle(LocalGemmaModelUi ui) =>
    modelInstallStatusCopy(ui).subtitle;
