import 'package:disastron/shared/widgets/genui_card.dart';
import 'package:flutter/material.dart';

class AccidentChipOption {
  const AccidentChipOption({
    required this.label,
    required this.prompt,
  });

  final String label;
  final String prompt;
}

const List<AccidentChipOption> kAccidentChipOptions = <AccidentChipOption>[
  AccidentChipOption(
    label: 'Vehicle crash',
    prompt:
        'Vehicle accident. I need immediate steps: injuries, traffic, fire risk, and who to call.',
  ),
  AccidentChipOption(
    label: 'Fire / burn',
    prompt:
        'Fire or burn emergency. What to do first for safety and first aid.',
  ),
  AccidentChipOption(
    label: 'Cut / bleeding',
    prompt:
        'Serious cut or bleeding. How to slow bleeding and when to seek emergency care.',
  ),
  AccidentChipOption(
    label: 'Fall / impact',
    prompt:
        'Fall or strong impact. Check for head/spine injury and what to monitor.',
  ),
  AccidentChipOption(
    label: 'Poisoning',
    prompt:
        'Possible poisoning or harmful substance. Practical steps while offline.',
  ),
  AccidentChipOption(
    label: 'Natural disaster',
    prompt:
        'Natural disaster situation (storm, flood, earthquake). Shelter and evacuation priorities.',
  ),
];

class AccidentChipsPanel extends StatelessWidget {
  const AccidentChipsPanel({required this.onSelect, super.key});

  final ValueChanged<AccidentChipOption> onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GenUiCard(
        title: 'What kind of emergency are you dealing with?',
        subtitle: 'Tap one — you can type details next.',
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: kAccidentChipOptions
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
