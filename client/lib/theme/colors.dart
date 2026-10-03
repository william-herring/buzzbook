import 'package:flutter/material.dart';

// Every colour here is one of Flutter's built-in Material colours
// (the comment says which), so they're easy to swap for the real theme later.
class AppColors {
  static const ink = Color(0xDD000000); // Colors.black87
  static const grey = Color(0xFF757575); // Colors.grey.shade600
  static const chip = Color(0xFFEEEEEE); // Colors.grey.shade200
  static const divider = Color(0xFFE0E0E0); // Colors.grey.shade300
  static const mapBackground = Color(0xFFEEEEEE); // Colors.grey.shade200

  // Accent colours
  static const lilac = Color(0xFFD1C4E9); // Colors.deepPurple.shade100
  static const lilacLight = Color(0xFFEDE7F6); // Colors.deepPurple.shade50
  static const lilacDark = Color(0xFF512DA8); // Colors.deepPurple.shade700
  static const yellow = Color(0xFFFFF59D); // Colors.yellow.shade200
  static const yellowLight = Color(0xFFFFF9C4); // Colors.yellow.shade100

  // Room status
  static const free = Color(0xFF388E3C); // Colors.green.shade700
  static const freeLight = Color(0xFFE8F5E9); // Colors.green.shade50
  static const freeDark = Color(0xFF2E7D32); // Colors.green.shade800
  static const soon = Color(0xFFFFA000); // Colors.amber.shade700
  static const booked = Color(0xFFBDBDBD); // Colors.grey.shade400
}
