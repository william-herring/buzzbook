import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../models/room.dart';
import '../theme/colors.dart';
import '../util/api.dart';
import '../widgets/load_error.dart';
import 'booking_screen.dart';

// The room QR codes made by the server (generate_room_qr_zip in util.py) hold
// text like "buzzbook://room/12", where 12 is the room's id in the database.
const roomCodePrefix = 'buzzbook://room/';

// "buzzbook://room/12" → 12. Returns null for any other kind of QR code.
int? roomIdFromCode(String? text) {
  if (text == null || !text.startsWith(roomCodePrefix)) return null;
  return int.tryParse(text.substring(roomCodePrefix.length));
}

// Point the camera at a room's QR code:
//  - if you have a booking for that room right now, you're asked to sign in;
//  - otherwise you're taken to the room's page (the booking screen).
class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );

  // True while a scanned code is being dealt with, so the same code (or a
  // second one) isn't handled twice.
  bool handling = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void showMessage(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> onDetect(BarcodeCapture capture) async {
    if (handling) return;
    handling = true;

    int? roomId;
    for (final barcode in capture.barcodes) {
      roomId = roomIdFromCode(barcode.rawValue);
      if (roomId != null) break;
    }

    if (roomId == null) {
      showMessage("That isn't a Buzzbook room code");
      await Future.delayed(const Duration(seconds: 2)); // don't nag every frame
      handling = false;
      return;
    }

    await controller.stop();
    final leftScreen = await openRoom(roomId);
    if (!leftScreen && mounted) {
      handling = false;
      await controller.start(); // something went wrong or the user said "Not now"
    }
  }

  // Does the right thing for a scanned room. Returns true if this screen has
  // been closed or replaced, or false if scanning should carry on.
  Future<bool> openRoom(int roomId) async {
    try {
      // The app already has every room (shared with the List and Map tabs).
      final rooms = await loadRooms();
      final room = rooms.where((r) => r.id == roomId).firstOrNull;
      if (room == null) {
        if (mounted) showMessage("That room isn't one of your institution's rooms");
        return false;
      }

      // Does the server say you have a booking for this room right now?
      final status = await Api.getRoomBookingStatus(roomId);
      if (!mounted) return true;

      if (status['booking'] == null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => BookingScreen(room: room)),
        );
        return true;
      }

      final signIn = await confirmSignIn(room);
      if (!mounted) return true;
      if (signIn != true) return false; // "Not now": keep scanning

      await Api.signInToRoom(roomId);
      if (!mounted) return true;

      // Grab the messenger first: it outlives this screen, so the message
      // still shows after the scanner closes.
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(SnackBar(content: Text('Signed in to ${room.readableName}')));
      return true;
    } on ApiException catch (e) {
      if (!mounted) return true;
      if (e.needsLogin) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(content: LoadError(error: e, onRetry: () {})),
        );
        return true; // stay stopped; the dialog's button goes to the login screen
      }
      showMessage(e.message); // e.g. "You have no booking for this room right now"
      return false;
    } catch (e) {
      if (mounted) showMessage('$e');
      return false;
    }
  }

  Future<bool?> confirmSignIn(Room room) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign in to this room?'),
        content: Text('You have a booking for ${room.readableName} right now.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.lilacDark),
            child: const Text('Sign in'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan a room code')),
      body: Stack(
        children: [
          MobileScanner(controller: controller, onDetect: onDetect),

          // A square to aim the QR code into.
          IgnorePointer(
            child: Center(
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 3),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),

          const IgnorePointer(
            child: Align(
              alignment: Alignment(0, 0.7),
              child: Text(
                'Point the camera at the QR code on the room',
                style: TextStyle(color: Colors.white, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}