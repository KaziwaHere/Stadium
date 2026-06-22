import 'package:appwrite/models.dart' as models;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stadium/src/data/stadium_data.dart';
import 'package:stadium/src/models/stadium.dart';
import 'package:stadium/src/screens/auth_page.dart';
import 'package:stadium/src/screens/main_navigation_page.dart';
import 'package:stadium/src/services/booking_service.dart';
import 'package:stadium/src/services/favorite_service.dart';
import 'package:stadium/src/theme/app_theme.dart';

void main() {
  testWidgets('Auth page shows login and register modes', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: AuthPage(onAuthenticated: (_) {}),
      ),
    );

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
    expect(find.text('Register'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);

    await tester.tap(find.text('Register'));
    await tester.pumpAndSettle();

    expect(find.text('Create your account'), findsOneWidget);
    expect(find.text('Full name'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
    expect(find.text('Forgot password?'), findsNothing);
  });

  testWidgets('Auth validation updates on blur and while typing', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: AuthPage(onAuthenticated: (_) {}),
      ),
    );

    final emailField = find.byType(TextFormField).first;
    final passwordField = find.byType(TextFormField).at(1);

    await tester.tap(emailField);
    await tester.pump();
    await tester.tap(passwordField);
    await tester.pump();

    expect(find.text('Enter a valid email'), findsOneWidget);

    await tester.enterText(emailField, 'hana@example.com');
    await tester.pump();

    expect(find.text('Enter a valid email'), findsNothing);
  });

  testWidgets('Stadium home page shows booking content', (tester) async {
    await tester.pumpWidget(_TestApp(home: _navigationPage()));

    expect(find.text('Featured stadium'), findsOneWidget);
    expect(find.text('Emerald Arena'), findsWidgets);
    expect(find.text('Book now'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Bookings'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
  });

  testWidgets('Bottom navigation switches pages', (tester) async {
    await tester.pumpWidget(_TestApp(home: _navigationPage()));

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
    expect(find.text('hana@example.com'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
  });

  testWidgets('Book now opens stadium booking slots', (tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(_TestApp(home: _navigationPage()));

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

class _TestApp extends StatelessWidget {
  const _TestApp({required this.home});

  final Widget home;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(theme: AppTheme.dark(), home: home);
  }
}

MainNavigationPage _navigationPage() {
  return MainNavigationPage(
    user: _user(),
    bookingsRepository: _FakeBookingsRepository(),
    favoritesRepository: _FakeFavoritesRepository(),
    onSignedOut: () {},
  );
}

models.User _user() {
  return models.User(
    $id: 'user_1',
    $createdAt: '2026-06-16T00:00:00.000+00:00',
    $updatedAt: '2026-06-16T00:00:00.000+00:00',
    name: 'Hana',
    registration: '2026-06-16T00:00:00.000+00:00',
    status: true,
    labels: const [],
    passwordUpdate: '',
    email: 'hana@example.com',
    phone: '',
    emailVerification: false,
    phoneVerification: false,
    mfa: false,
    prefs: models.Preferences(data: const {}),
    targets: const [],
    accessedAt: '2026-06-16T00:00:00.000+00:00',
  );
}

class _FakeBookingsRepository implements BookingsRepository {
  _FakeBookingsRepository()
    : _bookings = [
        StadiumBooking(
          rowId: 'booking_1',
          userId: 'test_user_id',
          userName: 'Test User',
          stadiumId: stadiums.first.id,
          slotId: 'emerald_arena-jun_13-700pm',
          stadiumName: stadiums.first.name,
          location: stadiums.first.location,
          rating: stadiums.first.rating,
          price: stadiums.first.price,
          iconKey: stadiums.first.iconKey,
          dayLabel: stadiums.first.days.first.label,
          dayDate: stadiums.first.days.first.date,
          slotTime: stadiums.first.days.first.slots[1].time,
          status: BookingService.activeStatus,
        ),
      ];

  final List<StadiumBooking> _bookings;

  @override
  Future<Set<String>> bookedSlotKeys(String stadiumId) async {
    return _bookings
        .where((booking) => booking.stadiumId == stadiumId)
        .map((booking) => booking.slotKey)
        .toSet();
  }

  @override
  Future<void> cancelBooking({required StadiumBooking booking}) async {
    _bookings.removeWhere((item) => item.rowId == booking.rowId);
  }

  @override
  Future<StadiumBooking> createBooking({
    required String userId,
    required String userName,
    required Stadium stadium,
    required BookingDay day,
    required BookingSlot slot,
  }) async {
    final booking = StadiumBooking(
      rowId: 'booking_${_bookings.length + 1}',
      userId: userId,
      userName: userName,
      stadiumId: stadium.id,
      slotId: '${stadium.id}-${day.date}-${slot.time}',
      stadiumName: stadium.name,
      location: stadium.location,
      rating: stadium.rating,
      price: stadium.price,
      iconKey: stadium.iconKey,
      dayLabel: day.label,
      dayDate: day.date,
      slotTime: slot.time,
      status: BookingService.activeStatus,
    );
    _bookings.add(booking);
    return booking;
  }

  @override
  Future<List<StadiumBooking>> listBookings(String userId) async {
    return List<StadiumBooking>.of(_bookings);
  }
}

class _FakeFavoritesRepository implements FavoritesRepository {
  _FakeFavoritesRepository()
    : _favorites = {
        stadiums[1].id: FavoriteStadium(
          rowId: 'favorite_1',
          stadiumId: stadiums[1].id,
          name: stadiums[1].name,
          location: stadiums[1].location,
          rating: stadiums[1].rating,
          price: stadiums[1].price,
          available: stadiums[1].available,
          iconKey: stadiums[1].iconKey,
        ),
      };

  final Map<String, FavoriteStadium> _favorites;

  @override
  Future<FavoriteStadium> addFavorite({
    required String userId,
    required Stadium stadium,
  }) async {
    final favorite = FavoriteStadium(
      rowId: 'favorite_${stadium.id}',
      stadiumId: stadium.id,
      name: stadium.name,
      location: stadium.location,
      rating: stadium.rating,
      price: stadium.price,
      available: stadium.available,
      iconKey: stadium.iconKey,
    );
    _favorites[stadium.id] = favorite;
    return favorite;
  }

  @override
  Future<Set<String>> favoriteStadiumIds(String userId) async {
    return _favorites.keys.toSet();
  }

  @override
  Future<List<FavoriteStadium>> listFavorites(String userId) async {
    return _favorites.values.toList();
  }

  @override
  Future<void> removeFavorite({
    required String userId,
    required String stadiumId,
  }) async {
    _favorites.remove(stadiumId);
  }

  @override
  Future<void> removeFavoriteRow({required String rowId}) async {
    _favorites.removeWhere((stadiumId, favorite) => favorite.rowId == rowId);
  }
}
