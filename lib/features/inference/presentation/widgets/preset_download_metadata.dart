import 'package:disastron/features/inference/domain/predefined_inference_model.dart';
import 'package:flutter/material.dart';

/// Subtitle for preset list tiles: description + download metadata line.
class PresetDownloadMetadataSubtitle extends StatelessWidget {
  const PresetDownloadMetadataSubtitle({
    required this.model,
    super.key,
  });

  final PredefinedInferenceModel model;

  @override
  Widget build(BuildContext context) {
    final TextStyle? metaStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(model.description),
        const SizedBox(height: 6),
        PresetDownloadMetadataChips(model: model),
        const SizedBox(height: 4),
        Text(model.downloadMetadataLine, style: metaStyle),
      ],
    );
  }
}

/// Compact chips for size, access, and multimodal (preset picker).
class PresetDownloadMetadataChips extends StatelessWidget {
  const PresetDownloadMetadataChips({
    required this.model,
    super.key,
  });

  final PredefinedInferenceModel model;

  @override
  Widget build(BuildContext context) {
    final List<Widget> chips = <Widget>[];
    if (model.sizeMb != null) {
      chips.add(_chip(context, '~${model.sizeMb} MB'));
    }
    chips.add(
      _chip(
        context,
        model.access == InferencePresetAccess.public ? 'Public' : 'Gated',
        icon: model.access == InferencePresetAccess.public
            ? Icons.lock_open_outlined
            : Icons.key_outlined,
      ),
    );
    if (model.multimodal) {
      chips.add(_chip(context, 'Photos', icon: Icons.photo_outlined));
    }

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: chips,
    );
  }

  Widget _chip(BuildContext context, String label, {IconData? icon}) {
    return Chip(
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: EdgeInsets.zero,
      labelPadding: const EdgeInsets.symmetric(horizontal: 6),
      avatar: icon != null
          ? Icon(icon, size: 14, color: Theme.of(context).colorScheme.primary)
          : null,
      label: Text(label, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}
