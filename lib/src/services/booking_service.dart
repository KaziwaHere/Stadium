import 'dart:convert';

import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:flutter/material.dart';
import 'package:stadium/src/appwrite_client.dart';
import 'package:stadium/src/models/stadium.dart';

abstract class BookingsRepository {
  Future<List<StadiumBooking>> listBookings(String userId);

  Future<List<StadiumBooking>> listBookingHistory(String userId);

  Future<Set<String>> bookedSlotKeys(String stadiumId);

  Future<StadiumBooking> createBooking({
    required String userId,
    required String userName,
    required Stadium stadium,
    required BookingDay day,
    required BookingSlot slot,
  });

  Future<void> cancelBooking({required StadiumBooking booking});
}

class BookingService implements BookingsRepository {
  BookingService(this._tables, this._functions);

  static const functionId = 'admin-users';
  static const databaseId = 'stadium_booking';
  static const tableId = 'bookings';
  static const bookedSlotsTableId = 'booked_slots';
  static const activeStatus = 'active';
  static const pendingStatus = 'pending';
  static const deniedStatus = 'denied';
  static const cancelledStatus = 'cancelled';
  static const _availabilityCacheTtl = Duration(seconds: 45);

  final TablesDB _tables;
  final Functions _functions;
  final Map<String, _CacheEntry<List<StadiumBooking>>> _bookingsCache = {};
  final Map<String, Future<List<StadiumBooking>>> _bookingsRequests = {};
  final Map<String, _CacheEntry<Set<String>>> _availabilityCache = {};
  final Map<String, Future<Set<String>>> _availabilityRequests = {};

  @override
  Future<List<StadiumBooking>> listBookings(String userId) async {
    final existingRequest = _bookingsRequests[userId];
    if (existingRequest != null) return existingRequest;

    final request = _fetchBookings(userId);
    _bookingsRequests[userId] = request;

    try {
      final bookings = await request;
      _bookingsCache[userId] = _CacheEntry(bookings);
      return bookings;
    } finally {
      _bookingsRequests.remove(userId);
    }
  }

  Future<List<StadiumBooking>> _fetchBookings(String userId) async {
    return _fetchBookingsByStatuses(userId, const [
      activeStatus,
      pendingStatus,
      deniedStatus,
    ]);
  }

  @override
  Future<List<StadiumBooking>> listBookingHistory(String userId) {
    return _fetchBookingsByStatuses(userId, const [
      activeStatus,
      pendingStatus,
      deniedStatus,
      cancelledStatus,
    ]);
  }

  Future<List<StadiumBooking>> _fetchBookingsByStatuses(
    String userId,
    List<String> statuses,
  ) async {
    final rows = await _tables.listRows(
      databaseId: databaseId,
      tableId: tableId,
      queries: [
        Query.equal('userId', userId),
        Query.equal('status', statuses),
        Query.orderAsc('dayDate'),
        Query.orderAsc('slotTime'),
      ],
    );

    return rows.rows.map(StadiumBooking.fromRow).toList()
      ..sort(_compareBookings);
  }

  @override
  Future<Set<String>> bookedSlotKeys(String stadiumId) async {
    final cached = _freshCachedAvailability(stadiumId);
    if (cached != null) return cached;

    final existingRequest = _availabilityRequests[stadiumId];
    if (existingRequest != null) return existingRequest;

    final request = _fetchBookedSlotKeys(stadiumId);
    _availabilityRequests[stadiumId] = request;

    try {
      final keys = await request;
      _availabilityCache[stadiumId] = _CacheEntry(keys);
      return keys;
    } finally {
      _availabilityRequests.remove(stadiumId);
    }
  }

  Future<Set<String>> _fetchBookedSlotKeys(String stadiumId) async {
    final rows = await _tables.listRows(
      databaseId: databaseId,
      tableId: bookedSlotsTableId,
      queries: [
        Query.equal('stadiumId', stadiumId),
        Query.equal('status', [activeStatus, pendingStatus]),
        Query.limit(100),
      ],
    );

    return rows.rows
        .map(BookedSlot.fromRow)
        .map((slot) => slot.slotKey)
        .toSet();
  }

