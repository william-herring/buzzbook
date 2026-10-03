import 'package:latlong2/latlong.dart';

import '../util/api.dart';
import 'building.dart';

// Is the room free right now? "busy" covers booked, occupied or closed.
enum RoomStatus { free, busy }

// One study room, as sent by the server's /get-rooms endpoint.
class Room {
  final int id; // the server's id, needed to book it
  final String name; // e.g. "80.05.003"
  final String buildingId; // the building's number, e.g. "80"
  final int floor;
  final String roomType;
  final int capacity;
  final bool hasTv;
  final bool hasWhiteboard;
  final bool hasProjector;
  final RoomStatus status;

  Room({
    required this.id,
    required this.name,
    required this.buildingId,
    required this.floor,
    required this.roomType,
    required this.capacity,
    required this.hasTv,
    required this.hasWhiteboard,
    required this.hasProjector,
    required this.status,
  });

  // Turns one room from the server into a Room.
  // The server identifies buildings by a database id (1, 2, 3...), but the app
  // uses the building number ("80"), so we're given a lookup from one to the other.
  // availableIds is the set of rooms the database says are available right now.
  factory Room.fromApi(Map<String, dynamic> json, Map<int, String> buildingNumbers, Set<int> availableIds) {
    return Room(
      id: json['id'],
      name: json['name'],
      buildingId: _buildingNumber(json, buildingNumbers),
      floor: json['floor'] ?? 0,
      roomType: json['room_type'] ?? '',
      capacity: json['capacity'] ?? 0,
      hasTv: (json['televisions'] ?? 0) > 0,
      hasWhiteboard: (json['whiteboards'] ?? 0) > 0,
      hasProjector: (json['projectors'] ?? 0) > 0,
      status: availableIds.contains(json['id']) ? RoomStatus.free : RoomStatus.busy,
    );
  }

  // Works out the building number ("80") for a room.
  // RMIT room names start with it ("80.05.003"), so that's tried first. Otherwise
  // the number is pulled out of the server's building name, so "80",
  // "Building 80" and "RMIT Building 80" all become "80".
  static String _buildingNumber(Map<String, dynamic> json, Map<int, String> buildingNames) {
    final fromRoomName = (json['name'] as String).split('.').first;
    if (RegExp(r'^\d+$').hasMatch(fromRoomName)) return fromRoomName;

    final buildingName = buildingNames[json['building_id']] ?? '';
    return RegExp(r'\d+').firstMatch(buildingName)?.group(0) ?? buildingName;
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
      case RoomStatus.busy:
        return 'Busy now';
    }
  }

  // The data uses 0 when it doesn't know how many seats a room has.
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

// Fetches every room from the server.
// The result is remembered, so the List and Map tabs share one download.
// Pass refresh: true to fetch again (e.g. after a "Try again" button).
Future<List<Room>>? _cachedRooms;

Future<List<Room>> loadRooms({bool refresh = false}) {
  if (refresh) _cachedRooms = null;
  final rooms = _cachedRooms ??= _fetchRooms();
  // If the download fails, forget it so the next call tries again.
  rooms.then((_) {}, onError: (_) {
    if (identical(_cachedRooms, rooms)) _cachedRooms = null;
  });
  return rooms;
}

Future<List<Room>> _fetchRooms() async {
  // Ask for all three at the same time, then wait for them all.
  final results = await Future.wait([Api.getBuildings(), Api.getRooms(), Api.getAvailableRoomIds()]);
  final buildings = results[0] as List<dynamic>;
  final roomsJson = results[1] as List<dynamic>;
  final availableIds = results[2] as Set<int>;

  // e.g. {1: "Building 8", 2: "Building 10", ...}
  final buildingNames = {for (final b in buildings) b['id'] as int: b['name'] as String};
  final rooms = [for (final json in roomsJson) Room.fromApi(json, buildingNames, availableIds)];

  // Turn the server's buildings into Buildings keyed by number ("8"), using the
  // server's name and position. A building without a position goes in the middle of campus.
  campusBuildings = [
    for (final b in buildings)
      Building(
        id: _numberIn(b['name'] as String) ?? '${b['id']}',
        name: b['name'] as String,
        location: b['latitude'] != null && b['longitude'] != null
            ? LatLng((b['latitude'] as num).toDouble(), (b['longitude'] as num).toDouble())
            : campusCentre,
      ),
  ]..sort((a, b) => (int.tryParse(a.id) ?? 0).compareTo(int.tryParse(b.id) ?? 0));

  return rooms;
}

// "Building 80" → "80"
String? _numberIn(String text) => RegExp(r'\d+').firstMatch(text)?.group(0);
