import 'package:flutter/material.dart';

import '../screens/login.dart';
import 'auth_storage.dart';

// Forgets the saved login and shows the login screen, with no way back to the
// screens behind it. (Same thing LoadError's "Log in again" button does.)
Future<void> goToLogin(BuildContext context) async {
  await AuthStorage.clearToken();
  if (!context.mounted) return;
  Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
  );
}