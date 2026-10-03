import 'package:flutter/material.dart';

import '../models/building.dart';
import '../models/room.dart';
import '../models/room_filters.dart';
import '../theme/colors.dart';
import '../widgets/current_bookings.dart';
import '../widgets/load_error.dart';
import '../widgets/map_markers.dart';
import 'booking_screen.dart';

// A list of every study room, grouped by building, with filters.
// Your current bookings sit at the top.
class RoomsScreen extends StatefulWidget {
  const RoomsScreen({super.key});

  @override
  State<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends State<RoomsScreen> {
  final filters = RoomFilters();
  List<Room> allRooms = [];
  bool loading = true;
  Object? error; // set if the server couldn't be reached

  @override
  void initState() {
    super.initState();
    fetchRooms();
  }

  Future<void> fetchRooms({bool refresh = false}) async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final rooms = await loadRooms(refresh: refresh);
      if (!mounted) return;
      setState(() => allRooms = rooms);
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e);
    }
    if (mounted) setState(() => loading = false);
  }

  void openBooking(Room room) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => BookingScreen(room: room)));
  }

  @override
  Widget build(BuildContext context) {
    // Build the list one section at a time: a heading per building,
    // then that building's rooms that pass the filters.
    final listItems = <Widget>[];
    for (final building in rmitBuildings) {
      final rooms = allRooms
          .where((r) => r.buildingId == building.id && filters.matches(r))
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      if (rooms.isEmpty) continue;

      listItems.add(_buildingHeading(building, rooms.length));
      for (final room in rooms) {
        listItems.add(_roomTile(room));
      }
    }

    return Scaffold(
      // Pull down on the list to fetch the rooms again.
      body: RefreshIndicator(
        onRefresh: () => fetchRooms(refresh: true),
        child: ListView(
        children: [
          const CurrentBookings(),
          const SizedBox(height: 8),
          _filterRow(),
          const Divider(height: 1),
          if (loading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (error != null) LoadError(error: error!, onRetry: () => fetchRooms(refresh: true)),
          if (!loading && error == null && listItems.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No rooms match these filters.', style: TextStyle(color: AppColors.grey)),
            ),
          ...listItems,
        ],
        ),
      ),
    );
  }

  // Building dropdown + on/off chips, in one row you can scroll sideways.
  Widget _filterRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          _buildingMenu(),
          const SizedBox(width: 8),
          _chip('Free now', filters.freeNow, (on) => filters.freeNow = on),
          const SizedBox(width: 8),
          _chip('TV', filters.tv, (on) => filters.tv = on),
          const SizedBox(width: 8),
          _chip('Whiteboard', filters.whiteboard, (on) => filters.whiteboard = on),
          const SizedBox(width: 8),
          _chip('4+ seats', filters.fourPlusSeats, (on) => filters.fourPlusSeats = on),
        ],
      ),
    );
  }

  Widget _buildingMenu() {
    final label = filters.buildingId == null ? 'All buildings' : 'Building ${filters.buildingId}';
    return PopupMenuButton<String?>(
      tooltip: 'Choose a building',
      onSelected: (id) => setState(() => filters.buildingId = id),
      itemBuilder: (context) => [
        const PopupMenuItem(value: null, child: Text('All buildings')),
        for (final b in rmitBuildings)
          PopupMenuItem(value: b.id, child: Text('Building ${b.id} · ${b.name}')),
      ],
      child: Chip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [Text(label), const Icon(Icons.arrow_drop_down, size: 18)],
        ),
        avatar: const Icon(Icons.apartment, size: 18),
        backgroundColor: filters.buildingId == null ? null : AppColors.lilac,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _chip(String label, bool selected, void Function(bool) update) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (on) => setState(() => update(on)),
      selectedColor: AppColors.lilac,
      checkmarkColor: AppColors.lilacDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }

  Widget _buildingHeading(Building building, int count) {
    return Container(
      color: AppColors.chip,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text('Building ${building.id}', style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(building.name,
                overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.grey)),
          ),
          Text('$count ${count == 1 ? 'room' : 'rooms'}',
              style: const TextStyle(color: AppColors.grey, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _roomTile(Room room) {
    return Column(
      children: [
        ListTile(
          title: Text(room.levelAndRoom),
          subtitle: Text(room.featureSummary),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.circle, size: 10, color: statusColor(room.status)),
              const SizedBox(width: 6),
              Text(room.statusLabel),
            ],
          ),
          onTap: () => openBooking(room),
        ),
        const Divider(height: 1, indent: 16),
      ],
    );
  }
}
