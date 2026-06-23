import 'package:appwrite/models.dart' as models;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:stadium/src/data/stadium_data.dart';
import 'package:stadium/src/models/stadium.dart';
import 'package:stadium/src/screens/stadium_booking_page.dart';
import 'package:stadium/src/services/booking_service.dart';
import 'package:stadium/src/services/favorite_service.dart';
import 'package:stadium/src/theme/app_theme.dart';
import 'package:stadium/src/widgets/app_notification.dart';

class BookingsPage extends StatefulWidget {
  const BookingsPage({
    super.key,
    required this.user,
    this.bookingsRepository,
    this.favoritesRepository,
    this.bookingsVersion,
    this.favoritesVersion,
    this.onBookingsChanged,
    this.onFavoritesChanged,
  });

  final models.User user;
  final BookingsRepository? bookingsRepository;
  final FavoritesRepository? favoritesRepository;
  final ValueListenable<int>? bookingsVersion;
  final ValueListenable<int>? favoritesVersion;
  final VoidCallback? onBookingsChanged;
  final VoidCallback? onFavoritesChanged;

  @override
  State<BookingsPage> createState() => _BookingsPageState();
}

class _BookingsPageState extends State<BookingsPage> {
  int _selectedSection = 0;
  late Future<List<StadiumBooking>> _bookingsFuture;
  late Future<List<FavoriteStadium>> _favoritesFuture;
  bool _ignoreNextBookingsChange = false;
  bool _ignoreNextFavoritesChange = false;

  BookingsRepository get _bookingsRepository =>
      widget.bookingsRepository ?? bookingService;

  FavoritesRepository get _favoritesRepository =>
      widget.favoritesRepository ?? favoriteService;

  @override
  void initState() {
    super.initState();
    _bookingsFuture = _loadBookings();
    _favoritesFuture = _loadFavorites();
    widget.bookingsVersion?.addListener(_handleBookingsChanged);
    widget.favoritesVersion?.addListener(_handleFavoritesChanged);
  }

  @override
  void didUpdateWidget(BookingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bookingsVersion != widget.bookingsVersion) {
      oldWidget.bookingsVersion?.removeListener(_handleBookingsChanged);
      widget.bookingsVersion?.addListener(_handleBookingsChanged);
    }

