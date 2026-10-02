import 'package:client/pages/select_institution.dart';
import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final PageController _controller = PageController();
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Image.asset(
          'assets/images/logo.png',
          height: 40,
        ),
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsetsGeometry.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text("Welcome to Buzzbook.", style: Theme.of(context).textTheme.titleLarge),
              Container(
                  height: 150,
                  padding: EdgeInsetsGeometry.all(8.0),
                  child: PageView(
                    controller: _controller,
                    physics: const NeverScrollableScrollPhysics(), // Disable manual swipe if validation required
                    children: [
                      SelectInstitutionStep(),
                      Container(height: 40, width: 50, color: Color.fromRGBO(0, 0, 0, 1)),
                    ],
                  )
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(onPressed: () {}, label: Text("NEXT"), icon: Icon(Icons.arrow_forward), iconAlignment: IconAlignment.end)
                ],
              )
            ],
          ),
        )
      ),
    );
  }
}