  @override
  Future<StadiumBooking> createBooking({
    required String userId,
    required String userName,
    required Stadium stadium,
    required BookingDay day,
    required BookingSlot slot,
  }) async {
    final slotId = _slotId(stadium.id, day.date, slot.time);

    final payload = await _executeBookingFunction({
      'action': 'createBooking',
      'userId': userId,
      'userName': userName,
      'stadiumId': stadium.id,
      'slotId': slotId,
      'stadiumName': stadium.name,
      'location': stadium.location,
      'rating': stadium.rating,
      'price': stadium.price,
      'icon': stadium.iconKey,
      'dayLabel': day.label,
      'dayDate': day.date,
      'slotTime': slot.time,
    });
    final booking = StadiumBooking.fromMap(_bookingPayload(payload));
    _appendCachedBooking(userId, booking);
    if (booking.status == activeStatus || booking.status == pendingStatus) {
      _addCachedBookedSlot(stadium.id, booking.slotKey);
    }
    return booking;
  }

  @override
  Future<void> cancelBooking({required StadiumBooking booking}) async {
    await _tables.updateRow(
      databaseId: databaseId,
      tableId: tableId,
      rowId: booking.rowId,
      data: {'status': cancelledStatus},
    );

    await _deleteBookedSlotMarker(booking.slotId);
    _removeCachedBooking(booking);
    _removeCachedBookedSlot(booking.stadiumId, booking.slotKey);
  }

  Future<void> _deleteBookedSlotMarker(String slotId) async {
    try {
      await _tables.deleteRow(
        databaseId: databaseId,
        tableId: bookedSlotsTableId,
        rowId: slotId,
      );
    } on AppwriteException catch (error) {
      if (error.code != 404) {
        rethrow;
      }
    }
  }

  String _slotId(String stadiumId, String dayDate, String slotTime) {
    final normalizedDate = dayDate.toLowerCase().replaceAll(' ', '_');
    final normalizedTime = slotTime
        .toLowerCase()
        .replaceAll(' ', '')
        .replaceAll(':', '');
    final raw = '$stadiumId|$normalizedDate|$normalizedTime';
    return 'slot_${_shortHash(raw)}';
  }

  String _shortHash(String value) {
    var hash = 0xcbf29ce484222325;
    for (final codeUnit in value.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x100000001b3) & 0xffffffffffffffff;
    }

    return hash.toRadixString(16).padLeft(16, '0');
  }

  Set<String>? _freshCachedAvailability(String stadiumId) {
    final cached = _availabilityCache[stadiumId];
    if (cached == null || cached.isExpired(_availabilityCacheTtl)) return null;
    return Set<String>.of(cached.value);
  }

  void _appendCachedBooking(String userId, StadiumBooking booking) {
    final cached = _bookingsCache[userId];
    if (cached == null) return;

    final bookings = [
      booking,
      ...cached.value.where((item) => item.rowId != booking.rowId),
    ]..sort(_compareBookings);
    _bookingsCache[userId] = _CacheEntry(bookings);
  }

  void _removeCachedBooking(StadiumBooking booking) {
    for (final entry in _bookingsCache.entries.toList()) {
      final bookings = entry.value.value
          .where((item) => item.rowId != booking.rowId)
          .toList();
      _bookingsCache[entry.key] = _CacheEntry(bookings);
    }
  }

  void _addCachedBookedSlot(String stadiumId, String slotKey) {
    final cached = _availabilityCache[stadiumId];
    if (cached == null || cached.isExpired(_availabilityCacheTtl)) return;

    _availabilityCache[stadiumId] = _CacheEntry({...cached.value, slotKey});
  }

  void _removeCachedBookedSlot(String stadiumId, String slotKey) {
    final cached = _availabilityCache[stadiumId];
    if (cached == null || cached.isExpired(_availabilityCacheTtl)) return;

    _availabilityCache[stadiumId] = _CacheEntry(
      Set<String>.of(cached.value)..remove(slotKey),
    );
  }

  int _compareBookings(StadiumBooking a, StadiumBooking b) {
    final statusComparison = _statusRank(
      a.status,
    ).compareTo(_statusRank(b.status));
    if (statusComparison != 0) return statusComparison;

    final dayComparison = a.dayDate.compareTo(b.dayDate);
    if (dayComparison != 0) return dayComparison;
    return a.slotTime.compareTo(b.slotTime);
  }

  int _statusRank(String status) {
    return switch (status) {
      activeStatus => 0,
      pendingStatus => 1,
      deniedStatus => 2,
      cancelledStatus => 3,
      _ => 4,
    };
  }

  Future<Map<String, dynamic>> _executeBookingFunction(
    Map<String, dynamic> payload,
  ) async {
    final execution = await _functions.createExecution(
      functionId: functionId,
      body: jsonEncode(payload),
      xasync: false,
    );

    final decoded = _decodeFunctionResponse(execution.responseBody);
    if (execution.responseStatusCode == 409) {
      throw const BookingSlotUnavailableException();
    }

    if (execution.responseStatusCode < 200 ||
        execution.responseStatusCode >= 300) {
      throw BookingServiceException(
        _executionFailureMessage(execution, decoded),
      );
    }

    return decoded;
  }
}

