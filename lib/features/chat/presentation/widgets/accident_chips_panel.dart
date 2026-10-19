import 'package:disastron/shared/widgets/genui_card.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class AccidentChipOption {
  const AccidentChipOption({required this.labelKey, required this.promptKey});

  final String labelKey;
  final String promptKey;

  String get label => labelKey.tr();

  String get prompt => promptKey.tr();
}

List<AccidentChipOption> accidentChipOptions() => const <AccidentChipOption>[
  AccidentChipOption(
    labelKey: 'chat_accident_vehicle_label',
    promptKey: 'chat_accident_vehicle_prompt',
  ),
  AccidentChipOption(
    labelKey: 'chat_accident_fire_label',
    promptKey: 'chat_accident_fire_prompt',
  ),
  AccidentChipOption(
    labelKey: 'chat_accident_bleed_label',
    promptKey: 'chat_accident_bleed_prompt',
  ),
  AccidentChipOption(
    labelKey: 'chat_accident_fall_label',
    promptKey: 'chat_accident_fall_prompt',
  ),
  AccidentChipOption(
    labelKey: 'chat_accident_poison_label',
    promptKey: 'chat_accident_poison_prompt',
  ),
  AccidentChipOption(
    labelKey: 'chat_accident_disaster_label',
    promptKey: 'chat_accident_disaster_prompt',
  ),
];

class AccidentChipsPanel extends StatelessWidget {
  const AccidentChipsPanel({required this.onSelect, super.key});

  final ValueChanged<AccidentChipOption> onSelect;

  @override
  Widget build(BuildContext context) {
    final List<AccidentChipOption> options = accidentChipOptions();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GenUiCard(
        title: 'chat_accident_title'.tr(),
        subtitle: 'chat_accident_subtitle'.tr(),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options
              .map(
                (AccidentChipOption o) => ActionChip(
                  label: Text(o.label),
                  onPressed: () => onSelect(o),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}
