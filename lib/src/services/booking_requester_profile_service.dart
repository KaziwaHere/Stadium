import 'dart:convert';

import 'package:appwrite/appwrite.dart';
import 'package:stadium/src/appwrite_client.dart';
import 'package:stadium/src/services/booking_service.dart';

abstract class BookingRequesterProfileRepository {
  Future<BookingRequesterProfile> getProfile({
    required String managerId,
    required String requestId,
  });
}

class BookingRequesterProfileService
    implements BookingRequesterProfileRepository {
  BookingRequesterProfileService(this._functions);

  final Functions _functions;

  @override
  Future<BookingRequesterProfile> getProfile({
    required String managerId,
    required String requestId,
  }) => _fetchProfile(managerId: managerId, requestId: requestId);

  Future<BookingRequesterProfile> _fetchProfile({
    required String managerId,
    required String requestId,
  }) async {
    final execution = await _functions.createExecution(
      functionId: BookingService.functionId,
      body: jsonEncode({
        'action': 'getBookingRequesterProfile',
        'userId': managerId,
        'requestId': requestId,
      }),
      xasync: false,
    );

    final body = _decode(execution.responseBody);
    if (execution.responseStatusCode < 200 ||
        execution.responseStatusCode >= 300) {
      throw BookingServiceException(
        body['error']?.toString() ?? 'Could not load requester profile.',
      );
    }

    final profile = body['profile'];
    if (profile is! Map) {
      throw const BookingServiceException('Requester profile is missing.');
    }
    return BookingRequesterProfile.fromMap(Map<String, dynamic>.from(profile));
  }

  Map<String, dynamic> _decode(String value) {
    if (value.trim().isEmpty) return const {};
    final decoded = jsonDecode(value);
    return decoded is Map<String, dynamic> ? decoded : const {};
  }
}

class BookingRequesterProfile {
  const BookingRequesterProfile({
    required this.userId,
    required this.name,
    required this.phone,
    this.profilePictureId,
  });

  factory BookingRequesterProfile.fromMap(Map<String, dynamic> map) {
    final pictureId = map['profilePictureId']?.toString().trim();
    return BookingRequesterProfile(
      userId: map['id'].toString(),
      name: map['name']?.toString().trim() ?? '',
      phone: map['phone']?.toString().trim() ?? '',
      profilePictureId: pictureId == null || pictureId.isEmpty
          ? null
          : pictureId,
    );
  }

  final String userId;
  final String name;
  final String phone;
  final String? profilePictureId;
}

final BookingRequesterProfileRepository bookingRequesterProfileService =
    BookingRequesterProfileService(Functions(client));
