import 'dart:async';
import 'dart:convert';

import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:flutter/material.dart';
import 'package:stadium/src/appwrite_client.dart';
import 'package:stadium/src/models/stadium.dart';
import 'package:stadium/src/utils/stadium_schedule.dart';

const _firstBookingSlotStartMinutes = 16 * 60;

abstract class BookingsRepository {
  Future<List<StadiumBooking>> listBookings(String userId);

  Future<List<StadiumBooking>> listBookingHistory(String userId);

  Future<List<BookedSlot>> bookedSlots(String stadiumId);

  Future<Set<String>> bookedSlotKeys(String stadiumId);

  Future<StadiumBooking> createBooking({
    required String userId,
    required String userName,
    required Stadium stadium,
    required BookingDay day,
    required BookingSlot slot,
  });

  Future<void> markSlotBookedByManager({
    required String managerId,
    required Stadium stadium,
    required BookingDay day,
    required BookingSlot slot,
  });

  Future<void> unmarkSlotBookedByManager({
    required String managerId,
    required Stadium stadium,
    required BookingDay day,
    required BookingSlot slot,
  });

  Future<void> cancelBooking({required StadiumBooking booking});
}

abstract class RealtimeBookingsRepository {
  Stream<void> watchBookings(String userId);

  Stream<void> watchBookedSlots(String stadiumId);
}

class BookingService implements BookingsRepository, RealtimeBookingsRepository {
  BookingService(this._tables, this._functions, [this._realtime]);

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
  final Realtime? _realtime;
  final Map<String, _CacheEntry<List<StadiumBooking>>> _bookingsCache = {};
  final Map<String, Future<List<StadiumBooking>>> _bookingsRequests = {};
  final Map<String, _CacheEntry<Set<String>>> _availabilityCache = {};
  final Map<String, Future<Set<String>>> _availabilityRequests = {};

  @override
  Future<List<StadiumBooking>> listBookings(String userId) async {
    final cached = _bookingsCache[userId];
    if (cached != null) {
      unawaited(_refreshBookingsInBackground(userId));
      final now = DateTime.now();
      return List<StadiumBooking>.unmodifiable(
        cached.value
            .where((booking) => booking.belongsInCurrentBookings(now: now))
            .toList(),
      );
    }

    return _refreshBookings(userId);
  }

  @override
  Stream<void> watchBookings(String userId) {
    return _watchTable(tableId, onEvent: () => _bookingsCache.remove(userId));
  }

  @override
  Stream<void> watchBookedSlots(String stadiumId) {
    return _watchTable(
      bookedSlotsTableId,
      onEvent: () => _availabilityCache.remove(stadiumId),
    );
  }

  Stream<void> _watchTable(
    String watchedTableId, {
    required void Function() onEvent,
  }) {
    final realtime = _realtime;
    if (realtime == null) return const Stream<void>.empty();

    late final RealtimeSubscription subscription;
    late final StreamController<void> controller;
    controller = StreamController<void>(
      onListen: () {
        subscription = realtime.subscribe([
          Channel.tablesdb(databaseId).table(watchedTableId).row(),
        ]);
        subscription.stream.listen((_) {
          onEvent();
          controller.add(null);
        }, onError: controller.addError);
      },
      onCancel: () => subscription.close(),
    );
    return controller.stream;
  }

  Future<List<StadiumBooking>> _refreshBookings(String userId) async {
    final existingRequest = _bookingsRequests[userId];
    if (existingRequest != null) return existingRequest;

    final request = _fetchBookings(userId);
    _bookingsRequests[userId] = request;

    try {
      final fetchedBookings = await request;
      final optimisticBookings =
          _bookingsCache[userId]?.value.where(
            (booking) => booking.rowId.startsWith('local_'),
          ) ??
          const Iterable<StadiumBooking>.empty();
      final bookings = [
        ...fetchedBookings,
        ...optimisticBookings.where(
          (optimistic) => !fetchedBookings.any(
            (fetched) => fetched.slotKey == optimistic.slotKey,
          ),
        ),
      ]..sort(_compareBookings);
      _bookingsCache[userId] = _CacheEntry(bookings);
      return List<StadiumBooking>.unmodifiable(bookings);
    } finally {
      _bookingsRequests.remove(userId);
    }
  }

  Future<void> _refreshBookingsInBackground(String userId) async {
    try {
      await _refreshBookings(userId);
    } catch (_) {
      // Keep showing the last known data when a background refresh fails.
    }
  }

  Future<List<StadiumBooking>> _fetchBookings(String userId) async {
    final bookings = await _fetchBookingsByStatuses(userId, const [
      activeStatus,
      pendingStatus,
      deniedStatus,
      cancelledStatus,
    ]);
    final now = DateTime.now();
    return bookings
        .where((booking) => booking.belongsInCurrentBookings(now: now))
        .toList();
  }

