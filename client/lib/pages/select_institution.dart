import 'package:flutter/material.dart';

class SelectInstitutionStep extends StatelessWidget {
  const SelectInstitutionStep({
    super.key,
    required this.selectedInstitution,
    required this.onChanged,
    this.errorText,
  });

  final String? selectedInstitution;
  final ValueChanged<String?> onChanged;
  final String? errorText;

  static const _institutions = <DropdownMenuEntry<String>>[
    DropdownMenuEntry(value: 'RMIT', label: 'RMIT University'),
    DropdownMenuEntry(value: 'UniMelb', label: 'The University of Melbourne'),
    DropdownMenuEntry(value: 'Monash', label: 'Monash University'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(12),
          child: Text(
            "Let's get you started by logging into your institution.",
            textAlign: TextAlign.center,
          ),
        ),
        DropdownMenu<String>(
          width: 300,
          hintText: 'Select an institution',
          enableSearch: true,
          enableFilter: true,
          requestFocusOnTap: true,
          initialSelection: selectedInstitution,
          errorText: errorText,
          dropdownMenuEntries: _institutions,
          onSelected: onChanged,
        ),
      ],
    );
  }
}