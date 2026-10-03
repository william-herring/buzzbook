import '../util/api.dart';

// Can the room be booked right now?
enum RoomStatus { free, occupied, unavailable }

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
  factory Room.fromApi(Map<String, dynamic> json, Map<int, String> buildingNumbers) {
    RoomStatus status = RoomStatus.free;
    if (json['occupied_now'] == true) status = RoomStatus.occupied;
    if (json['status'] != null && json['status'] != 'available') status = RoomStatus.unavailable;

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
      status: status,
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
      case RoomStatus.occupied:
        return 'In use';
      case RoomStatus.unavailable:
        return 'Unavailable';
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
  // Ask for both lists at the same time, then wait for both.
  final results = await Future.wait([Api.getBuildings(), Api.getRooms()]);
  final buildings = results[0];
  final rooms = results[1];

  // e.g. {1: "8", 2: "10", ...}
  final buildingNumbers = {for (final b in buildings) b['id'] as int: b['name'] as String};
  return rooms.map((json) => Room.fromApi(json, buildingNumbers)).toList();
}
