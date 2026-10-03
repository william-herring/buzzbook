import 'package:flutter/material.dart';

import '../models/room_filters.dart';
import '../theme/colors.dart';

// The white "Filters" card that floats at the top of the map.
class FilterBar extends StatelessWidget {
  final RoomFilters filters;
  final VoidCallback onChanged; // tells the map screen to redraw

  const FilterBar({super.key, required this.filters, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Filters', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const Spacer(),
              _buildSortMenu(),
            ],
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _chip('Free now', filters.freeNow, (on) => filters.freeNow = on),
              _chip('TV', filters.tv, (on) => filters.tv = on),
              _chip('Whiteboard', filters.whiteboard, (on) => filters.whiteboard = on),
              _chip('4+ seats', filters.fourPlusSeats, (on) => filters.fourPlusSeats = on),
            ],
          ),
        ],
      ),
    );
  }

  // One on/off chip.
  Widget _chip(String label, bool selected, void Function(bool) update) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (on) {
        update(on);
        onChanged();
      },
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      selectedColor: AppColors.lilac,
      labelStyle: TextStyle(color: selected ? AppColors.lilacDark : AppColors.ink, fontSize: 14),
    );
  }

  // The "Sort: ..." dropdown in the top right of the card.
  Widget _buildSortMenu() {
    const labels = {
      SortOption.availability: 'Availability',
      SortOption.name: 'Room name',
      SortOption.seats: 'Most seats',
    };
    return PopupMenuButton<SortOption>(
      initialValue: filters.sort,
      onSelected: (option) {
        filters.sort = option;
        onChanged();
      },
      itemBuilder: (context) => [
        for (final option in SortOption.values)
          PopupMenuItem(value: option, child: Text(labels[option]!)),
      ],
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Sort: ${labels[filters.sort]}', style: const TextStyle(fontSize: 14, color: AppColors.grey)),
            const Icon(Icons.expand_more, size: 18, color: AppColors.grey),
          ],
        ),
      ),
    );
  }
}