class _CacheEntry<T> {
  _CacheEntry(this.value) : createdAt = DateTime.now();

  final T value;
  final DateTime createdAt;

  bool isExpired(Duration ttl) => DateTime.now().difference(createdAt) > ttl;
}

String bookingSlotKey(String dayDate, String slotTime) {
  return '$dayDate|$slotTime';
}

class BookingSlotUnavailableException implements Exception {
  const BookingSlotUnavailableException();
}

class BookedSlot {
  const BookedSlot({
    required this.rowId,
    required this.stadiumId,
    required this.dayDate,
    required this.slotTime,
    required this.status,
  });

  factory BookedSlot.fromRow(models.Row row) {
    final data = row.data;

    return BookedSlot(
      rowId: row.$id,
      stadiumId: data['stadiumId'].toString(),
      dayDate: data['dayDate'].toString(),
      slotTime: data['slotTime'].toString(),
      status: data['status'].toString(),
    );
  }

  final String rowId;
  final String stadiumId;
  final String dayDate;
  final String slotTime;
  final String status;

  String get slotKey => bookingSlotKey(dayDate, slotTime);
}

abstract class ManagerBookingRequestsRepository {
  Future<List<StadiumBooking>> listPendingRequests(String managerId);

  Future<StadiumBooking> acceptRequest({
    required String managerId,
    required StadiumBooking request,
  });

  Future<void> denyRequest({
    required String managerId,
    required StadiumBooking request,
  });
}

class ManagerBookingRequestsService
    implements ManagerBookingRequestsRepository {
  ManagerBookingRequestsService(this._tables, this._functions);

  final TablesDB _tables;
  final Functions _functions;

  @override
  Future<List<StadiumBooking>> listPendingRequests(String managerId) async {
    final rows = await _tables.listRows(
      databaseId: BookingService.databaseId,
      tableId: BookingService.tableId,
      queries: [
        Query.equal('stadiumId', managerId),
        Query.equal('status', BookingService.pendingStatus),
        Query.orderAsc('dayDate'),
        Query.orderAsc('slotTime'),
      ],
    );

    return rows.rows.map(StadiumBooking.fromRow).toList();
  }

  @override
  Future<StadiumBooking> acceptRequest({
    required String managerId,
    required StadiumBooking request,
  }) async {
    if (request.status != BookingService.pendingStatus) {
      return request;
    }

    final payload = await _executeBookingFunction({
      'action': 'acceptBookingRequest',
      'userId': managerId,
      'requestId': request.rowId,
    });
    return StadiumBooking.fromMap(_bookingPayload(payload));
  }

  @override
  Future<void> denyRequest({
    required String managerId,
    required StadiumBooking request,
  }) async {
    if (request.stadiumId != managerId) {
      throw StateError('Managers can only update requests for their stadium.');
    }

    await _executeBookingFunction({
      'action': 'denyBookingRequest',
      'userId': managerId,
      'requestId': request.rowId,
    });
  }

  Future<Map<String, dynamic>> _executeBookingFunction(
    Map<String, dynamic> payload,
  ) async {
    final execution = await _functions.createExecution(
      functionId: BookingService.functionId,
      body: jsonEncode(payload),
      xasync: false,
    );

    final decoded = _decodeFunctionResponse(execution.responseBody);
    if (execution.responseStatusCode == 409) {
      throw const BookingSlotUnavailableException();
    }

    if (execution.responseStatusCode < 200 ||
        execution.responseStatusCode >= 300) {
      throw BookingServiceException(
        _executionFailureMessage(execution, decoded),
      );
    }

    return decoded;
  }
}

