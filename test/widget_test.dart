import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stadium/app.dart';

void main() {
  testWidgets('Stadium home page shows booking content', (tester) async {
    await tester.pumpWidget(const StadiumBookingApp());

    expect(find.text('Book your next football pitch'), findsOneWidget);
    expect(find.text('Featured stadium'), findsOneWidget);
    expect(find.text('Emerald Arena'), findsWidgets);
    expect(find.text('Book now'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Bookings'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
  });

  testWidgets('Bottom navigation switches pages', (tester) async {
    await tester.pumpWidget(const StadiumBookingApp());

    await tester.tap(find.text('Bookings'));
    await tester.pumpAndSettle();
    expect(find.text('My Bookings'), findsOneWidget);
    expect(find.text('Active bookings'), findsOneWidget);
    expect(find.text('Hearted'), findsOneWidget);
    await tester.tap(find.text('Hearted'));
    await tester.pumpAndSettle();
    expect(find.text('Northside Pitch'), findsOneWidget);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Personal details'), findsOneWidget);
  });

  testWidgets('Book now opens stadium booking slots', (tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const StadiumBookingApp());

    await tester.tap(find.text('Book now'));
    await tester.pumpAndSettle();

    expect(find.text('Choose a day'), findsOneWidget);
    expect(find.text('Downtown District'), findsWidgets);
    expect(find.text('View on map'), findsOneWidget);
    expect(find.text('Available times'), findsOneWidget);
    expect(find.text('7:00 PM'), findsOneWidget);
    expect(find.text('Booked'), findsAtLeastNWidgets(1));
    await tester.dragUntilVisible(
      find.text('Select a time'),
      find.byType(Scrollable).last,
      const Offset(0, -120),
    );
    expect(find.text('Select a time'), findsOneWidget);
  });
}
