import 'dart:convert';

import 'package:flutter/services.dart';

// Is the room free right now? (Fake for now: see `status` below.)
enum RoomStatus { free, soon, booked }

// One study room, built from one entry in rmit_city_study_rooms.json.
class Room {
  final String name; // e.g. "80.05.003"
  final String buildingId; // e.g. "80"
  final int floor;
  final String roomType;
  final int capacity;
  final bool hasTv;
  final bool hasWhiteboard;
  final bool hasProjector;

  Room({
    required this.name,
    required this.buildingId,
    required this.floor,
    required this.roomType,
    required this.capacity,
    required this.hasTv,
    required this.hasWhiteboard,
    required this.hasProjector,
  });

  // Turns one JSON object into a Room.
  factory Room.fromJson(Map<String, dynamic> json) {
    final features = json['features'] as Map<String, dynamic>;
    return Room(
      name: json['name'],
      buildingId: json['building'],
      floor: int.parse(json['floor']), // the JSON stores floor as text, e.g. "5"
      roomType: json['room_type'],
      capacity: json['capacity'],
      hasTv: features['TV'] > 0,
      hasWhiteboard: features['Whiteboard'] > 0,
      hasProjector: features['Projector'] > 0,
    );
  }

  // PRETEND availability until the server can tell us real bookings.
  // It's based on the room name, so a room always shows the same status.
  RoomStatus get status {
    final number = name.codeUnits.fold(0, (sum, c) => sum + c);
    switch (number % 5) {
      case 3:
        return RoomStatus.soon;
      case 4:
        return RoomStatus.booked;
      default:
        return RoomStatus.free;
    }
  }

  // "80.05.003" → "Building 80, Level 5, Room 3"
  String get readableName => 'Building $buildingId, $levelAndRoom';

  // "80.05.003" → "Level 5, Room 3" (for lists already grouped by building)
  String get levelAndRoom {
    final parts = name.split('.');
    // Drop leading zeros: "003" → "3", "003A" → "3A", "101" stays "101"
    final roomNumber = parts.last.replaceFirst(RegExp(r'^0+(?=.)'), '');
    return 'Level $floor, Room $roomNumber';
  }

  String get statusLabel {
    switch (status) {
      case RoomStatus.free:
        return 'Free';
      case RoomStatus.soon:
        return 'Free soon';
      case RoomStatus.booked:
        return 'Booked';
    }
  }

  // The JSON uses 0 when it doesn't know how many seats a room has.
  String get seatsLabel => capacity == 0 ? 'Seats unknown' : '$capacity seats';

  // e.g. "5 seats · TV · Whiteboard"
  String get featureSummary {
    final parts = [seatsLabel];
    if (hasTv) parts.add('TV');
    if (hasWhiteboard) parts.add('Whiteboard');
    if (hasProjector) parts.add('Projector');
    return parts.join(' · ');
  }
}

// Reads every room from the JSON file bundled with the app.
// Later this becomes an HTTP request to William's server.
// The result is remembered, so every screen shares the same list.
Future<List<Room>>? _cachedRooms;

Future<List<Room>> loadRooms() {
  _cachedRooms ??= _readRoomsFile();
  return _cachedRooms!;
}

Future<List<Room>> _readRoomsFile() async {
  final text = await rootBundle.loadString('assets/data/rmit_city_study_rooms.json');
  final List<dynamic> list = jsonDecode(text);
  return list.map((item) => Room.fromJson(item)).toList();
}
