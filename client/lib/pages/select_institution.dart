import 'package:flutter/material.dart';

import '../util/api.dart';

// Step 1 of logging in: pick your institution.
// The list comes from the server (GET /institutions), so a new institution
// uploaded in the admin dashboard shows up here without changing the app.
class SelectInstitutionStep extends StatefulWidget {
  const SelectInstitutionStep({
    super.key,
    required this.selectedInstitution,
    required this.onChanged,
    this.errorText,
  });

  final String? selectedInstitution;
  final ValueChanged<String?> onChanged;
  final String? errorText;

  @override
  State<SelectInstitutionStep> createState() => _SelectInstitutionStepState();
}

class _SelectInstitutionStepState extends State<SelectInstitutionStep> with AutomaticKeepAliveClientMixin {
  List<DropdownMenuEntry<String>>? institutions; // null until the server replies
  String? loadError; // set if the server couldn't be reached

  // The login screen's PageView throws away a page when you swipe off it. Staying
  // alive means going Back from the password step doesn't download the list again.
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    loadInstitutions();
  }

  Future<void> loadInstitutions() async {
    setState(() => loadError = null);
    try {
      final list = await Api.getInstitutions();
      if (!mounted) return;
      setState(() {
        institutions = [
          for (final i in list) DropdownMenuEntry(value: '${i['id']}', label: i['name'] as String),
        ];
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => loadError = e.message);
    } catch (e) {
      if (mounted) setState(() => loadError = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // needed by AutomaticKeepAliveClientMixin

    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(12),
          child: Text(
            "Let's get you started by logging into your institution.",
            textAlign: TextAlign.center,
          ),
        ),
        _picker(),
      ],
    );
  }

  Widget _picker() {
    if (loadError != null) {
      return Column(
        children: [
          Text(loadError!, textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis),
          TextButton(onPressed: loadInstitutions, child: const Text('Try again')),
        ],
      );
    }

    final entries = institutions;
    if (entries == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: CircularProgressIndicator(),
      );
    }
    if (entries.isEmpty) {
      return const Text('No institutions have been set up yet.');
    }

    return DropdownMenu<String>(
      width: 300,
      hintText: 'Select an institution',
      enableSearch: true,
      enableFilter: true,
      requestFocusOnTap: true,
      initialSelection: widget.selectedInstitution,
      errorText: widget.errorText,
      dropdownMenuEntries: entries,
      onSelected: widget.onChanged,
    );
  }
}