    if (oldWidget.favoritesVersion != widget.favoritesVersion) {
      oldWidget.favoritesVersion?.removeListener(_handleFavoritesChanged);
      widget.favoritesVersion?.addListener(_handleFavoritesChanged);
    }
  }

  @override
  void dispose() {
    widget.bookingsVersion?.removeListener(_handleBookingsChanged);
    widget.favoritesVersion?.removeListener(_handleFavoritesChanged);
    super.dispose();
  }

  Future<List<StadiumBooking>> _loadBookings() {
    return _bookingsRepository.listBookings(widget.user.$id);
  }

  Future<List<FavoriteStadium>> _loadFavorites() {
    return _favoritesRepository.listFavorites(widget.user.$id);
  }

  @override
  Widget build(BuildContext context) {
    return _BookingsFrame(
      title: 'My Bookings',
      subtitle: 'Your reserved stadium slots will appear here.',
      selectedSection: _selectedSection,
      bookingsFuture: _bookingsFuture,
      favoritesFuture: _favoritesFuture,
      onOpenHistory: _openBookingHistory,
      onCancelBooking: _cancelBooking,
      onOpenFavorite: (favorite, index) =>
          _openFavorite(context, favorite, index),
      onRemoveFavorite: _removeFavorite,
      onSectionChanged: (index) {
        setState(() {
          _selectedSection = index;
          if (index == 0) {
            _bookingsFuture = _loadBookings();
          } else {
            _favoritesFuture = _loadFavorites();
          }
        });
      },
    );
  }

  void _openBookingHistory() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => BookingHistoryPage(
          user: widget.user,
          bookingsRepository: _bookingsRepository,
        ),
      ),
    );
  }

  void _refreshBookings() {
    final bookingsFuture = _loadBookings();
    setState(() {
      _bookingsFuture = bookingsFuture;
    });
  }

  void _refreshFavorites() {
    final favoritesFuture = _loadFavorites();
    setState(() {
      _favoritesFuture = favoritesFuture;
    });
  }

  void _handleBookingsChanged() {
    if (_ignoreNextBookingsChange) {
      _ignoreNextBookingsChange = false;
      return;
    }

    if (_selectedSection == 0) {
      _refreshBookings();
    }
  }

  void _handleFavoritesChanged() {
    if (_ignoreNextFavoritesChange) {
      _ignoreNextFavoritesChange = false;
      return;
    }

    if (_selectedSection == 1) {
      _refreshFavorites();
    }
  }

  Future<void> _openFavorite(
    BuildContext context,
    FavoriteStadium favorite,
    int index,
  ) async {
    final stadium = _stadiumFromFavorite(favorite);
    final colors = context.appColors;
    final isHearted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => StadiumBookingPage(
          stadium: stadium,
          gradient:
              colors.stadiumGradients[index % colors.stadiumGradients.length],
          user: widget.user,
          isHearted: true,
          favoriteRowId: favorite.rowId,
          bookingsRepository: _bookingsRepository,
          favoritesRepository: _favoritesRepository,
          onBookingCreated: widget.onBookingsChanged,
        ),
      ),
    );

    if (isHearted == false) {
      _refreshFavorites();
      _ignoreNextFavoritesChange = true;
      widget.onFavoritesChanged?.call();
    }
  }

  Future<void> _cancelBooking(StadiumBooking booking) async {
    try {
      await _bookingsRepository.cancelBooking(booking: booking);
      setState(() {
        _bookingsFuture = _bookingsFuture.then(
          (bookings) =>
              bookings.where((item) => item.rowId != booking.rowId).toList(),
        );
      });
      _ignoreNextBookingsChange = true;
      widget.onBookingsChanged?.call();
      if (!mounted) return;

      showAppNotification(
        context,
        title: 'Booking canceled',
        message: '${booking.stadiumName} was removed from your bookings.',
        type: AppNotificationType.success,
      );
    } catch (error) {
      if (!mounted) return;

      showAppNotification(
        context,
        title: 'Cancel failed',
        message: 'Could not cancel ${booking.stadiumName}.',
        type: AppNotificationType.error,
      );
    }
  }

  Future<void> _removeFavorite(FavoriteStadium favorite) async {
    try {
      await _favoritesRepository.removeFavoriteRow(rowId: favorite.rowId);
      setState(() {
        _favoritesFuture = _favoritesFuture.then(
          (favorites) =>
              favorites.where((item) => item.rowId != favorite.rowId).toList(),
        );
      });
      _ignoreNextFavoritesChange = true;
      widget.onFavoritesChanged?.call();
      if (!mounted) return;

      showAppNotification(
        context,
        title: 'Removed from hearted',
        message: '${favorite.name} was removed from your hearted stadiums.',
        type: AppNotificationType.success,
      );
    } catch (error) {
      if (!mounted) return;

      showAppNotification(
        context,
        title: 'Remove failed',
        message: 'Could not remove ${favorite.name} from hearted stadiums.',
        type: AppNotificationType.error,
      );
    }
  }

  Stadium _stadiumFromFavorite(FavoriteStadium favorite) {
    for (final stadium in stadiums) {
      if (stadium.id == favorite.stadiumId) return stadium;
    }

    return Stadium(
      id: favorite.stadiumId,
      name: favorite.name,
      location: favorite.location,
      rating: favorite.rating,
      price: favorite.price,
      available: favorite.available,
      iconKey: favorite.iconKey,
      icon: favorite.icon,
      days: const [],
    );
  }
}

class _ActiveBookingsSection extends StatelessWidget {
  const _ActiveBookingsSection({
    super.key,
    required this.bookingsFuture,
    required this.onCancel,
  });

  final Future<List<StadiumBooking>> bookingsFuture;
  final ValueChanged<StadiumBooking> onCancel;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<StadiumBooking>>(
      future: bookingsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done &&
            !snapshot.hasData) {
          return const _BookingsStatusCard(
            icon: Icons.confirmation_number_rounded,
            title: 'Loading bookings',
            subtitle: 'Fetching your reserved stadium slots.',
          );
        }

