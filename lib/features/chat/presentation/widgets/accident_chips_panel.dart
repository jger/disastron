import 'package:disastron/shared/widgets/genui_card.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class AccidentChipOption {
  const AccidentChipOption({
    required this.label,
    required this.prompt,
  });

  final String label;
  final String prompt;
}

List<AccidentChipOption> localizedAccidentChipOptions() {
  return <AccidentChipOption>[
    AccidentChipOption(
      label: 'chip_vehicle_crash'.tr(),
      prompt: 'chip_vehicle_crash_prompt'.tr(),
    ),
    AccidentChipOption(
      label: 'chip_fire_burn'.tr(),
      prompt: 'chip_fire_burn_prompt'.tr(),
    ),
    AccidentChipOption(
      label: 'chip_cut_bleeding'.tr(),
      prompt: 'chip_cut_bleeding_prompt'.tr(),
    ),
    AccidentChipOption(
      label: 'chip_fall_impact'.tr(),
      prompt: 'chip_fall_impact_prompt'.tr(),
    ),
    AccidentChipOption(
      label: 'chip_poisoning'.tr(),
      prompt: 'chip_poisoning_prompt'.tr(),
    ),
    AccidentChipOption(
      label: 'chip_natural_disaster'.tr(),
      prompt: 'chip_natural_disaster_prompt'.tr(),
    ),
  ];
}

class AccidentChipsPanel extends StatelessWidget {
  const AccidentChipsPanel({required this.onSelect, super.key});

  final ValueChanged<AccidentChipOption> onSelect;

  @override
  Widget build(BuildContext context) {
    final List<AccidentChipOption> options = localizedAccidentChipOptions();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GenUiCard(
        title: 'chat_emergency_question'.tr(),
        subtitle: 'chat_emergency_hint'.tr(),
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