Map<String, dynamic> _decodeFunctionResponse(String responseBody) {
  if (responseBody.isEmpty) return const {};

  try {
    final decoded = jsonDecode(responseBody);
    if (decoded is Map<String, dynamic>) return decoded;
  } catch (_) {
    return {'error': responseBody};
  }

  return {'error': responseBody};
}

Map<String, dynamic> _bookingPayload(Map<String, dynamic> payload) {
  final booking = payload['booking'];
  if (booking is Map<String, dynamic>) return booking;

  throw const BookingServiceException('Booking response is missing data.');
}

String? _errorMessage(Map<String, dynamic> payload) {
  final error = payload['error'];
  return error?.toString();
}

String _executionFailureMessage(
  models.Execution execution,
  Map<String, dynamic> decoded,
) {
  final parts = <String>[
    _errorMessage(decoded) ?? 'Booking action failed.',
    'status=${execution.status.value}',
    'http=${execution.responseStatusCode}',
  ];

  if (execution.responseBody.trim().isNotEmpty) {
    parts.add('body=${execution.responseBody}');
  }

  if (execution.errors.trim().isNotEmpty) {
    parts.add('errors=${execution.errors}');
  }

  return parts.join(' | ');
}

class BookingServiceException implements Exception {
  const BookingServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class StadiumBooking {
  const StadiumBooking({
    required this.rowId,
    required this.userId,
    required this.userName,
    required this.stadiumId,
    required this.slotId,
    required this.stadiumName,
    required this.location,
    required this.rating,
    required this.price,
    required this.iconKey,
    required this.dayLabel,
    required this.dayDate,
    required this.slotTime,
    required this.status,
  });

  factory StadiumBooking.fromRow(models.Row row) {
    return StadiumBooking.fromMap({'\$id': row.$id, ...row.data});
  }

  factory StadiumBooking.fromMap(Map<String, dynamic> data) {
    return StadiumBooking(
      rowId: data['\$id']?.toString() ?? data['id']?.toString() ?? '',
      userId: data['userId'].toString(),
      userName: data['userName']?.toString() ?? 'Unknown User',
      stadiumId: data['stadiumId'].toString(),
      slotId: data['slotId'].toString(),
      stadiumName: data['stadiumName'].toString(),
      location: data['location'].toString(),
      rating: (data['rating'] as num).toDouble(),
      price: (data['price'] as num).toInt(),
      iconKey: data['icon'].toString(),
      dayLabel: data['dayLabel'].toString(),
      dayDate: data['dayDate'].toString(),
      slotTime: data['slotTime'].toString(),
      status: data['status'].toString(),
    );
  }

  final String rowId;
  final String userId;
  final String userName;
  final String stadiumId;
  final String slotId;
  final String stadiumName;
  final String location;
  final double rating;
  final int price;
  final String iconKey;
  final String dayLabel;
  final String dayDate;
  final String slotTime;
  final String status;

  IconData get icon => stadiumIconFromKey(iconKey);

  String get slotKey => bookingSlotKey(dayDate, slotTime);
}

final BookingsRepository bookingService = BookingService(
  TablesDB(client),
  Functions(client),
);
final ManagerBookingRequestsRepository managerBookingRequestsService =
    ManagerBookingRequestsService(TablesDB(client), Functions(client));
