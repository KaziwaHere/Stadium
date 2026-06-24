import 'package:stadium/src/models/stadium.dart';

const bookingWindowDays = 6;
const _firstSlotStartMinutes = 16 * 60;
const _lastSlotStartMinutes = 24 * 60;

final _slotStartMinutes = List<int>.generate(
  ((_lastSlotStartMinutes - _firstSlotStartMinutes) ~/ 60) + 1,
  (index) => _firstSlotStartMinutes + (index * 60),
);

List<BookingDay> buildBookingDays({
  DateTime? now,
  int dayCount = bookingWindowDays,
}) {
  final localNow = now ?? DateTime.now();
  final today = DateTime(localNow.year, localNow.month, localNow.day);

  return List<BookingDay>.generate(dayCount, (index) {
    final date = today.add(Duration(days: index));

    return BookingDay(
      label: _dayLabel(index, date),
      date: _formatDate(date),
      slots: [
        for (final minutes in _slotStartMinutes)
          BookingSlot(time: _formatTime(minutes), isBooked: false),
      ],
    );
  });
}

String nextAvailabilityLabel({DateTime? now}) {
  final localNow = now ?? DateTime.now();
  for (final day in buildBookingDays(now: localNow)) {
    for (final slot in day.slots) {
      final startsAt = bookingSlotStartsAt(day, slot);
      if (startsAt != null && startsAt.isAfter(localNow)) {
        return '${day.label}, ${slot.time}';
      }
    }
  }

  return 'Available soon';
}

bool bookingSlotHasPassed(BookingDay day, BookingSlot slot, {DateTime? now}) {
  final startsAt = bookingSlotStartsAt(day, slot);
  if (startsAt == null) return false;

  return !startsAt.isAfter(now ?? DateTime.now());
}

DateTime? bookingSlotStartsAt(BookingDay day, BookingSlot slot) {
  final date = _parseDate(day.date);
  final minutes = _parseTime(slot.time);
  if (date == null || minutes == null) return null;

  final slotDate = minutes < _firstSlotStartMinutes
      ? date.add(const Duration(days: 1))
      : date;
  return DateTime(
    slotDate.year,
    slotDate.month,
    slotDate.day,
    minutes ~/ 60,
    minutes % 60,
  );
}

DateTime? _parseDate(String value) {
  final parts = value.split('-');
  if (parts.length != 3) return null;

  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) return null;

  return DateTime(year, month, day);
}

int? _parseTime(String value) {
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

String _dayLabel(int index, DateTime date) {
  if (index == 0) return 'Today';
  if (index == 1) return 'Tomorrow';

  return switch (date.weekday) {
    DateTime.monday => 'Monday',
    DateTime.tuesday => 'Tuesday',
    DateTime.wednesday => 'Wednesday',
    DateTime.thursday => 'Thursday',
    DateTime.friday => 'Friday',
    DateTime.saturday => 'Saturday',
    DateTime.sunday => 'Sunday',
    _ => 'Later',
  };
}

String _formatDate(DateTime date) {
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

String _formatTime(int minutes) {
  final normalizedMinutes = minutes % (24 * 60);
  final hour24 = normalizedMinutes ~/ 60;
  final minute = normalizedMinutes % 60;
  final period = hour24 >= 12 ? 'PM' : 'AM';
  final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;

  return '$hour12:${minute.toString().padLeft(2, '0')} $period';
}
