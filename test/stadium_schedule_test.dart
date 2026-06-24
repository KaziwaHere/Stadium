import 'package:flutter_test/flutter_test.dart';
import 'package:stadium/src/utils/stadium_schedule.dart';

void main() {
  test('buildBookingDays creates a six-day local schedule', () {
    final days = buildBookingDays(now: DateTime(2026, 6, 24, 17, 0));

    expect(days, hasLength(6));
    expect(days.first.label, 'Today');
    expect(days.first.date, '2026-06-24');
    expect(days[1].label, 'Tomorrow');
    expect(days[1].date, '2026-06-25');
    expect(days.last.date, '2026-06-29');
    expect(days.first.slots, hasLength(24));
    expect(days.first.slots.first.time, '12:00 AM');
    expect(days.first.slots[6].time, '6:00 AM');
    expect(days.first.slots[12].time, '12:00 PM');
    expect(days.first.slots.last.time, '11:00 PM');
  });

  test('bookingSlotHasPassed follows the current local time', () {
    final day = buildBookingDays(now: DateTime(2026, 6, 24, 17, 0)).first;
    final sixPmSlot = day.slots[18];

    expect(
      bookingSlotHasPassed(day, sixPmSlot, now: DateTime(2026, 6, 24, 17, 59)),
      isFalse,
    );
    expect(
      bookingSlotHasPassed(day, sixPmSlot, now: DateTime(2026, 6, 24, 18, 0)),
      isTrue,
    );
  });

  test('nextAvailabilityLabel skips times that have already passed', () {
    expect(
      nextAvailabilityLabel(now: DateTime(2026, 6, 24, 20, 0)),
      'Today, 9:00 PM',
    );
    expect(
      nextAvailabilityLabel(now: DateTime(2026, 6, 24, 23, 0)),
      'Tomorrow, 12:00 AM',
    );
  });
}
