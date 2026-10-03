import 'package:flutter/material.dart';

import '../models/room.dart';
import '../theme/colors.dart';

// The colour for each availability status.
Color statusColor(RoomStatus status) {
  switch (status) {
    case RoomStatus.free:
      return AppColors.free;
    case RoomStatus.busy:
      return AppColors.booked;
    case RoomStatus.booked:
      return AppColors.lilacDark;
  }
}

// The label drawn on top of a building, e.g. "80" with a "3 free" badge.
class BuildingMarker extends StatelessWidget {
  final String label;
  final int freeCount;
  final bool selected;

  const BuildingMarker({super.key, required this.label, required this.freeCount, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? Colors.white : AppColors.yellow,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.ink, width: 1.5),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          Text(
            '$freeCount free',
            style: const TextStyle(fontSize: 10, color: AppColors.freeDark),
          ),
        ],
      ),
    );
  }
}

// A round coloured dot for one room. The number inside is the floor.
class RoomPin extends StatelessWidget {
  final Room room;

  const RoomPin({super.key, required this.room});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '${room.readableName} · ${room.seatsLabel}',
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: statusColor(room.status),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 1))],
        ),
        child: Text(
          '${room.floor}',
          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

// The little "● Free  ● Busy now" key.
class StatusLegend extends StatelessWidget {
  const StatusLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _item('Free', AppColors.free),
        const SizedBox(width: 14),
        _item('Busy now', AppColors.booked),
        const SizedBox(width: 14),
        _item('Yours', AppColors.lilacDark),
      ],
    );
  }

  Widget _item(String label, Color color) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 13, color: AppColors.grey)),
      ],
    );
  }
}
