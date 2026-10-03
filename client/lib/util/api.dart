import 'dart:convert';

import 'package:client/constants.dart';
import 'package:client/util/auth_storage.dart';
import 'package:http/http.dart' as http;

// Thrown when a request to the server fails.
class ApiException implements Exception {
  final String message;
  final bool needsLogin; // true when the login token is missing or has expired

  ApiException(this.message, {this.needsLogin = false});

  @override
  String toString() => message;
}

// Every call the app makes to William's Flask server lives here,
// so the screens never have to deal with URLs, headers or status codes.
class Api {
  static const _timeout = Duration(seconds: 10);

  // GET /get-buildings → [{id, name, latitude, longitude}, ...]
  static Future<List<dynamic>> getBuildings() async {
    return await _get('/get-buildings') as List<dynamic>;
  }

  // GET /get-rooms → [{id, name, building_id, floor, capacity, televisions, ...}, ...]
  static Future<List<dynamic>> getRooms() async {
    return await _get('/get-rooms') as List<dynamic>;
  }

  // The ids of the rooms the database marks as available right now.
  // Each room has a "status" in the database, which the server's scheduler keeps
  // up to date ("available", or "occupied" while a booking is running).
  // /get-rooms doesn't include it in its reply, but it can filter by it.
  static Future<Set<int>> getAvailableRoomIds() async {
    final rooms = await _get('/get-rooms?status=available') as List<dynamic>;
    return {for (final room in rooms) room['id'] as int};
  }

  // POST /add-to-booking → {message, booking_id, users: [{id, student_id}, ...]}
  // Returns the student IDs of everyone now in the booking.
  static Future<List<String>> addToBooking({required int bookingId, required String studentId}) async {
    final headers = await _authHeaders();
    final response = await _send(() => http.post(
          Uri.parse('$apiBaseUrl/add-to-booking'),
          headers: headers,
          body: jsonEncode({'booking_id': bookingId, 'invited_user_id': studentId}),
        ));
    final users = jsonDecode(response.body)['users'] as List<dynamic>;
    return [for (final user in users) user['student_id'] as String];
  }

  // POST /book-room → {booking_id, room_id, start_time, end_time, user_ids}
  // studentIds are the friends to add to the booking, e.g. ["S4247161"].
  static Future<Map<String, dynamic>> bookRoom({
    required int roomId,
    required DateTime start,
    required DateTime end,
    required List<String> studentIds,
  }) async {
    final headers = await _authHeaders();
    final response = await _send(() => http.post(
          Uri.parse('$apiBaseUrl/book-room'),
          headers: headers,
          body: jsonEncode({
            'room_id': roomId,
            // The server wants times with a timezone; UTC ("...Z") is simplest.
            'start_time': start.toUtc().toIso8601String(),
            'end_time': end.toUtc().toIso8601String(),
            'student_ids': studentIds,
          }),
        ));
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<dynamic> _get(String path) async {
    final headers = await _authHeaders();
    final response = await _send(() => http.get(
          Uri.parse('$apiBaseUrl$path'),
          headers: headers,
        ));
    return jsonDecode(response.body);
  }

  // Reads the saved login token (from the iPhone keychain / Android keystore).
  // Kept separate from _send so a storage problem isn't mistaken for a network one.
  static Future<Map<String, String>> _authHeaders() async {
    try {
      return await AuthStorage.authHeaders();
    } catch (e) {
      throw ApiException("Couldn't read the saved login from this device.\n($e)", needsLogin: true);
    }
  }

  // Sends a request and turns every kind of failure into an ApiException
  // with a message that can be shown to the user.
  static Future<http.Response> _send(Future<http.Response> Function() request) async {
    final http.Response response;
    try {
      response = await request().timeout(_timeout);
    } catch (e) {
      // Include the real error so it's clear what went wrong, e.g.
      // "Connection refused" (nothing listening there), "timed out" (wrong IP or
      // network), "App Transport Security" (iOS blocking plain http://).
      throw ApiException("Couldn't reach the server at $apiBaseUrl\n($e)");
    }

    if (response.statusCode >= 200 && response.statusCode < 300) return response;

    // 401 = not logged in or the login expired.
    if (response.statusCode == 401) {
      throw ApiException('Your login has expired. Please log in again.', needsLogin: true);
    }
    // 422 = the server didn't accept the login token. flask-jwt-extended says why in "msg".
    if (response.statusCode == 422) {
      String reason = 'unknown reason';
      try {
        reason = jsonDecode(response.body)['msg'] ?? reason;
      } catch (_) {}
      throw ApiException('The server rejected the login token ($reason).', needsLogin: true);
    }

    // Most of William's errors look like {"message": "..."}.
    try {
      final message = jsonDecode(response.body)['message'];
      if (message is String) throw ApiException(message);
    } on FormatException {
      // body wasn't JSON; fall through to the generic message
    }
    throw ApiException('Something went wrong (error ${response.statusCode}).');
  }
}
