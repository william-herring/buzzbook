import 'package:flutter/material.dart';

import '../screens/login.dart';
import '../theme/colors.dart';
import '../util/api.dart';
import '../util/auth_storage.dart';

// Shown instead of a screen's content when loading from the server failed.
// Offers "Try again", or "Log in again" when the login has expired.
class LoadError extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const LoadError({super.key, required this.error, required this.onRetry});

  bool get needsLogin => error is ApiException && (error as ApiException).needsLogin;

  Future<void> _logInAgain(BuildContext context) async {
    await AuthStorage.clearToken();
    if (!context.mounted) return;
    // Replace everything with the login screen, so "back" can't return here.
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off, size: 40, color: AppColors.grey),
          const SizedBox(height: 8),
          Text('$error', textAlign: TextAlign.center),
          const SizedBox(height: 12),
          needsLogin
              ? FilledButton(onPressed: () => _logInAgain(context), child: const Text('Log in again'))
              : OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}
