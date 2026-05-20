import 'package:disastron/features/inference/domain/model_install_activity_kind.dart';
import 'package:disastron/features/inference/presentation/local_gemma_model_provider.dart';

class InstallStatusCopy {
  const InstallStatusCopy({
    required this.title,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
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
      if (p == 0) {
        return const InstallStatusCopy(
          title: 'Preparing download…',
          subtitle:
              'Wi‑Fi check, Hugging Face auth, or connection setup. Progress appears when bytes flow.',
        );
      }
      if (p < 100) {
        return InstallStatusCopy(title: 'Downloading… $p%');
      }
      return const InstallStatusCopy(
        title: 'Finishing install…',
        subtitle: 'Validating files and activating the model.',
      );
    case ModelInstallActivityKind.importLocalFile:
      if (p == 0) {
        return const InstallStatusCopy(
          title: 'Reading model file…',
          subtitle: 'Large files can take a moment before progress updates.',
        );
      }
      if (p < 100) {
        return InstallStatusCopy(title: 'Installing model… $p%');
      }
      return const InstallStatusCopy(
        title: 'Finishing install…',
        subtitle: 'Validating and activating the model.',
      );
    case ModelInstallActivityKind.restoreSaved:
      if (p == 0) {
        return const InstallStatusCopy(
          title: 'Restoring saved model…',
          subtitle: 'Loading from device storage.',
        );
      }
      if (p < 100) {
        return InstallStatusCopy(title: 'Loading model… $p%');
      }
      return const InstallStatusCopy(
        title: 'Finishing restore…',
        subtitle: 'Activating the model.',
      );
    case ModelInstallActivityKind.activateExisting:
      if (p == 0) {
        return const InstallStatusCopy(
          title: 'Switching model…',
          subtitle: 'Preparing the selected model.',
        );
      }
      if (p < 100) {
        return InstallStatusCopy(title: 'Loading model… $p%');
      }
      return const InstallStatusCopy(
        title: 'Finishing…',
        subtitle: 'Activating the selected model.',
      );
    case ModelInstallActivityKind.unknown:
      if (p == 0) {
        return const InstallStatusCopy(
          title: 'Preparing…',
          subtitle: 'Setup or transfer will show progress when it starts.',
        );
      }
      if (p < 100) {
        return InstallStatusCopy(title: 'Working… $p%');
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
