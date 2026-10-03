import 'package:client/screens/home.dart';
import 'package:client/screens/login.dart';
import 'package:client/theme/theme.dart';
import 'package:client/util/auth_storage.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final hasToken = await AuthStorage.readToken() != null;
  runApp(App(startLoggedIn: hasToken));
}

class App extends StatelessWidget {
  final bool startLoggedIn;

  const App({super.key, required this.startLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Buzzbook',
      theme: AppTheme.theme,
      debugShowCheckedModeBanner: false,
      home: startLoggedIn ? const HomeScreen() : const LoginScreen(),
      routes: {
        "/home": (_) => const HomeScreen(),
      },
    );
  }
}