        if (snapshot.hasError) {
          return const _BookingsStatusCard(
            icon: Icons.error_rounded,
            title: 'Could not load bookings',
            subtitle: 'Check your connection and try again.',
          );
        }

        return _AnimatedBookingsList(
          bookings: snapshot.data ?? const [],
          onCancel: onCancel,
        );
      },
    );
  }
}

class _AnimatedBookingsList extends StatefulWidget {
  const _AnimatedBookingsList({required this.bookings, required this.onCancel});

  final List<StadiumBooking> bookings;
  final ValueChanged<StadiumBooking> onCancel;

  @override
  State<_AnimatedBookingsList> createState() => _AnimatedBookingsListState();
}

class _AnimatedBookingsListState extends State<_AnimatedBookingsList> {
  late List<StadiumBooking> _bookings = List.of(widget.bookings);

  @override
  void didUpdateWidget(_AnimatedBookingsList oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncBookings();
  }

  @override
  Widget build(BuildContext context) {
    if (_bookings.isEmpty) {
      return const _BookingsStatusCard(
        icon: Icons.stadium_rounded,
        title: 'No bookings',
        subtitle: 'Book a stadium from the home page to track it here.',
      );
    }

    return Column(
      children: [
        for (var index = 0; index < _bookings.length; index++)
          _BookingListItem(
            booking: _bookings[index],
            index: index,
            onCancel: widget.onCancel,
            showAcceptedDivider: _showAcceptedDivider(index),
          ),
      ],
    );
  }

  void _syncBookings() {
    setState(() => _bookings = List.of(widget.bookings));
  }

  bool _showAcceptedDivider(int index) {
    if (index == 0) return false;

    return _bookings[index - 1].status == BookingService.activeStatus &&
        _bookings[index].status != BookingService.activeStatus;
  }
}

class _BookingListItem extends StatelessWidget {
  const _BookingListItem({
    required this.booking,
    required this.index,
    required this.onCancel,
    this.showAcceptedDivider = false,
  });

  final StadiumBooking booking;
  final int index;
  final ValueChanged<StadiumBooking> onCancel;
  final bool showAcceptedDivider;

  @override
  Widget build(BuildContext context) {
    final canCancel = booking.status == BookingService.activeStatus;

    return Column(
      children: [
        if (showAcceptedDivider) const _AcceptedBookingsDivider(),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _ActiveBookingCard(
            booking: booking,
            index: index,
            onCancel: canCancel ? () => onCancel(booking) : null,
          ),
        ),
      ],
    );
  }
}

class _AcceptedBookingsDivider extends StatelessWidget {
  const _AcceptedBookingsDivider();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 16),
      child: Container(
        height: 1,
        decoration: BoxDecoration(
          color: colors.glassBorder.withValues(alpha: .74),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class _ActiveBookingCard extends StatelessWidget {
  const _ActiveBookingCard({
    required this.booking,
    required this.index,
    required this.onCancel,
    this.showCancelAction = true,
  });

  final StadiumBooking booking;
  final int index;
  final VoidCallback? onCancel;
  final bool showCancelAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final gradient =
        colors.stadiumGradients[index % colors.stadiumGradients.length];
    final statusLabel = _statusLabel(
      booking.status,
      includeActive: !showCancelAction,
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.glassFill,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.glassBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradient),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              booking.icon,
              color: Colors.white.withValues(alpha: .88),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  booking.stadiumName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  booking.location,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white.withValues(alpha: .56)),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    _BookingMeta(
                      icon: Icons.calendar_month_rounded,
                      label: '${booking.dayLabel}, ${booking.dayDate}',
                    ),
                    _BookingMeta(
                      icon: Icons.access_time_rounded,
                      label: booking.slotTime,
                    ),
                    _BookingMeta(
                      icon: Icons.payments_rounded,
                      label: '\$${booking.price}/h',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (statusLabel != null)
            _BookingStatusBadge(label: statusLabel)
          else if (showCancelAction)
            IconButton(
              tooltip: 'Cancel booking',
              onPressed: onCancel,
              style: IconButton.styleFrom(
                foregroundColor: colors.action,
                minimumSize: const Size(42, 42),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(Icons.close_rounded, size: 22),
            ),
        ],
      ),
    );
  }

  String? _statusLabel(String status, {required bool includeActive}) {
    return switch (status) {
      BookingService.activeStatus when includeActive => 'Confirmed',
      BookingService.pendingStatus => 'Pending',
      BookingService.deniedStatus => 'Declined',
      BookingService.cancelledStatus => 'Cancelled',
      _ => null,
    };
  }
}

