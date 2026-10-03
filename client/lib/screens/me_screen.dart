import 'package:flutter/material.dart';

import '../models/booking.dart';
import '../theme/colors.dart';
import '../util/api.dart';
import '../util/session.dart';
import '../widgets/load_error.dart';

// The "Me" tab: who you're logged in as, and a Log out button.
class MeScreen extends StatefulWidget {
  const MeScreen({super.key});

  @override
  State<MeScreen> createState() => _MeScreenState();
}

class _MeScreenState extends State<MeScreen> {
  Map<String, dynamic>? me; // filled in once the server replies
  Object? error; // set if the server couldn't be reached
  bool loading = true;
  bool loggingOut = false;

  @override
  void initState() {
    super.initState();
    fetchMe();
  }

  Future<void> fetchMe() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await Api.getMe();
      if (mounted) setState(() => me = result);
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> logOut() async {
    setState(() => loggingOut = true);
    await Api.logout(); // tells the server this login token is finished
    BookingStore.instance.clear(); // don't leave this user's bookings for the next login
    if (!mounted) return;
    await goToLogin(context);
  }

  @override
  Widget build(BuildContext context) {
    final institution = me?['institution'] as Map<String, dynamic>?;
    final institutionName = institution?['name'] as String? ?? 'Unknown institution';

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading) const CircularProgressIndicator(),
            if (error != null) LoadError(error: error!, onRetry: fetchMe),
            if (me != null) ...[
              const CircleAvatar(
                radius: 40,
                backgroundColor: AppColors.lilac,
                child: Icon(Icons.person, size: 40, color: AppColors.lilacDark),
              ),
              const SizedBox(height: 16),
              Text('${me!['student_id']}', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(institutionName, style: const TextStyle(color: AppColors.grey)),
            ],
            const SizedBox(height: 32),
            // Always available, even if the details above failed to load.
            FilledButton.icon(
              onPressed: loggingOut ? null : logOut,
              icon: const Icon(Icons.logout),
              label: Text(loggingOut ? 'Logging out...' : 'Log out'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.lilacDark,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}