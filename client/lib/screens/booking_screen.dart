import 'package:flutter/material.dart';

import '../models/booking.dart';
import '../models/room.dart';
import '../theme/colors.dart';
import '../util/api.dart';
import '../widgets/load_error.dart';

// "Book a room": pick a day, pick up to 2 hours of time slots, invite friends,
// then send it to the server's /book-room endpoint.
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
  final invited = <String>[]; // student IDs
  final inviteController = TextEditingController();
  bool sending = false; // true while waiting for the server

  @override
  void dispose() {
    inviteController.dispose();
    super.dispose();
  }

  // The real date and time a slot starts at. Slot 16 is 5:00pm (the end of slot 15).
  DateTime slotTime(int slot) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day + selectedDay, firstHour).add(Duration(minutes: slot * 30));
  }

  // "9:00", "9:30", ... "5:00"
  String slotLabel(int slot) {
    final time = slotTime(slot);
    var hour = time.hour % 12;
    if (hour == 0) hour = 12;
    return '$hour:${time.minute.toString().padLeft(2, '0')}';
  }

  // Slots that have already started can't be booked.
  // (The server doesn't tell us which times are taken yet. If one is, it
  // replies with "Room is already booked for that time" when you press Book.)
  bool isPast(int slot) => slotTime(slot).isBefore(DateTime.now());

  bool isSelected(int slot) {
    if (startSlot == null) return false;
    return slot >= startSlot! && slot <= endSlot!;
  }

  // First tap picks a start time. A second tap on a later slot (within 2 hours)
  // stretches the booking to that slot.
  void tapSlot(int slot) {
    if (isPast(slot)) return;
    setState(() {
      final start = startSlot;
      final canExtend = start != null && endSlot == start && slot > start && slot - start < maxSlots;
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

  void addInvite(String studentId) {
    final cleaned = studentId.trim().toUpperCase();
    if (cleaned.isEmpty || invited.contains(cleaned)) return;
    setState(() => invited.add(cleaned));
    inviteController.clear();
  }

  // Sends the booking to the server. On success it's added to "Current bookings".
  Future<void> book() async {
    setState(() => sending = true);
    final start = slotTime(startSlot!);
    final end = slotTime(endSlot! + 1);

    try {
      final result = await Api.bookRoom(roomId: widget.room.id, start: start, end: end, studentIds: invited);
      BookingStore.instance.add(Booking(
        id: result['booking_id'],
        room: widget.room,
        start: start,
        end: end,
        invited: List.from(invited),
      ));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Booked ${widget.room.readableName}')),
      );
      Navigator.pop(context);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => sending = false);
      if (e.needsLogin) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(content: LoadError(error: e, onRetry: () {})),
        );
      } else {
        // e.g. "Room is already booked for that time" or "Users not found: S123"
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.room;

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
                            startSlot = null; // a different day, so clear the time
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
                      hintText: 'Student ID, e.g. S4247161',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final studentId in invited)
                        InputChip(
                          label: Text(studentId),
                          backgroundColor: AppColors.lilacLight,
                          onDeleted: () => setState(() => invited.remove(studentId)),
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
                  onPressed: startSlot == null || sending ? null : book, // null = greyed out
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.lilacDark,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                  child: Text(
                    sending
                        ? 'Booking...'
                        : startSlot == null
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
    final past = isPast(slot);
    final selected = isSelected(slot);

    Color background = AppColors.freeLight;
    Color textColor = AppColors.freeDark;
    if (past) {
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
        onTap: past ? null : () => tapSlot(slot),
        child: Center(
          child: Text(
            slotLabel(slot),
            style: TextStyle(color: textColor, fontWeight: selected ? FontWeight.w600 : FontWeight.w400),
          ),
        ),
      ),
    );
  }
}
