import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:flutter/material.dart';
import 'package:stadium/src/appwrite_client.dart';
import 'package:stadium/src/models/stadium.dart';

abstract class BookingsRepository {
  Future<List<StadiumBooking>> listBookings(String userId);

  Future<Set<String>> bookedSlotKeys(String stadiumId);

  Future<StadiumBooking> createBooking({
    required String userId,
    required Stadium stadium,
    required BookingDay day,
    required BookingSlot slot,
  });

  Future<void> cancelBooking({required StadiumBooking booking});
}

class BookingService implements BookingsRepository {
  BookingService(this._tables);

  static const databaseId = 'stadium_booking';
  static const tableId = 'bookings';
  static const bookedSlotsTableId = 'booked_slots';
  static const activeStatus = 'active';
  static const cancelledStatus = 'cancelled';
  static const _bookingsCacheTtl = Duration(minutes: 3);
  static const _availabilityCacheTtl = Duration(seconds: 45);

  final TablesDB _tables;
  final Map<String, _CacheEntry<List<StadiumBooking>>> _bookingsCache = {};
  final Map<String, Future<List<StadiumBooking>>> _bookingsRequests = {};
  final Map<String, _CacheEntry<Set<String>>> _availabilityCache = {};
  final Map<String, Future<Set<String>>> _availabilityRequests = {};

  @override
  Future<List<StadiumBooking>> listBookings(String userId) async {
    final cached = _freshCachedBookings(userId);
    if (cached != null) return cached;

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
    final rows = await _tables.listRows(
      databaseId: databaseId,
      tableId: tableId,
      queries: [
        Query.equal('userId', userId),
        Query.equal('status', activeStatus),
        Query.orderAsc('dayDate'),
        Query.orderAsc('slotTime'),
      ],
    );

    return rows.rows.map(StadiumBooking.fromRow).toList();
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
        Query.equal('status', activeStatus),
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
    required Stadium stadium,
    required BookingDay day,
    required BookingSlot slot,
  }) async {
    final slotId = _slotId(stadium.id, day.date, slot.time);

    await _createBookedSlotMarker(
      userId: userId,
      slotId: slotId,
      stadiumId: stadium.id,
      dayDate: day.date,
      slotTime: slot.time,
    );

    try {
      final row = await _tables.createRow(
        databaseId: databaseId,
        tableId: tableId,
        rowId: ID.unique(),
        data: {
          'userId': userId,
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
          'status': activeStatus,
          'createdAt': DateTime.now().toUtc().toIso8601String(),
        },
        permissions: [
          Permission.read(Role.user(userId)),
          Permission.update(Role.user(userId)),
          Permission.delete(Role.user(userId)),
        ],
      );

      final booking = StadiumBooking.fromRow(row);
      _appendCachedBooking(userId, booking);
      _addCachedBookedSlot(stadium.id, booking.slotKey);
      return booking;
    } catch (_) {
      await _deleteBookedSlotMarker(slotId);
      rethrow;
    }
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

  Future<void> _createBookedSlotMarker({
    required String userId,
    required String slotId,
    required String stadiumId,
    required String dayDate,
    required String slotTime,
  }) async {
    try {
      await _tables.createRow(
        databaseId: databaseId,
        tableId: bookedSlotsTableId,
        rowId: slotId,
        data: {
          'stadiumId': stadiumId,
          'dayDate': dayDate,
          'slotTime': slotTime,
          'status': activeStatus,
        },
        permissions: [
          Permission.read(Role.users()),
          Permission.update(Role.user(userId)),
          Permission.delete(Role.user(userId)),
        ],
      );
    } on AppwriteException catch (error) {
      if (error.code == 409) {
        throw const BookingSlotUnavailableException();
      }

      rethrow;
    }
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
    return '$stadiumId-$normalizedDate-$normalizedTime';
  }

  List<StadiumBooking>? _freshCachedBookings(String userId) {
    final cached = _bookingsCache[userId];
    if (cached == null || cached.isExpired(_bookingsCacheTtl)) return null;
    return List<StadiumBooking>.of(cached.value);
  }

  Set<String>? _freshCachedAvailability(String stadiumId) {
    final cached = _availabilityCache[stadiumId];
    if (cached == null || cached.isExpired(_availabilityCacheTtl)) return null;
    return Set<String>.of(cached.value);
  }

  void _appendCachedBooking(String userId, StadiumBooking booking) {
    final cached = _bookingsCache[userId];
    if (cached == null || cached.isExpired(_bookingsCacheTtl)) return;

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
    final dayComparison = a.dayDate.compareTo(b.dayDate);
    if (dayComparison != 0) return dayComparison;
    return a.slotTime.compareTo(b.slotTime);
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

class StadiumBooking {
  const StadiumBooking({
    required this.rowId,
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
    final data = row.data;

    return StadiumBooking(
      rowId: row.$id,
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

final BookingsRepository bookingService = BookingService(TablesDB(client));