  @override
  Future<List<StadiumBooking>> listBookingHistory(String userId) async {
    final bookings = await _fetchBookingsByStatuses(userId, const [
      activeStatus,
      pendingStatus,
      deniedStatus,
      cancelledStatus,
    ]);
    final now = DateTime.now();
    return bookings
        .where((booking) => booking.belongsInHistory(now: now))
        .toList();
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

  @override
  Future<List<BookedSlot>> bookedSlots(String stadiumId) async {
    return _fetchBookedSlots(stadiumId);
  }

  Future<Set<String>> _fetchBookedSlotKeys(String stadiumId) async {
    final slots = await _fetchBookedSlots(stadiumId);
    return slots.map((slot) => slot.slotKey).toSet();
  }

  Future<List<BookedSlot>> _fetchBookedSlots(String stadiumId) async {
    final rows = await _tables.listRows(
      databaseId: databaseId,
      tableId: bookedSlotsTableId,
      queries: [
        Query.equal('stadiumId', stadiumId),
        Query.equal('status', [activeStatus, pendingStatus]),
        Query.limit(100),
      ],
    );

    return rows.rows.map(BookedSlot.fromRow).toList();
  }

  @override
  Future<StadiumBooking> createBooking({
    required String userId,
    required String userName,
    required Stadium stadium,
    required BookingDay day,
    required BookingSlot slot,
  }) async {
    if (bookingSlotHasPassed(day, slot)) {
      throw const BookingSlotExpiredException();
    }

    final slotId = _slotId(stadium.id, day.date, slot.time);
    final optimisticBooking = StadiumBooking(
      rowId: 'local_$slotId',
      userId: userId,
      userName: userName,
      stadiumId: stadium.id,
      slotId: slotId,
      stadiumName: stadium.name,
      location: stadium.location,
      rating: stadium.rating,
      price: stadium.price,
      iconKey: stadium.iconKey,
      imageFileId: stadium.imageFileId,
      dayLabel: day.label,
      dayDate: day.date,
      slotTime: slot.time,
      status: pendingStatus,
      statusChangedAt: DateTime.now(),
    );
    _appendCachedBooking(userId, optimisticBooking);
    _addCachedBookedSlot(stadium.id, optimisticBooking.slotKey);

    try {
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
        if (stadium.imageFileId != null) 'imageFileId': stadium.imageFileId,
        'dayLabel': day.label,
        'dayDate': day.date,
        'slotTime': slot.time,
      });
      final booking = StadiumBooking.fromMap(_bookingPayload(payload));
      _appendCachedBooking(userId, booking);
      if (booking.status != activeStatus && booking.status != pendingStatus) {
        _removeCachedBookedSlot(stadium.id, booking.slotKey);
      }
      return booking;
    } catch (_) {
      _removeCachedBooking(optimisticBooking);
      _removeCachedBookedSlot(stadium.id, optimisticBooking.slotKey);
      rethrow;
    }
  }

  @override
  Future<void> markSlotBookedByManager({
    required String managerId,
    required Stadium stadium,
    required BookingDay day,
    required BookingSlot slot,
  }) async {
    if (bookingSlotHasPassed(day, slot)) {
      throw const BookingSlotExpiredException();
    }

    final slotId = _slotId(stadium.id, day.date, slot.time);
    await _executeBookingFunction({
      'action': 'managerBlockSlot',
      'userId': managerId,
      'stadiumId': stadium.id,
      'slotId': slotId,
      'dayDate': day.date,
      'slotTime': slot.time,
    });
    _addCachedBookedSlot(stadium.id, bookingSlotKey(day.date, slot.time));
  }

  @override
  Future<void> unmarkSlotBookedByManager({
    required String managerId,
    required Stadium stadium,
    required BookingDay day,
    required BookingSlot slot,
  }) async {
    final slotId = _slotId(stadium.id, day.date, slot.time);
    await _executeBookingFunction({
      'action': 'managerUnblockSlot',
      'userId': managerId,
      'stadiumId': stadium.id,
      'slotId': slotId,
      'dayDate': day.date,
      'slotTime': slot.time,
    });
    _removeCachedBookedSlot(stadium.id, bookingSlotKey(day.date, slot.time));
  }

  @override
  Future<void> cancelBooking({required StadiumBooking booking}) async {
    await _executeBookingFunction({
      'action': 'cancelBookingRequest',
      'userId': booking.userId,
      'requestId': booking.rowId,
    });
    _removeCachedBooking(booking);
    _removeCachedBookedSlot(booking.stadiumId, booking.slotKey);
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

  void _appendCachedBooking(String userId, StadiumBooking booking) {
    final cached = _bookingsCache[userId];
    final bookings = [
      booking,
      ...?cached?.value.where(
        (item) =>
            item.rowId != booking.rowId && item.slotKey != booking.slotKey,
      ),
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
    _availabilityCache[stadiumId] = _CacheEntry({...?cached?.value, slotKey});
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

class BookingSlotExpiredException implements Exception {
  const BookingSlotExpiredException();
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

  Future<List<StadiumBooking>> listRequestHistory(String managerId);

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
  Future<List<StadiumBooking>> listRequestHistory(String managerId) async {
    final rows = await _tables.listRows(
      databaseId: BookingService.databaseId,
      tableId: BookingService.tableId,
      queries: [
        Query.equal('stadiumId', managerId),
        Query.equal('status', const [
          BookingService.activeStatus,
          BookingService.pendingStatus,
          BookingService.deniedStatus,
        ]),
        Query.orderDesc('dayDate'),
        Query.orderDesc('slotTime'),
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
    this.imageFileId,
    required this.dayLabel,
    required this.dayDate,
    required this.slotTime,
    required this.status,
    this.statusChangedAt,
  });

  factory StadiumBooking.fromRow(models.Row row) {
    return StadiumBooking.fromMap({
      '\$id': row.$id,
      '\$updatedAt': row.$updatedAt,
      ...row.data,
    });
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
      imageFileId: _optionalBookingImageFileId(data['imageFileId']),
      dayLabel: data['dayLabel'].toString(),
      dayDate: data['dayDate'].toString(),
      slotTime: data['slotTime'].toString(),
      status: data['status'].toString(),
      statusChangedAt: _parseServerDate(data[r'$updatedAt']),
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
  final String? imageFileId;
  final String dayLabel;
  final String dayDate;
  final String slotTime;
  final String status;
  final DateTime? statusChangedAt;

  IconData get icon => stadiumIconFromKey(iconKey);

  String get slotKey => bookingSlotKey(dayDate, slotTime);

  DateTime? get date => _parseBookingDate(dayDate);

  DateTime? get startsAt {
    final bookingDate = date;
    final minutes = _parseBookingTime(slotTime);
    if (bookingDate == null || minutes == null) return null;

    final slotDate = minutes < _firstBookingSlotStartMinutes
        ? bookingDate.add(const Duration(days: 1))
        : bookingDate;

    return DateTime(
      slotDate.year,
      slotDate.month,
      slotDate.day,
      minutes ~/ 60,
      minutes % 60,
    );
  }

  DateTime? get endsAt {
    final start = startsAt;
    if (start == null) return null;
    return start.add(const Duration(hours: 1));
  }

  bool isToday({DateTime? now}) {
    final bookingDate = date;
    if (bookingDate == null) return false;

    return _isSameDate(bookingDate, now ?? DateTime.now());
  }

  bool isBeforeToday({DateTime? now}) {
    final bookingDate = date;
    if (bookingDate == null) return false;

    return bookingDate.isBefore(_startOfDay(now ?? DateTime.now()));
  }

  bool isOver({DateTime? now}) {
    final slotEndsAt = endsAt;
    if (slotEndsAt == null) return false;

    return !slotEndsAt.isAfter(now ?? DateTime.now());
  }

  bool belongsInCurrentBookings({DateTime? now}) {
    final currentTime = now ?? DateTime.now();
    if (_isTerminalStatus) return statusChangedToday(now: currentTime);
    if (isToday(now: currentTime)) return true;
    if (status == BookingService.pendingStatus) return true;
    return status == BookingService.activeStatus &&
        !isBeforeToday(now: currentTime);
  }

  bool belongsInHistory({DateTime? now}) {
    final currentTime = now ?? DateTime.now();
    if (_isTerminalStatus) return !statusChangedToday(now: currentTime);
    return status == BookingService.activeStatus &&
        isBeforeToday(now: currentTime);
  }

  bool statusChangedToday({DateTime? now}) {
    final currentTime = now ?? DateTime.now();
    final changedAt = statusChangedAt?.toLocal();
    if (changedAt == null) return isToday(now: currentTime);
    return _isSameDate(changedAt, currentTime);
  }

  bool get _isTerminalStatus =>
      status == BookingService.deniedStatus ||
      status == BookingService.cancelledStatus;
}

String? _optionalBookingImageFileId(dynamic value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

DateTime? _parseServerDate(dynamic value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) return null;
  return DateTime.tryParse(text);
}

DateTime _startOfDay(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

bool _isSameDate(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

DateTime? _parseBookingDate(String value) {
  final parts = value.split('-');
  if (parts.length != 3) return null;

  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) return null;

  return DateTime(year, month, day);
}

int? _parseBookingTime(String value) {
  final match = RegExp(
    r'^(\d{1,2}):(\d{2})\s*(AM|PM)$',
    caseSensitive: false,
  ).firstMatch(value.trim());
  if (match == null) return null;

  var hour = int.tryParse(match.group(1)!);
  final minute = int.tryParse(match.group(2)!);
  final period = match.group(3)!.toUpperCase();
  if (hour == null || minute == null) return null;
  if (hour < 1 || hour > 12 || minute < 0 || minute > 59) return null;

  if (period == 'AM' && hour == 12) hour = 0;
  if (period == 'PM' && hour != 12) hour += 12;

  return hour * 60 + minute;
}

final BookingsRepository bookingService = BookingService(
  TablesDB(client),
  Functions(client),
  Realtime(client),
);
final ManagerBookingRequestsRepository managerBookingRequestsService =
    ManagerBookingRequestsService(TablesDB(client), Functions(client));
