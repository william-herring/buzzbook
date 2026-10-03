import 'package:latlong2/latlong.dart';

import '../util/api.dart';
import 'booking.dart';
import 'building.dart';

// free   = the database says it's available
// busy   = the database says it isn't (someone's booking is running, or it's closed)
// booked = you've booked it (shown straight away, before the database catches up)
enum RoomStatus { free, busy, booked }

// One study room, as sent by the server's /get-rooms endpoint.
class Room {
  final int id; // the server's id, needed to book it
  final String name; // e.g. "80.05.003" or "Group Study A"
  final String buildingId; // the server's id for the building, as text (see Building.id)
  final String buildingName; // e.g. "Building 80" or "Baillieu Library"
  final int floor;
  final String roomType;
  final int capacity;
  final bool hasTv;
  final bool hasWhiteboard;
  final bool hasProjector;
  final RoomStatus dbStatus; // what the database said when we last loaded

  Room({
    required this.id,
    required this.name,
    required this.buildingId,
    required this.buildingName,
    required this.floor,
    required this.roomType,
    required this.capacity,
    required this.hasTv,
    required this.hasWhiteboard,
    required this.hasProjector,
    required this.dbStatus,
  });

  // Turns one room from the server into a Room.
  // buildingNames maps the server's building ids to their names, e.g. {1: "Building 8"}.
  // availableIds is the set of rooms the database says are available right now.
  //
  // Rooms are tied to their building by the server's building id. We don't try
  // to read a building number out of any name, because not every institution
  // has numbered buildings or "80.05.003"-style room names.
  factory Room.fromApi(Map<String, dynamic> json, Map<int, String> buildingNames, Set<int> availableIds) {
    return Room(
      id: json['id'],
      name: json['name'],
      buildingId: '${json['building_id']}',
      buildingName: buildingNames[json['building_id']] ?? 'Unknown building',
      floor: json['floor'] ?? 0,
      roomType: json['room_type'] ?? '',
      capacity: json['capacity'] ?? 0,
      hasTv: (json['televisions'] ?? 0) > 0,
      hasWhiteboard: (json['whiteboards'] ?? 0) > 0,
      hasProjector: (json['projectors'] ?? 0) > 0,
      dbStatus: availableIds.contains(json['id']) ? RoomStatus.free : RoomStatus.busy,
    );
  }

  // "80.05.003" → "Building 80, Level 5, Room 3"
  // "Group Study A" → "Baillieu Library, Level 2, Group Study A"
  String get readableName => '$buildingName, $levelAndRoom';

  // "80.05.003" → "Level 5, Room 3" (for lists already grouped by building)
  String get levelAndRoom {
    // RMIT-style names are building.level.room, like "80.05.003".
    final parts = name.split('.');
    final rmitStyle = parts.length == 3 && RegExp(r'^\d+$').hasMatch(parts.first);
    if (!rmitStyle) return 'Level $floor, $name';

    // Drop leading zeros: "003" → "3", "003A" → "3A", "101" stays "101"
    final roomNumber = parts.last.replaceFirst(RegExp(r'^0+(?=.)'), '');
    return 'Level $floor, Room $roomNumber';
  }

  // Your booking for this room that hasn't finished yet, if you have one.
  Booking? get myBooking => BookingStore.instance.bookings
      .where((b) => b.room.id == id && b.end.isAfter(DateTime.now()))
      .firstOrNull;

  // The database only marks a room busy once a booking STARTS, so a room you've
  // just booked for later would still look free. Your own bookings win.
  RoomStatus get status => myBooking != null ? RoomStatus.booked : dbStatus;

  String get statusLabel {
    switch (status) {
      case RoomStatus.free:
        return 'Free';
      case RoomStatus.busy:
        return 'Busy now';
      case RoomStatus.booked:
        final booking = myBooking!;
        final day = booking.dayLabel == 'Today' ? '' : '${booking.dayLabel} ';
        return 'Booked by you · $day${booking.timeLabel}';
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

// Throws away the remembered rooms, so the next loadRooms() asks the server again.
void forgetRooms() => _cachedRooms = null;

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

  // Where each building is, for the buildings the server has a position for.
  final positions = <int, LatLng>{
    for (final b in buildings)
      if (b['latitude'] != null && b['longitude'] != null)
        b['id'] as int: LatLng((b['latitude'] as num).toDouble(), (b['longitude'] as num).toDouble()),
  };

  // The map opens in the middle of this institution's buildings, whichever
  // university that is.
  if (positions.isNotEmpty) campusCentre = centroidOf(positions.values.toList());

  // A building the server has no position for goes in the middle of campus.
  campusBuildings = [
    for (final b in buildings)
      Building(
        id: '${b['id']}',
        name: b['name'] as String,
        location: positions[b['id']] ?? campusCentre,
        outline: _parseOutline(b['outline']),
      ),
  ]..sort(_compareBuildings);

  return rooms;
}

// The server sends an outline as [[latitude, longitude], ...], or null.
List<LatLng>? _parseOutline(dynamic raw) {
  if (raw is! List) return null;
  final points = [
    for (final p in raw)
      if (p is List && p.length == 2) LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble()),
  ];
  return points.length >= 3 ? points : null;
}

// Numbered buildings first, in number order ("Building 8" before "Building 10"),
// then the rest alphabetically.
int _compareBuildings(Building a, Building b) {
  final x = int.tryParse(a.number ?? '');
  final y = int.tryParse(b.number ?? '');
  if (x != null && y != null && x != y) return x.compareTo(y);
  if (x != null && y == null) return -1;
  if (x == null && y != null) return 1;
  return a.name.compareTo(b.name);
}