import 'package:flutter_test/flutter_test.dart';
import 'package:stadium/src/services/booking_service.dart';

void main() {
  test('cancelled booking remains current on cancellation day', () {
    final booking = _booking(
      bookingDate: '2027-01-15',
      statusChangedAt: DateTime(2026, 6, 30, 9, 45),
    );
    final laterThatDay = DateTime(2026, 6, 30, 23, 59);

    expect(booking.belongsInCurrentBookings(now: laterThatDay), isTrue);
    expect(booking.belongsInHistory(now: laterThatDay), isFalse);
  });

  test('cancelled booking moves to history the next calendar day', () {
    final booking = _booking(
      bookingDate: '2027-01-15',
      statusChangedAt: DateTime(2026, 6, 30, 23, 59),
    );
    final nextDay = DateTime(2026, 7, 1);

    expect(booking.belongsInCurrentBookings(now: nextDay), isFalse);
    expect(booking.belongsInHistory(now: nextDay), isTrue);
  });

  test('scheduled date does not override an older cancellation action', () {
    final booking = _booking(
      bookingDate: '2026-07-01',
      statusChangedAt: DateTime(2026, 6, 30, 18),
    );
    final bookingDay = DateTime(2026, 7, 1, 8);

    expect(booking.belongsInCurrentBookings(now: bookingDay), isFalse);
    expect(booking.belongsInHistory(now: bookingDay), isTrue);
  });
}

StadiumBooking _booking({
  required String bookingDate,
  required DateTime statusChangedAt,
}) {
  return StadiumBooking(
    rowId: 'booking',
    userId: 'user',
    userName: 'User',
    stadiumId: 'stadium',
    slotId: 'slot',
    stadiumName: 'Stadium',
    location: 'Location',
    rating: 4.5,
    price: 50,
    iconKey: 'stadium',
    dayLabel: 'Day',
    dayDate: bookingDate,
    slotTime: '7:00 PM',
    status: BookingService.cancelledStatus,
    statusChangedAt: statusChangedAt,
  );
}
