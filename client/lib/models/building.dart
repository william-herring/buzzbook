import 'package:latlong2/latlong.dart';

// One RMIT building that has study rooms.
class Building {
  final String id; // matches the "building" field in the rooms JSON, e.g. "80"
  final String name;
  final LatLng location; // where the building sits on the map

  const Building({required this.id, required this.name, required this.location});
}

// Locations come from OpenStreetMap (the centre of each building's outline).
// When William's server has a /buildings endpoint, this list can come from there instead.
const List<Building> rmitBuildings = [
  Building(id: '8', name: 'Swanston Library', location: LatLng(-37.80858, 144.96386)),
  Building(id: '10', name: 'Swanston Library', location: LatLng(-37.80811, 144.96369)),
  Building(id: '12', name: 'Swanston Library', location: LatLng(-37.80778, 144.96357)),
  Building(id: '80', name: 'Swanston Academic Building', location: LatLng(-37.80826, 144.96268)),
  Building(id: '94', name: 'Carlton Library', location: LatLng(-37.80591, 144.96396)),
];

// Finds a building by its number. If the server knows a building this list
// doesn't (yet), we still return something sensible instead of crashing.
Building findBuilding(String id) {
  return rmitBuildings.firstWhere(
    (b) => b.id == id,
    orElse: () => Building(id: id, name: 'Building $id', location: const LatLng(-37.8076, 144.9634)),
  );
}
