import 'package:flutter/material.dart';

import '../models/booking.dart';
import '../models/building.dart';
import '../models/room.dart';
import '../theme/colors.dart';

// "Book a room": pick a day, pick up to 2 hours of time slots, invite friends.
// Nothing is saved yet. That happens once William's server has a bookings endpoint.
class BookingScreen extends StatefulWidget {
  final Room room;

  const BookingScreen({super.key, required this.room});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  static const firstHour = 9; // slots run 9:00am to 5:00pm
  static const slotCount = 16; // 16 half-hour slots
  static const maxSlots = 4; // 4 × 30 min = 2 hours

  int selectedDay = 0; // 0 = today, 1 = tomorrow, ...
  int? startSlot; // first selected slot, or null
  int? endSlot; // last selected slot, or null
  final invited = <String>[];
  final inviteController = TextEditingController();

  @override
  void dispose() {
    inviteController.dispose();
    super.dispose();
  }

  // "9:00", "9:30", ... "5:00" for slot numbers 0..16
  String slotLabel(int slot) {
    final totalMinutes = firstHour * 60 + slot * 30;
    var hour = totalMinutes ~/ 60;
    if (hour > 12) hour -= 12;
    final minutes = totalMinutes % 60 == 0 ? '00' : '30';
    return '$hour:$minutes';
  }

  // PRETEND bookings until the server tells us the real ones.
  bool isBooked(int slot) {
    final seed = widget.room.name.codeUnits.fold(0, (sum, c) => sum + c);
    return (seed + selectedDay * 7 + slot * 3) % 7 == 0;
  }

  bool isSelected(int slot) {
    if (startSlot == null) return false;
    return slot >= startSlot! && slot <= endSlot!;
  }

  // First tap picks a start time. A second tap on a later slot (within 2 hours,
  // with nothing booked in between) stretches the booking to that slot.
  void tapSlot(int slot) {
    if (isBooked(slot)) return;
    setState(() {
      final start = startSlot;
      final canExtend = start != null &&
          endSlot == start &&
          slot > start &&
          slot - start < maxSlots &&
          !List.generate(slot - start, (i) => start + 1 + i).any(isBooked);
      if (canExtend) {
        endSlot = slot;
      } else {
        startSlot = slot;
        endSlot = slot;
      }
    });
  }

  String dayLabel(int day) {
    if (day == 0) return 'Today';
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[DateTime.now().add(Duration(days: day)).weekday - 1];
  }

  void addInvite(String name) {
    if (name.trim().isEmpty) return;
    setState(() => invited.add(name.trim()));
    inviteController.clear();
  }

  // Adds the booking to "Current bookings" (only while the app is open,
  // until the server can save it) and goes back.
  void book() {
    BookingStore.instance.add(Booking(
      room: widget.room,
      day: dayLabel(selectedDay),
      time: '${slotLabel(startSlot!)}–${slotLabel(endSlot! + 1)}',
      invited: List.from(invited),
    ));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Booked ${widget.room.readableName}. Demo only, not saved to the server.')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.room;
    final building = findBuilding(room.buildingId);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white, elevation: 0, scrolledUnderElevation: 0),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  // Room heading
                  Text(room.readableName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(building.name, style: const TextStyle(fontSize: 15, color: AppColors.grey)),
                  const SizedBox(height: 6),
                  Text(room.featureSummary, style: const TextStyle(fontSize: 15)),
                  Text(room.roomType, style: const TextStyle(fontSize: 13, color: AppColors.grey)),
                  const SizedBox(height: 28),

                  // Day picker
                  _sectionTitle('Day'),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (var day = 0; day < 4; day++)
                        _pillButton(
                          label: dayLabel(day),
                          selected: day == selectedDay,
                          onTap: () => setState(() {
                            selectedDay = day;
                            startSlot = null; // bookings differ per day, so clear the time
                            endSlot = null;
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Time grid
                  Row(
                    children: [
                      _sectionTitle('Time'),
                      const Spacer(),
                      const Text('Up to 2 hours', style: TextStyle(fontSize: 13, color: AppColors.grey)),
                    ],
                  ),
                  GridView.count(
                    crossAxisCount: 4,
                    shrinkWrap: true, // let the grid sit inside the ListView
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1.9,
                    children: [for (var slot = 0; slot < slotCount; slot++) _timeSlot(slot)],
                  ),
                  const SizedBox(height: 28),

                  // Invite friends
                  _sectionTitle('Invite friends'),
                  TextField(
                    controller: inviteController,
                    onSubmitted: addInvite,
                    decoration: const InputDecoration(
                      hintText: 'Email or student name',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final name in invited)
                        InputChip(
                          label: Text(name),
                          backgroundColor: AppColors.lilacLight,
                          onDeleted: () => setState(() => invited.remove(name)),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // Book button pinned to the bottom
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: startSlot == null ? null : book, // null = greyed out
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.lilacDark,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                  child: Text(
                    startSlot == null
                        ? 'Pick a time'
                        : 'Book ${slotLabel(startSlot!)}–${slotLabel(endSlot! + 1)}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
    );
  }

  Widget _pillButton({required String label, required bool selected, required VoidCallback onTap}) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onTap(),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      selectedColor: AppColors.lilac,
      labelStyle: TextStyle(color: selected ? AppColors.lilacDark : AppColors.ink),
    );
  }

  Widget _timeSlot(int slot) {
    final booked = isBooked(slot);
    final selected = isSelected(slot);

    Color background = AppColors.freeLight;
    Color textColor = AppColors.freeDark;
    if (booked) {
      background = AppColors.chip;
      textColor = const Color(0xFFB0B0B0);
    } else if (selected) {
      background = AppColors.lilac;
      textColor = AppColors.lilacDark;
    }

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: booked ? null : () => tapSlot(slot),
        child: Center(
          child: Text(
            slotLabel(slot),
            style: TextStyle(
              color: textColor,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              decoration: booked ? TextDecoration.lineThrough : null,
            ),
          ),
        ),
      ),
    );
  }
}
