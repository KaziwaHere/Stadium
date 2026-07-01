import 'package:flutter_test/flutter_test.dart';
import 'package:stadium/src/services/admin_service.dart';

void main() {
  test('stadium booking statistics parse approved booking details', () {
    final stadium = AdminStadiumBookingStats.fromMap({
      'id': 'stadium_1',
      'name': 'Arena One',
      'location': 'Baghdad',
      'price': 100,
      'isFeatured': true,
      'bookingCount': 1,
      'bookings': [
        {
          'id': 'booking_1',
          'userId': 'user_1',
          'userName': 'Hana',
          'dayDate': '2026-07-03',
          'slotTime': '7:00 PM',
          'price': 100,
        },
      ],
    });

    expect(stadium.name, 'Arena One');
    expect(stadium.bookingCount, 1);
    expect(stadium.isFeatured, isTrue);
    expect(stadium.bookings.single.userName, 'Hana');
    expect(stadium.bookings.single.dayDate, '2026-07-03');
  });

  test('weekly report charges 3 percent only for completed bookings', () {
    final stadium = AdminStadiumBookingStats.fromMap({
      'id': 'stadium_1',
      'name': 'Arena One',
      'location': 'Baghdad',
      'price': 100,
      'bookings': [
        {
          'id': 'done',
          'userId': 'user_1',
          'dayDate': '2026-06-29',
          'slotTime': '7:00 PM',
          'price': 100,
        },
        {
          'id': 'upcoming',
          'userId': 'user_2',
          'dayDate': '2026-07-03',
          'slotTime': '7:00 PM',
          'price': 200,
        },
      ],
    });

    final report = stadium.weeklyReport(now: DateTime(2026, 7, 1));
    expect(report.approvedBookings, 2);
    expect(report.completedBookings, 1);
    expect(report.upcomingBookings, 1);
    expect(report.grossRevenue, 100);
    expect(report.adminCommission, 3);
  });
}
