import 'package:latlong2/latlong.dart';

const campusCentre = LatLng(-37.8076, 144.9634);

// One building that has study rooms, as sent by the server's /get-buildings.
class Building {
  final String id; // the building's number, e.g. "80"
  final String name; // e.g. "Building 80"
  final LatLng location; // where the building sits on the map

  const Building({required this.id, required this.name, required this.location});
}

// Every building from the server. Filled in by loadRooms() (see room.dart),
// so it's empty until the first download finishes.
// The only building data the app keeps itself is the outline shapes on the map
// (building_outlines.dart), because the server doesn't have those.
List<Building> campusBuildings = [];

// Finds a building by its number. If the server didn't send it (yet), we still
// return something sensible instead of crashing.
Building findBuilding(String id) {
  return campusBuildings.firstWhere(
    (b) => b.id == id,
    orElse: () => Building(id: id, name: 'Building $id', location: campusCentre),
  );
}
