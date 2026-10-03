import 'package:flutter/material.dart';

import '../models/building.dart';
import '../models/room.dart';
import '../theme/colors.dart';
import 'map_markers.dart';

// The white card at the bottom of the map.
// With no building picked it shows a hint; otherwise the building's rooms.
class BuildingCard extends StatelessWidget {
  final Building? building; // null = nothing selected yet
  final List<Room> rooms; // already filtered and sorted
  final void Function(Room) onRoomTap;

  const BuildingCard({super.key, required this.building, required this.rooms, required this.onRoomTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: SafeArea(
        top: false,
        child: building == null ? _buildHint() : _buildDetails(),
      ),
    );
  }

  Widget _buildHint() {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tap a building', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        SizedBox(height: 4),
        Text('to see its study rooms', style: TextStyle(fontSize: 14, color: AppColors.grey)),
        SizedBox(height: 12),
        StatusLegend(),
      ],
    );
  }

  Widget _buildDetails() {
    final freeCount = rooms.where((r) => r.status == RoomStatus.free).length;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(building!.name,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(
          '${rooms.length} rooms · $freeCount free now',
          style: const TextStyle(fontSize: 14, color: AppColors.grey),
        ),
        const SizedBox(height: 12),
        if (rooms.isEmpty)
          const Text('No rooms match your filters.', style: TextStyle(color: AppColors.grey))
        else
          // A sideways-scrolling row of room tiles, in the chosen sort order.
          SizedBox(
            height: 76,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: rooms.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) => _roomTile(rooms[index]),
            ),
          ),
        const SizedBox(height: 12),
        const StatusLegend(),
      ],
    );
  }

  Widget _roomTile(Room room) {
    return Material(
      color: AppColors.lilacLight,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: () => onRoomTap(room),
        child: Container(
          width: 132,
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: statusColor(room.status), shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Text(room.levelAndRoom.split(', ').last, style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Level ${room.floor} · ${room.seatsLabel}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: AppColors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
