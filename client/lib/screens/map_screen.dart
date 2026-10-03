import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/building.dart';
import '../models/building_outlines.dart';
import '../models/room.dart';
import '../models/room_filters.dart';
import '../theme/colors.dart';
import '../widgets/building_card.dart';
import '../widgets/filter_bar.dart';
import '../widgets/load_error.dart';
import '../widgets/map_markers.dart';
import 'booking_screen.dart';

// The main screen: a map of RMIT City campus.
// Tap a building → its rooms appear as coloured pins → tap a pin → booking page.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final mapController = MapController();
  final filters = RoomFilters();

  // Tells us which building shape (if any) was under the finger/mouse on a tap.
  final LayerHitNotifier<String> buildingHit = ValueNotifier(null);

  List<Room> allRooms = []; // filled in once the server replies
  Object? error; // set if the server couldn't be reached
  Building? selectedBuilding; // null until the user taps a building

  @override
  void initState() {
    super.initState();
    fetchRooms();
  }

  Future<void> fetchRooms({bool refresh = false}) async {
    setState(() => error = null);
    try {
      final rooms = await loadRooms(refresh: refresh);
      if (mounted) setState(() => allRooms = rooms);
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  // Rooms in one building that pass the filters, in the chosen sort order.
  List<Room> roomsIn(Building building) {
    final matching = allRooms.where((r) => r.buildingId == building.id && filters.matches(r)).toList();
    return filters.sorted(matching);
  }

  // Where to put a building's label and room pins.
  // If we have its outline, use the middle of the outline so everything sits on
  // the shape. Otherwise use the position from the server.
  // (The server's positions are a little off for some buildings, so they don't
  // always line up with the outlines.)
  LatLng spotFor(Building building) {
    final outline = buildingOutlines[building.id];
    if (outline == null) return building.location;
    final lat = outline.map((p) => p.latitude).reduce((a, b) => a + b) / outline.length;
    final lng = outline.map((p) => p.longitude).reduce((a, b) => a + b) / outline.length;
    return LatLng(lat, lng);
  }

  void selectBuilding(Building building) {
    setState(() => selectedBuilding = building);
    mapController.move(spotFor(building), 19); // zoom in on it
  }

  // Zoom in or out by one step, keeping the same centre.
  void zoomBy(double amount) {
    final camera = mapController.camera;
    mapController.move(camera.center, camera.zoom + amount);
  }

  void openBooking(Room room) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => BookingScreen(room: room)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = selectedBuilding;

    return Scaffold(
      backgroundColor: AppColors.mapBackground,
      body: Stack(
        children: [
          // 1. The map itself, filling the whole screen.
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              initialCenter: campusCentre,
              initialZoom: 17,
              minZoom: 15,
              maxZoom: 20,
              // Stop the map being dragged too far away from campus.
              cameraConstraint: CameraConstraint.containCenter(
                bounds: LatLngBounds(const LatLng(-37.815, 144.955), const LatLng(-37.800, 144.972)),
              ),
              // Pinch-zoom, drag, scroll-wheel and double-tap zoom are all on by
              // default. We only switch off rotating, which is easy to do by
              // accident while pinching.
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              // Tapping empty map closes the selected building.
              onTap: (tapPosition, point) => setState(() => selectedBuilding = null),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.buzzbook.client',
                maxNativeZoom: 19, // OSM has no zoom-20 pictures, so it enlarges zoom-19 ones
              ),
              buildingShapes(),
              MarkerLayer(markers: buildingMarkers()),
              if (selected != null) MarkerLayer(markers: roomPins(selected)),
              const RichAttributionWidget(
                attributions: [TextSourceAttribution('OpenStreetMap contributors')],
              ),
            ],
          ),

          // If loading failed, show why in a card in the middle of the map.
          if (error != null)
            Center(
              child: Card(
                margin: const EdgeInsets.all(32),
                child: LoadError(error: error!, onRetry: () => fetchRooms(refresh: true)),
              ),
            ),

          // 2. The filter card floating at the top.
          Positioned(
            top: 0,
            left: 16,
            right: 16,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    FilterBar(filters: filters, onChanged: () => setState(() {})),
                    const SizedBox(height: 8),
                    zoomButtons(),
                  ],
                ),
              ),
            ),
          ),

          // 3. The info card at the bottom.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: BuildingCard(
              building: selected,
              rooms: selected == null ? [] : roomsIn(selected),
              onRoomTap: openBooking,
            ),
          ),
        ],
      ),
    );
  }

  // Each building's outline, filled in like a stadium seating section.
  // Tapping anywhere inside a shape selects that building.
  Widget buildingShapes() {
    return MouseRegion(
      hitTestBehavior: HitTestBehavior.deferToChild,
      cursor: SystemMouseCursors.click, // pointer cursor when hovering a building
      child: GestureDetector(
        onTap: () {
          final hit = buildingHit.value;
          if (hit == null) return;
          selectBuilding(findBuilding(hit.hitValues.first));
        },
        child: PolygonLayer<String>(
          hitNotifier: buildingHit,
          polygons: [
            // Only buildings we have an outline shape for (see building_outlines.dart).
            for (final building in campusBuildings.where((b) => buildingOutlines.containsKey(b.id)))
              Polygon<String>(
                points: buildingOutlines[building.id]!,
                hitValue: building.id, // what buildingHit reports when this shape is tapped
                color: building == selectedBuilding
                    ? AppColors.lilac.withValues(alpha: 0.7)
                    : AppColors.yellow.withValues(alpha: 0.6),
                borderColor: building == selectedBuilding ? AppColors.lilacDark : AppColors.ink,
                borderStrokeWidth: building == selectedBuilding ? 2.5 : 1.5,
              ),
          ],
        ),
      ),
    );
  }

  // + / − / back-to-campus buttons under the filter card.
  Widget zoomButtons() {
    Widget button(IconData icon, String tooltip, VoidCallback onPressed) {
      return Material(
        color: Colors.white,
        elevation: 2,
        borderRadius: BorderRadius.circular(4),
        child: IconButton(icon: Icon(icon), tooltip: tooltip, onPressed: onPressed),
      );
    }

    return Column(
      children: [
        button(Icons.add, 'Zoom in', () => zoomBy(1)),
        const SizedBox(height: 4),
        button(Icons.remove, 'Zoom out', () => zoomBy(-1)),
        const SizedBox(height: 4),
        button(Icons.center_focus_strong, 'Back to campus', () => mapController.move(campusCentre, 17)),
      ],
    );
  }

  // One marker per building, showing how many matching rooms are free.
  List<Marker> buildingMarkers() {
    return [
      for (final building in campusBuildings)
        if (building != selectedBuilding) // the selected one is replaced by its room pins
          Marker(
            point: spotFor(building),
            width: 52,
            height: 44,
            child: GestureDetector(
              onTap: () => selectBuilding(building),
              child: BuildingMarker(
                label: building.id,
                freeCount: roomsIn(building).where((r) => r.status == RoomStatus.free).length,
                selected: false,
              ),
            ),
          ),
    ];
  }

  // PRETEND positions for each room, since we don't know where rooms really are
  // inside a building. Rooms are laid out in a grid on top of the building:
  // one row per floor (top floor at the top), up to 6 rooms per row.
  List<Marker> roomPins(Building building) {
    const latStep = 0.00007; // about 8 metres north/south
    const lngStep = 0.00009; // about 8 metres east/west
    const perRow = 6;

    // Group the rooms by floor, highest floor first.
    final rooms = roomsIn(building);
    final floors = rooms.map((r) => r.floor).toSet().toList()..sort((a, b) => b.compareTo(a));
    final rows = <List<Room>>[];
    for (final floor in floors) {
      final onFloor = rooms.where((r) => r.floor == floor).toList();
      for (var i = 0; i < onFloor.length; i += perRow) {
        rows.add(onFloor.sublist(i, (i + perRow).clamp(0, onFloor.length)));
      }
    }

    final markers = <Marker>[];
    for (var row = 0; row < rows.length; row++) {
      final lat = spotFor(building).latitude + (rows.length / 2 - row - 0.5) * latStep;
      for (var col = 0; col < rows[row].length; col++) {
        final lng = spotFor(building).longitude + (col - (rows[row].length - 1) / 2) * lngStep;
        final room = rows[row][col];
        markers.add(
          Marker(
            point: LatLng(lat, lng),
            width: 30,
            height: 30,
            child: GestureDetector(
              onTap: () => openBooking(room),
              child: RoomPin(room: room),
            ),
          ),
        );
      }
    }
    return markers;
  }
}
