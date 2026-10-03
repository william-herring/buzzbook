import 'room.dart';

enum SortOption { availability, name, seats }

// Which filter chips are switched on, and how to sort.
class RoomFilters {
  String? buildingId; // null = all buildings
  bool freeNow = false;
  bool tv = false;
  bool whiteboard = false;
  bool fourPlusSeats = false;
  SortOption sort = SortOption.availability;

  // Does this room pass every filter that is switched on?
  bool matches(Room room) {
    if (buildingId != null && room.buildingId != buildingId) return false;
    if (freeNow && room.status != RoomStatus.free) return false;
    if (tv && !room.hasTv) return false;
    if (whiteboard && !room.hasWhiteboard) return false;
    if (fourPlusSeats && room.capacity < 4) return false;
    return true;
  }

  // Returns a new, sorted copy of the list.
  List<Room> sorted(List<Room> rooms) {
    final copy = List<Room>.from(rooms);
    switch (sort) {
      case SortOption.availability:
        copy.sort((a, b) => a.status.index.compareTo(b.status.index));
      case SortOption.name:
        copy.sort((a, b) => a.name.compareTo(b.name));
      case SortOption.seats:
        copy.sort((a, b) => b.capacity.compareTo(a.capacity));
    }
    return copy;
  }
}
