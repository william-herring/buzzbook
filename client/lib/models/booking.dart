import 'package:flutter/foundation.dart';

import 'room.dart';

// One booking the user has made.
class Booking {
  final Room room;
  final String day; // e.g. "Today", "Mon"
  final String time; // e.g. "1:00–2:30"
  final List<String> invited; // names or emails of friends

  Booking({required this.room, required this.day, required this.time, List<String>? invited})
      : invited = invited ?? [];
}

// Holds the user's bookings while the app is open.
// It's a ChangeNotifier, which means screens can "listen" to it and redraw
// whenever a booking is added or an invite changes.
//
// Nothing is saved yet: closing the app forgets everything. Later this will
// fetch and send bookings to William's server instead.
class BookingStore extends ChangeNotifier {
  // One shared store for the whole app.
  static final instance = BookingStore();

  final List<Booking> bookings = [];
  bool _addedExamples = false;

  void add(Booking booking) {
    bookings.add(booking);
    notifyListeners();
  }

  void addInvite(Booking booking, String name) {
    booking.invited.add(name);
    notifyListeners();
  }

  void removeInvite(Booking booking, String name) {
    booking.invited.remove(name);
    notifyListeners();
  }

  // Two example bookings so the "Current bookings" carousel has something to show.
  void addExampleBookings(List<Room> rooms) {
    if (_addedExamples) return;
    _addedExamples = true;
    final first = rooms.firstWhere((r) => r.name == '10.05.67');
    final second = rooms.firstWhere((r) => r.name == '94.03.004');
    bookings.add(Booking(room: first, day: 'Today', time: '2:00–4:00', invited: ['Priya R.', 'Tom N.']));
    bookings.add(Booking(room: second, day: 'Tomorrow', time: '10:00–11:00'));
    notifyListeners();
  }
}