class BookingHistoryPage extends StatelessWidget {
  const BookingHistoryPage({
    super.key,
    required this.user,
    required this.bookingsRepository,
  });

  final models.User user;
  final BookingsRepository bookingsRepository;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors.backgroundGradient,
          ),
        ),
        child: SafeArea(
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    onPressed: () => Navigator.of(context).pop(),
                    style: IconButton.styleFrom(
                      foregroundColor: Colors.white.withValues(alpha: .86),
                      backgroundColor: colors.glassFill,
                      minimumSize: const Size(46, 46),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: colors.glassBorder),
                      ),
                    ),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const Spacer(),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Booking History',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'All your booking requests and their latest status.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white.withValues(alpha: .62),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 24),
              FutureBuilder<List<StadiumBooking>>(
                future: bookingsRepository.listBookingHistory(user.$id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done &&
                      !snapshot.hasData) {
                    return const _BookingsStatusCard(
                      icon: Icons.history_rounded,
                      title: 'Loading history',
                      subtitle: 'Fetching your booking history.',
                    );
                  }

                  if (snapshot.hasError) {
                    return const _BookingsStatusCard(
                      icon: Icons.error_rounded,
                      title: 'Could not load history',
                      subtitle: 'Check your connection and try again.',
                    );
                  }

                  final bookings = snapshot.data ?? const [];
                  if (bookings.isEmpty) {
                    return const _BookingsStatusCard(
                      icon: Icons.history_rounded,
                      title: 'No booking history',
                      subtitle: 'Your requests will appear here after booking.',
                    );
                  }

                  return Column(
                    children: [
                      for (var index = 0; index < bookings.length; index++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _ActiveBookingCard(
                            booking: bookings[index],
                            index: index,
                            onCancel: null,
                            showCancelAction: false,
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookingStatusBadge extends StatelessWidget {
  const _BookingStatusBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final labelColor = label == 'Pending' ? Colors.amber : colors.selection;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: colors.activeNavFill,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.glassBorder),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: labelColor,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _BookingMeta extends StatelessWidget {
  const _BookingMeta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: colors.mutedIcon, size: 16),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: .72),
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _HeartedStadiumsSection extends StatelessWidget {
  const _HeartedStadiumsSection({
    super.key,
    required this.favoritesFuture,
    required this.onOpen,
    required this.onRemove,
  });

  final Future<List<FavoriteStadium>> favoritesFuture;
  final void Function(FavoriteStadium favorite, int index) onOpen;
  final ValueChanged<FavoriteStadium> onRemove;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<FavoriteStadium>>(
      future: favoritesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done &&
            !snapshot.hasData) {
          return const _HeartedStatusCard(
            icon: Icons.favorite_rounded,
            title: 'Loading hearted stadiums',
            subtitle: 'Fetching your saved stadiums.',
          );
        }

        if (snapshot.hasError) {
          return const _HeartedStatusCard(
            icon: Icons.error_rounded,
            title: 'Could not load hearted stadiums',
            subtitle: 'Check your connection and try again.',
          );
        }

        return _AnimatedHeartedList(
          favorites: snapshot.data ?? const [],
          onOpen: onOpen,
          onRemove: onRemove,
        );
      },
    );
  }
}

class _AnimatedHeartedList extends StatefulWidget {
  const _AnimatedHeartedList({
    required this.favorites,
    required this.onOpen,
    required this.onRemove,
  });

  final List<FavoriteStadium> favorites;
  final void Function(FavoriteStadium favorite, int index) onOpen;
  final ValueChanged<FavoriteStadium> onRemove;

  @override
  State<_AnimatedHeartedList> createState() => _AnimatedHeartedListState();
}

class _AnimatedHeartedListState extends State<_AnimatedHeartedList> {
  final _listKey = GlobalKey<AnimatedListState>();
  late final List<FavoriteStadium> _favorites = List.of(widget.favorites);

  @override
  void didUpdateWidget(_AnimatedHeartedList oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncFavorites();
  }

  @override
  Widget build(BuildContext context) {
    if (_favorites.isEmpty) {
      return const _HeartedStatusCard(
        icon: Icons.favorite_border_rounded,
        title: 'No hearted stadiums',
        subtitle: 'Tap the heart on a stadium to save it here.',
      );
    }

    return AnimatedList(
      key: _listKey,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      initialItemCount: _favorites.length,
      itemBuilder: (context, index, animation) {
        return _AnimatedListEntry(
          animation: animation,
          child: _FavoriteListItem(
            favorite: _favorites[index],
            index: index,
            onOpen: widget.onOpen,
            onRemove: widget.onRemove,
          ),
        );
      },
    );
  }

  void _syncFavorites() {
    final nextFavorites = widget.favorites;
    if (_favorites.isEmpty && nextFavorites.isNotEmpty) {
      setState(() => _favorites.addAll(nextFavorites));
      return;
    }

    final nextIds = nextFavorites.map((favorite) => favorite.rowId).toSet();
    var removedAny = false;

    for (var index = _favorites.length - 1; index >= 0; index--) {
      final favorite = _favorites[index];
      if (nextIds.contains(favorite.rowId)) continue;

      final removedIndex = index;
      final removedFavorite = _favorites.removeAt(index);
      removedAny = true;
      _listKey.currentState?.removeItem(
        removedIndex,
        (context, animation) => _AnimatedListEntry(
          animation: animation,
          child: _FavoriteListItem(
            favorite: removedFavorite,
            index: removedIndex,
            onOpen: widget.onOpen,
            onRemove: widget.onRemove,
          ),
        ),
        duration: const Duration(milliseconds: 340),
      );
    }

    if (removedAny && _favorites.isEmpty) {
      Future<void>.delayed(const Duration(milliseconds: 340), () {
        if (mounted) setState(() {});
      });
    }

    for (var index = 0; index < nextFavorites.length; index++) {
      final favorite = nextFavorites[index];
      final existingIndex = _favorites.indexWhere(
        (item) => item.rowId == favorite.rowId,
      );

      if (existingIndex == -1) {
        _favorites.insert(index, favorite);
        _listKey.currentState?.insertItem(
          index,
          duration: const Duration(milliseconds: 320),
        );
      } else {
        _favorites[existingIndex] = favorite;
      }
    }
  }
}

class _FavoriteListItem extends StatelessWidget {
  const _FavoriteListItem({
    required this.favorite,
    required this.index,
    required this.onOpen,
    required this.onRemove,
  });

  final FavoriteStadium favorite;
  final int index;
  final void Function(FavoriteStadium favorite, int index) onOpen;
  final ValueChanged<FavoriteStadium> onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _HeartedStadiumCard(
        stadium: favorite,
        index: index,
        onTap: () => onOpen(favorite, index),
        onRemove: () => onRemove(favorite),
      ),
    );
  }
}

