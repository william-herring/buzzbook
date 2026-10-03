import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../models/booking.dart';
import '../models/building.dart';
import '../theme/colors.dart';

// "Current bookings" at the top of the Rooms screen.
// Swipe left/right to move between bookings. The Invite button edits
// the invites of whichever booking is showing.
class CurrentBookings extends StatefulWidget {
  const CurrentBookings({super.key});

  @override
  State<CurrentBookings> createState() => _CurrentBookingsState();
}

class _CurrentBookingsState extends State<CurrentBookings> {
  // viewportFraction < 1 lets the next card peek in, so it's obvious you can swipe.
  final pageController = PageController(viewportFraction: 0.92);
  int currentPage = 0;

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ListenableBuilder redraws this part whenever the BookingStore changes.
    return ListenableBuilder(
      listenable: BookingStore.instance,
      builder: (context, _) {
        final bookings = BookingStore.instance.bookings;
        if (currentPage >= bookings.length) currentPage = 0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
              child: Row(
                children: [
                  Text('Current bookings', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(width: 8),
                  if (bookings.length > 1)
                    Text('${currentPage + 1} of ${bookings.length}',
                        style: const TextStyle(color: AppColors.grey, fontSize: 13)),
                  const Spacer(),
                  if (bookings.isNotEmpty)
                    TextButton.icon(
                      onPressed: () => showInviteSheet(bookings[currentPage]),
                      icon: const Icon(Icons.person_add_alt_1, size: 18),
                      label: const Text('Invite'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.lilacDark,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                ],
              ),
            ),
            if (bookings.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text('No bookings yet. Pick a room below.', style: TextStyle(color: AppColors.grey)),
              )
            else
              SizedBox(
                height: 104,
                // By default Flutter on the web doesn't let you drag a PageView
                // with the mouse, only with touch. This adds mouse dragging so
                // swiping works when testing in Chrome.
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context).copyWith(
                    dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse, PointerDeviceKind.trackpad},
                  ),
                  child: PageView.builder(
                    controller: pageController,
                    itemCount: bookings.length,
                    onPageChanged: (page) => setState(() => currentPage = page),
                    itemBuilder: (context, index) => _bookingCard(bookings[index]),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _bookingCard(Booking booking) {
    final building = findBuilding(booking.room.buildingId);
    final invitedText = booking.invited.isEmpty ? 'Just you' : 'With ${booking.invited.join(', ')}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.yellowLight,
          border: Border.all(color: AppColors.yellow),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${booking.day}, ${booking.time}',
                style: const TextStyle(fontSize: 13, color: AppColors.grey)),
            const SizedBox(height: 2),
            Text(booking.room.readableName,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            Text(building.name, style: const TextStyle(fontSize: 13)),
            const Spacer(),
            Text(invitedText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: AppColors.lilacDark)),
          ],
        ),
      ),
    );
  }

  // A panel that slides up from the bottom to add or remove invited people.
  void showInviteSheet(Booking booking) {
    final controller = TextEditingController();
    final store = BookingStore.instance;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // lets the sheet move up above the keyboard
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(8))),
      builder: (context) {
        return ListenableBuilder(
          listenable: store,
          builder: (context, _) {
            void add() {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              store.addInvite(booking, name);
              controller.clear();
            }

            return Padding(
              // Push the content up when the on-screen keyboard opens.
              padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Invites', style: Theme.of(context).textTheme.titleMedium),
                  Text(booking.room.readableName, style: const TextStyle(color: AppColors.grey)),
                  const SizedBox(height: 12),
                  if (booking.invited.isEmpty)
                    const Text('Nobody invited yet.', style: TextStyle(color: AppColors.grey)),
                  for (final name in booking.invited)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: const CircleAvatar(
                        radius: 14,
                        backgroundColor: AppColors.lilac,
                        child: Icon(Icons.person, size: 16, color: AppColors.lilacDark),
                      ),
                      title: Text(name),
                      trailing: IconButton(
                        tooltip: 'Remove $name',
                        icon: const Icon(Icons.close),
                        onPressed: () => store.removeInvite(booking, name),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: controller,
                          onSubmitted: (_) => add(),
                          decoration: const InputDecoration(
                            hintText: 'Email or student name',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: add,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.lilac,
                          foregroundColor: AppColors.lilacDark,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        ),
                        child: const Text('Add'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
