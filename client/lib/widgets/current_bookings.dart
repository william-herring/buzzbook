import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../models/booking.dart';
import '../theme/colors.dart';
import '../util/api.dart';

// "Current bookings" at the top of the Rooms screen.
// Swipe left/right to move between bookings. The Invite button adds friends
// to whichever booking is showing.
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
                  // Flexible + ellipsis so the heading shrinks instead of overflowing
                  // on narrow phones or with large text turned on.
                  Flexible(
                    child: Text(
                      bookings.length > 1
                          ? 'Current bookings · ${currentPage + 1} of ${bookings.length}'
                          : 'Current bookings',
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
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
                // A PageView needs a fixed height. Grow it with the phone's text
                // size setting, so bigger text doesn't overflow the card.
                height: MediaQuery.textScalerOf(context).scale(66) + 34,
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
        // One line each, cut off with "..." if too long, so the card never overflows.
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${booking.dayLabel}, ${booking.timeLabel}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: AppColors.grey)),
            Text(booking.room.readableName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            Text(invitedText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: AppColors.lilacDark)),
          ],
        ),
      ),
    );
  }

  // A panel that slides up from the bottom to add friends to a booking.
  void showInviteSheet(Booking booking) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // lets the sheet move up above the keyboard
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(8))),
      builder: (context) => _InviteSheet(booking: booking),
    );
  }
}

// The contents of the invite panel. It's its own StatefulWidget because it
// needs to remember things while open: whether it's busy, and any error.
class _InviteSheet extends StatefulWidget {
  final Booking booking;

  const _InviteSheet({required this.booking});

  @override
  State<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends State<_InviteSheet> {
  final controller = TextEditingController();
  bool sending = false;
  String? error; // the server's reason if adding failed

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> add() async {
    final studentId = controller.text.trim().toUpperCase();
    if (studentId.isEmpty || sending) return;

    setState(() {
      sending = true;
      error = null;
    });
    try {
      await BookingStore.instance.addInvite(widget.booking, studentId);
      controller.clear();
    } on ApiException catch (e) {
      error = e.message; // e.g. "Student S123 not found"
    }
    if (mounted) setState(() => sending = false);
  }

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;

    return Padding(
      // Push the content up when the on-screen keyboard opens.
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Invites', style: Theme.of(context).textTheme.titleMedium),
          Text('${booking.room.readableName} · ${booking.dayLabel}, ${booking.timeLabel}',
              style: const TextStyle(color: AppColors.grey)),
          const SizedBox(height: 12),
          if (booking.invited.isEmpty) const Text('Nobody invited yet.', style: TextStyle(color: AppColors.grey)),
          for (final studentId in booking.invited)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.lilac,
                child: Icon(Icons.person, size: 16, color: AppColors.lilacDark),
              ),
              title: Text(studentId),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: !sending,
                  onSubmitted: (_) => add(),
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: 'Student ID, e.g. S4247161',
                    border: const OutlineInputBorder(),
                    isDense: true,
                    errorText: error,
                    errorMaxLines: 2,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: sending ? null : add,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.lilac,
                  foregroundColor: AppColors.lilacDark,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
                child: Text(sending ? 'Adding...' : 'Add'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
