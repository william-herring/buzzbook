import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get theme {
    return ThemeData (
      fontFamily: 'Inter',
      textTheme: _textTheme,
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(fontFamily: 'Inter'),
        labelStyle: TextStyle(fontFamily: 'Inter'),
      ),
    );
  }

  static const TextTheme _textTheme = TextTheme(
    displayMedium: TextStyle(
      fontFamily: 'Inter',
      fontWeight: FontWeight.w400
    ),
    bodyMedium: TextStyle(
        fontFamily: 'Inter',
        fontWeight: FontWeight.w400
    ),
    titleLarge: TextStyle(
      fontFamily: 'Inter',
      fontWeight: FontWeight.w600
    )
  );
}