class _AnimatedListEntry extends StatelessWidget {
  const _AnimatedListEntry({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    return SizeTransition(
      sizeFactor: curved,
      axisAlignment: -1,
      child: FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(.04, 0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      ),
    );
  }
}

class _HeartedStadiumCard extends StatelessWidget {
  const _HeartedStadiumCard({
    required this.stadium,
    required this.index,
    required this.onTap,
    required this.onRemove,
  });

  final FavoriteStadium stadium;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final gradient =
        colors.stadiumGradients[index % colors.stadiumGradients.length];

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.glassFill,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: colors.glassBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: gradient),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                stadium.icon,
                color: Colors.white.withValues(alpha: .88),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    stadium.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    stadium.location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .56),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.star_rounded, color: colors.star, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        stadium.rating.toString(),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .72),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '\$${stadium.price}/h',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            IconButton(
              tooltip: 'Remove from hearted',
              onPressed: onRemove,
              style: IconButton.styleFrom(
                foregroundColor: colors.action,
                minimumSize: const Size(42, 42),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(Icons.favorite_rounded, size: 22),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookingsSegmentedControl extends StatelessWidget {
  const _BookingsSegmentedControl({
    required this.selectedIndex,
    required this.onChanged,
  });

  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: colors.glassFill,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.glassBorder),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const gap = 6.0;
          final segmentWidth = (constraints.maxWidth - gap) / 2;

          return SizedBox(
            height: 42,
            child: Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutCubic,
                  left: selectedIndex == 0 ? 0 : segmentWidth + gap,
                  top: 0,
                  bottom: 0,
                  width: segmentWidth,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.activeNavFill,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                Row(
                  children: [
                    _SegmentButton(
                      label: 'Bookings',
                      isSelected: selectedIndex == 0,
                      onTap: () => onChanged(0),
                    ),
                    const SizedBox(width: gap),
                    _SegmentButton(
                      label: 'Hearted',
                      isSelected: selectedIndex == 1,
                      onTap: () => onChanged(1),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: 42,
          child: Center(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              style: TextStyle(
                color: isSelected
                    ? colors.selection
                    : Colors.white.withValues(alpha: .62),
                fontWeight: FontWeight.w900,
              ),
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ),
        ),
      ),
    );
  }
}

class _BookingsFrame extends StatelessWidget {
  const _BookingsFrame({
    required this.title,
    required this.subtitle,
    required this.selectedSection,
    required this.bookingsFuture,
    required this.favoritesFuture,
    required this.onOpenHistory,
    required this.onCancelBooking,
    required this.onOpenFavorite,
    required this.onRemoveFavorite,
    required this.onSectionChanged,
  });

  final String title;
  final String subtitle;
  final int selectedSection;
  final Future<List<StadiumBooking>> bookingsFuture;
  final Future<List<FavoriteStadium>> favoritesFuture;
  final VoidCallback onOpenHistory;
  final ValueChanged<StadiumBooking> onCancelBooking;
  final void Function(FavoriteStadium favorite, int index) onOpenFavorite;
  final ValueChanged<FavoriteStadium> onRemoveFavorite;
  final ValueChanged<int> onSectionChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors.backgroundGradient,
          ),
        ),
        child: SafeArea(
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 110),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Booking history',
                    onPressed: onOpenHistory,
                    style: IconButton.styleFrom(
                      foregroundColor: colors.selection,
                      backgroundColor: colors.glassFill,
                      minimumSize: const Size(46, 46),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: colors.glassBorder),
                      ),
                    ),
                    icon: const Icon(Icons.history_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white.withValues(alpha: .62),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 26),
              _BookingsSegmentedControl(
                selectedIndex: selectedSection,
                onChanged: onSectionChanged,
              ),
              const SizedBox(height: 18),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 320),
                reverseDuration: const Duration(milliseconds: 240),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                layoutBuilder: (currentChild, previousChildren) {
                  return Stack(
                    alignment: Alignment.topCenter,
                    children: [...previousChildren, ?currentChild],
                  );
                },
                transitionBuilder: (child, animation) {
                  final key = child.key;
                  final slidesFromRight = key == const ValueKey(1);
                  final begin = Offset(slidesFromRight ? .05 : -.05, .02);
                  final curved = CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                    reverseCurve: Curves.easeInCubic,
                  );

                  return FadeTransition(
                    opacity: curved,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: begin,
                        end: Offset.zero,
                      ).animate(curved),
                      child: child,
                    ),
                  );
                },
                child: selectedSection == 0
                    ? _ActiveBookingsSection(
                        key: const ValueKey(0),
                        bookingsFuture: bookingsFuture,
                        onCancel: onCancelBooking,
                      )
                    : _HeartedStadiumsSection(
                        key: const ValueKey(1),
                        favoritesFuture: favoritesFuture,
                        onOpen: onOpenFavorite,
                        onRemove: onRemoveFavorite,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeartedStatusCard extends StatelessWidget {
  const _HeartedStatusCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.glassFill,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.glassBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: colors.glassFill,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.white.withValues(alpha: .58)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingsStatusCard extends StatelessWidget {
  const _BookingsStatusCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.glassFill,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.glassBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: colors.glassFill,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.white.withValues(alpha: .58)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
