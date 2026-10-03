import 'dart:convert';

import 'package:client/constants.dart';
import 'package:client/pages/user_credentials.dart';
import 'package:client/pages/select_institution.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../util/auth_storage.dart';
import 'home.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const _stepCount = 2;
  static const _animationDuration = Duration(milliseconds: 300);

  final _pageController = PageController();
  final _credentialsFormKey = GlobalKey<FormState>();
  final _studentIdController = TextEditingController();
  final _passwordController = TextEditingController();

  int _currentStep = 0;
  String? _institution;
  String? _institutionError;

  bool get _isFirstStep => _currentStep == 0;
  bool get _isLastStep => _currentStep == _stepCount - 1;

  @override
  void dispose() {
    _pageController.dispose();
    _studentIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _goToStep(int step) {
    setState(() => _currentStep = step);
    _pageController.animateToPage(
      step,
      duration: _animationDuration,
      curve: Curves.easeInOut,
    );
  }

  void _onInstitutionChanged(String? value) {
    setState(() {
      _institution = value;
      _institutionError = null;
    });
  }

  bool _validateInstitution() {
    final isValid = _institution != null;
    setState(() {
      _institutionError = isValid ? null : 'Please select an institution';
    });
    return isValid;
  }

  void _onNext() {
    if (_isLastStep) {
      _submit();
      return;
    }
    if (_validateInstitution()) _goToStep(_currentStep + 1);
  }

  void _onBack() => _goToStep(_currentStep - 1);

  void _submit() async {
    if (!_credentialsFormKey.currentState!.validate()) return;

    final institution = _institution!;
    final studentId = _studentIdController.text.trim();
    final password = _passwordController.text;

    try {
      final response = await http
          .post(
        Uri.parse("$apiBaseUrl/authenticate"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'institution_id': institution,
          'student_id': studentId,
          'password': password,
        }),
      )
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final token = jsonDecode(response.body)['access_token'] as String;
        await AuthStorage.saveToken(token);
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed(
          "/home"
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid credentials')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't reach the server")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Image.asset('assets/images/logo.png', height: 40),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Welcome to Buzzbook.',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 220,
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    SelectInstitutionStep(
                      selectedInstitution: _institution,
                      onChanged: _onInstitutionChanged,
                      errorText: _institutionError,
                    ),
                    CredentialsStep(
                      formKey: _credentialsFormKey,
                      studentIdController: _studentIdController,
                      passwordController: _passwordController,
                      onSubmitted: _submit,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_isFirstStep)
                    const SizedBox.shrink()
                  else
                    TextButton.icon(
                      onPressed: _onBack,
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('BACK'),
                    ),
                  TextButton.icon(
                    onPressed: _onNext,
                    icon: Icon(_isLastStep ? Icons.login : Icons.arrow_forward),
                    iconAlignment: IconAlignment.end,
                    label: Text(_isLastStep ? 'LOG IN' : 'NEXT'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}