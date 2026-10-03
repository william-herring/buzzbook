// import 'package:client/screens/login.dart';
import 'package:client/screens/app_shell.dart';
import 'package:client/theme/theme.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Buzzbook',
      theme: AppTheme.theme,
      debugShowCheckedModeBanner: false,
      // TEMPORARY: skip login while the server isn't connected.
      // Switch back to LoginScreen (and un-comment its import) when it is.
      // home: const LoginScreen(),
      home: const AppShell(),
    );
  }
}
