import 'package:latlong2/latlong.dart';

import 'building_outlines.dart';

// Where the map starts. This is RMIT City until the buildings arrive from the
// server; then loadRooms() (see room.dart) moves it to the middle of whichever
// institution's buildings were sent, so every university gets its own campus.
LatLng campusCentre = const LatLng(-37.8076, 144.9634);

// One building that has study rooms, as sent by the server's /get-buildings.
class Building {
  final String id; // the server's database id for the building, as text, e.g. "7"
  final String name; // whatever the institution calls it: "Building 80", "Baillieu Library"
  final LatLng location; // where the building sits on the map
  final List<LatLng>? outline; // the building's footprint from the server, if it has one

  const Building({required this.id, required this.name, required this.location, this.outline});

  // Two Buildings are the same building if they have the same id. (loadRooms()
  // makes fresh Building objects every time it downloads, and the map needs to
  // recognise the selected building afterwards.)
  @override
  bool operator ==(Object other) => other is Building && other.id == id;

  @override
  int get hashCode => id.hashCode;

  // A building number in the name, if it has one: "Building 80" → "80".
  // Plenty of institutions don't number their buildings, so this can be null.
  String? get number => RegExp(r'\d+').firstMatch(name)?.group(0);

  // Short text for the little marker on the map.
  //   "Building 80"            → "80"
  //   "Baillieu Library"       → "BL"
  //   "Redmond Barry Building" → "RB"
  //   "Engineering"            → "ENG"
  String get shortLabel {
    final digits = number;
    if (digits != null) return digits;

    final words = name
        .split(RegExp(r'[^A-Za-z]+'))
        .where((w) => w.isNotEmpty && !_genericWords.contains(w.toLowerCase()))
        .toList();
    if (words.isEmpty) return name.isEmpty ? '?' : name.substring(0, 1).toUpperCase();
    if (words.length == 1) {
      final word = words.first;
      return word.substring(0, word.length < 3 ? word.length : 3).toUpperCase();
    }
    return words.take(3).map((w) => w[0]).join().toUpperCase();
  }

  static const _genericWords = {'building', 'bldg', 'block'};
}

// Every building from the server. Filled in by loadRooms() (see room.dart),
// so it's empty until the first download finishes.
List<Building> campusBuildings = [];

// Finds a building by its id. If the server didn't send it (yet), we still
// return something sensible instead of crashing.
Building findBuilding(String id) {
  return campusBuildings.firstWhere(
        (b) => b.id == id,
    orElse: () => Building(id: id, name: 'Unknown building', location: campusCentre),
  );
}

// The middle of a shape, from the average of its corners.
LatLng centroidOf(List<LatLng> points) {
  final lat = points.map((p) => p.latitude).reduce((a, b) => a + b) / points.length;
  final lng = points.map((p) => p.longitude).reduce((a, b) => a + b) / points.length;
  return LatLng(lat, lng);
}

// The outline (footprint) to draw for a building on the map, or null if we
// don't have one.
//
// 1. Outlines come from the server, so any institution can have them: add an
//    "outline" to a building in its JSON file (a list of [latitude, longitude]).
// 2. Failing that, RMIT's buildings fall back to the outlines bundled with the
//    app (building_outlines.dart), which are keyed by building number. Another
//    university could easily have a "Building 80" too, so a bundled outline is
//    only used when it's really where the server says the building is (the
//    server's positions can be a couple of hundred metres off).
List<LatLng>? outlineFor(Building building) {
  final fromServer = building.outline;
  if (fromServer != null && fromServer.length >= 3) return fromServer;

  final number = building.number;
  final outline = number == null ? null : buildingOutlines[number];
  if (outline == null) return null;

  final metresAway = const Distance().as(LengthUnit.Meter, centroidOf(outline), building.location);
  return metresAway < 500 ? outline : null;
}