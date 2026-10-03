import 'package:flutter/foundation.dart';

import '../util/api.dart';
import 'room.dart';

// One booking the user has made.
class Booking {
  final int id; // the server's booking_id
  final Room room;
  final DateTime start;
  final DateTime end;
  final List<String> invited; // student IDs of friends

  Booking({required this.id, required this.room, required this.start, required this.end, List<String>? invited})
      : invited = invited ?? [];

  String get dayLabel => dayLabelFor(start);
  String get timeLabel => timeRangeLabel(start, end);
}

// Any booking of a room, by anyone, as sent by the server's /room/<id>.
class RoomBooking {
  final int id;
  final DateTime start;
  final DateTime end;
  final List<String> studentIds; // everyone in the booking

  RoomBooking({required this.id, required this.start, required this.end, required this.studentIds});

  factory RoomBooking.fromApi(Map<String, dynamic> json) {
    return RoomBooking(
      id: json['id'],
      start: DateTime.parse(json['start_time']).toLocal(),
      end: DateTime.parse(json['end_time']).toLocal(),
      studentIds: [for (final id in json['student_ids'] ?? []) id as String],
    );
  }

  String get dayLabel => dayLabelFor(start);
  String get timeLabel => timeRangeLabel(start, end);
}

// "Today", "Tomorrow" or a weekday like "Mon"
String dayLabelFor(DateTime time) {
  final local = time.toLocal();
  final today = DateTime.now();
  final day = DateTime(local.year, local.month, local.day);
  final difference = day.difference(DateTime(today.year, today.month, today.day)).inDays;
  if (difference == 0) return 'Today';
  if (difference == 1) return 'Tomorrow';
  const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return names[local.weekday - 1];
}

// e.g. "2:00–3:30"
String timeRangeLabel(DateTime start, DateTime end) => '${_clock(start)}–${_clock(end)}';

String _clock(DateTime time) {
  final local = time.toLocal();
  var hour = local.hour % 12;
  if (hour == 0) hour = 12;
  return '$hour:${local.minute.toString().padLeft(2, '0')}';
}

// Holds the bookings made while the app is open, so "Current bookings" can show them.
// It's a ChangeNotifier, which means screens can "listen" to it and redraw
// whenever a booking is added or an invite changes.
//
// The server saves bookings, but has no endpoint yet to LIST a user's bookings,
// so after restarting the app this starts empty again. Once William adds one
// (e.g. GET /my-bookings), load it here.
class BookingStore extends ChangeNotifier {
  // One shared store for the whole app.
  static final instance = BookingStore();

  final List<Booking> bookings = [];

  void add(Booking booking) {
    bookings.add(booking);
    bookings.sort((a, b) => a.start.compareTo(b.start));
    // The database has changed, so the next loadRooms() should fetch fresh data.
    forgetRooms();
    notifyListeners();
  }

  // Forgets everything. Used when logging out, so the next person to log in
  // on this device doesn't see the previous user's bookings.
  void clear() {
    bookings.clear();
    forgetRooms();
    notifyListeners();
  }

  // Adds a friend to the booking on the server (/add-to-booking), then updates
  // the app's copy. Throws an ApiException with the server's reason if it fails,
  // e.g. "Student S123 not found" or "Room is at capacity (5)".
  // (There's no server endpoint to REMOVE someone from a booking yet.)
  Future<void> addInvite(Booking booking, String studentId) async {
    final everyone = await Api.addToBooking(bookingId: booking.id, studentId: studentId);
    // The server sends back everyone in the booking. Use its spelling of the new ID.
    final added = everyone.firstWhere(
          (id) => id.toLowerCase() == studentId.toLowerCase(),
      orElse: () => studentId,
    );
    if (!booking.invited.contains(added)) booking.invited.add(added);
    notifyListeners();
  }
}