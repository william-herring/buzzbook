import 'package:flutter/material.dart';

class SelectInstitutionStep extends StatefulWidget {
  const SelectInstitutionStep({super.key});

  @override
  State<SelectInstitutionStep> createState() => _SelectInstitutionStepState();
}

class _SelectInstitutionStepState extends State<SelectInstitutionStep> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsetsGeometry.all(12.0),
          child: Text("Let's get you started by logging into your institution.", textAlign: TextAlign.center),
        ),
        DropdownMenu<String>(
          width: 300,
          hintText: "Select an institution",
          enableSearch: true,
          enableFilter: true,
          requestFocusOnTap: true,
          dropdownMenuEntries: const [
            DropdownMenuEntry(value: 'RMIT', label: 'RMIT University'),
            DropdownMenuEntry(value: 'UniMelb', label: 'The University of Melbourne'),
            DropdownMenuEntry(value: 'Monash', label: 'Monash University'),
          ],
          onSelected: (String? value) {},
        ),
      ],
    );
  }
}
