import 'package:flutter/material.dart';

import '../screens/login.dart';
import 'auth_storage.dart';

Future<void> goToLogin(BuildContext context) async {
  await AuthStorage.clearToken();
  if (!context.mounted) return;
  Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
  );
}