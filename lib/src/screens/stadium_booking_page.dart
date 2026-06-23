import 'dart:ui';

import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:flutter/material.dart';
import 'package:stadium/src/models/stadium.dart';
import 'package:stadium/src/services/booking_service.dart';
import 'package:stadium/src/services/favorite_service.dart';
import 'package:stadium/src/theme/app_theme.dart';
import 'package:stadium/src/widgets/app_notification.dart';
import 'package:url_launcher/url_launcher.dart';

class StadiumBookingPage extends StatefulWidget {
  const StadiumBookingPage({
    super.key,
    required this.stadium,
    required this.gradient,
    required this.user,
    required this.isHearted,
    this.favoriteRowId,
    this.bookingsRepository,
    this.favoritesRepository,
    this.onBookingCreated,
  });

  final Stadium stadium;
  final List<Color> gradient;
  final models.User user;
  final bool isHearted;
  final String? favoriteRowId;
  final BookingsRepository? bookingsRepository;
  final FavoritesRepository? favoritesRepository;
  final VoidCallback? onBookingCreated;

  @override
  State<StadiumBookingPage> createState() => _StadiumBookingPageState();
}

class _StadiumBookingPageState extends State<StadiumBookingPage> {
  int _selectedDayIndex = 0;
  BookingSlot? _selectedSlot;
  late bool _isHearted = widget.isHearted;
  final Set<String> _bookedSlotKeys = {};
  bool _isLoadingBookedSlots = true;
  bool _isBooking = false;
  bool _isUpdatingFavorite = false;

  BookingsRepository get _bookingsRepository =>
      widget.bookingsRepository ?? bookingService;

  FavoritesRepository get _favoritesRepository =>
      widget.favoritesRepository ?? favoriteService;

  BookingDay get _selectedDay => widget.stadium.days[_selectedDayIndex];

  @override
  void initState() {
    super.initState();
    _loadBookedSlots();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      body: Stack(
        children: [
          _BookingBackground(colors: colors),
          SafeArea(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
              children: [
                Row(
                  children: [
                    _IconButton(
                      icon: Icons.arrow_back_rounded,
                      onTap: () => Navigator.of(context).pop(_isHearted),
                    ),
                    const Spacer(),
                    _IconButton(
                      icon: _isHearted
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      isLoading: _isUpdatingFavorite,
                      color: _isHearted ? colors.action : null,
                      onTap: _toggleFavorite,
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                _StadiumHero(
                  stadium: widget.stadium,
                  gradient: widget.gradient,
                ),
                const SizedBox(height: 16),
                _LocationPanel(stadium: widget.stadium),
                const SizedBox(height: 24),
                Text(
                  'Choose a day',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 92,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemBuilder: (context, index) {
                      final day = widget.stadium.days[index];
                      final isSelected = index == _selectedDayIndex;

                      return _DayChip(
                        day: day,
                        isSelected: isSelected,
                        onTap: () {
                          setState(() {
                            _selectedDayIndex = index;
                            _selectedSlot = null;
                          });
                        },
                      );
                    },
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 10),
                    itemCount: widget.stadium.days.length,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Available times',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Text(
                      '${_selectedDay.label}, ${_selectedDay.date}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .58),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_isLoadingBookedSlots) ...[
                  LinearProgressIndicator(
                    minHeight: 2,
                    backgroundColor: colors.glassFill,
                    valueColor: AlwaysStoppedAnimation<Color>(colors.selection),
                  ),
                  const SizedBox(height: 12),
                ],
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _selectedDay.slots.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 2.45,
                  ),
                  itemBuilder: (context, index) {
                    final slot = _selectedDay.slots[index];
                    final isSelected = _selectedSlot == slot;
                    final isBooked = _bookedSlotKeys.contains(
                      _slotKey(_selectedDay, slot),
                    );

                    return _TimeSlotButton(
                      slot: slot,
                      isSelected: isSelected,
                      isBooked: isBooked,
                      onTap: isBooked || _isBooking || _isLoadingBookedSlots
                          ? null
                          : () {
                              setState(() => _selectedSlot = slot);
                            },
                    );
                  },
                ),
                const SizedBox(height: 24),
                _Legend(colors: colors),
                const SizedBox(height: 24),
                SizedBox(
                  height: 54,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: _selectedSlot == null
                          ? colors.glassFill
                          : colors.action,
                      foregroundColor: _selectedSlot == null
                          ? Colors.white.withValues(alpha: .46)
                          : colors.onAction,
                      disabledBackgroundColor: colors.glassFill,
                      disabledForegroundColor: Colors.white.withValues(
                        alpha: .46,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    onPressed: _selectedSlot == null || _isBooking
                        ? null
                        : _submitBooking,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 160),
                      child: _isBooking
                          ? SizedBox(
                              key: const ValueKey('bookingLoading'),
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  colors.onAction,
                                ),
                              ),
                            )
                          : Text(
                              key: ValueKey(_selectedSlot?.time),
                              _selectedSlot == null
                                  ? 'Select a time'
                                  : 'Book ${_selectedSlot!.time}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadBookedSlots() async {
    setState(() => _isLoadingBookedSlots = true);

    try {
      final bookedSlotKeys = await _bookingsRepository.bookedSlotKeys(
        widget.stadium.id,
      );

      if (!mounted) return;

      setState(() {
        _bookedSlotKeys
          ..clear()
          ..addAll(bookedSlotKeys);
        if (_selectedSlot != null &&
            _bookedSlotKeys.contains(_slotKey(_selectedDay, _selectedSlot!))) {
          _selectedSlot = null;
        }
      });
    } catch (error) {
      if (!mounted) return;

      showAppNotification(
        context,
        title: 'Availability unavailable',
        message: 'Could not refresh stadium availability.',
        type: AppNotificationType.error,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoadingBookedSlots = false);
      }
    }
  }

  Future<void> _submitBooking() async {
    final slot = _selectedSlot;
    if (slot == null || _isBooking) return;

    final day = _selectedDay;

    setState(() => _isBooking = true);

    try {
      final booking = await _bookingsRepository.createBooking(
        userId: widget.user.$id,
        userName: widget.user.name.trim().isEmpty
            ? 'User ${widget.user.$id.substring(0, 8)}'
            : widget.user.name,
        stadium: widget.stadium,
        day: day,
        slot: slot,
      );

      if (!mounted) return;

      setState(() {
        if (booking.status == BookingService.activeStatus ||
            booking.status == BookingService.pendingStatus) {
          _bookedSlotKeys.add(_slotKey(day, slot));
        }
        _selectedSlot = null;
      });
      widget.onBookingCreated?.call();

      showAppNotification(
        context,
        title: booking.status == BookingService.pendingStatus
            ? 'Request sent'
            : 'Stadium booked',
        message: booking.status == BookingService.pendingStatus
            ? 'Your booking request was sent. The manager will accept or deny it soon.'
            : '${widget.stadium.name} is yours ${day.label}, ${day.date} at ${slot.time}.',
        type: AppNotificationType.success,
      );
    } on BookingSlotUnavailableException {
      if (!mounted) return;

      setState(() {
        _bookedSlotKeys.add(_slotKey(day, slot));
        _selectedSlot = null;
      });

      showAppNotification(
        context,
        title: 'Time unavailable',
        message: 'That time was just booked.',
        type: AppNotificationType.warning,
      );
    } catch (error, stackTrace) {
      if (!mounted) return;

      print('=== BOOKING ERROR ===');
      print('Error: $error');
      print('Stack trace: $stackTrace');
      if (error is AppwriteException) {
        print('Appwrite error code: ${error.code}');
        print('Appwrite error message: ${error.message}');
        print('Appwrite error type: ${error.type}');
      }
      print('===================');

      final message = error is AppwriteException
          ? error.message ?? error.toString()
          : error.toString();

      showAppNotification(
        context,
        title: 'Booking failed',
        message: message,
        type: AppNotificationType.error,
      );
    } finally {
      if (mounted) {
        setState(() => _isBooking = false);
      }
    }
  }

  String _slotKey(BookingDay day, BookingSlot slot) {
    return bookingSlotKey(day.date, slot.time);
  }

  Future<void> _toggleFavorite() async {
    if (_isUpdatingFavorite) return;

    final wasHearted = _isHearted;

    setState(() {
      _isUpdatingFavorite = true;
      _isHearted = !wasHearted;
    });

    try {
      if (wasHearted) {
        final favoriteRowId = widget.favoriteRowId;
        if (favoriteRowId == null) {
          await _favoritesRepository.removeFavorite(
            userId: widget.user.$id,
            stadiumId: widget.stadium.id,
          );
        } else {
          await _favoritesRepository.removeFavoriteRow(rowId: favoriteRowId);
        }
      } else {
        await _favoritesRepository.addFavorite(
          userId: widget.user.$id,
          stadium: widget.stadium,
        );
      }
      if (!mounted) return;

      showAppNotification(
        context,
        title: wasHearted ? 'Removed from hearted' : 'Stadium hearted',
        message: wasHearted
            ? '${widget.stadium.name} was removed from your hearted stadiums.'
            : '${widget.stadium.name} was added to your hearted stadiums.',
        type: AppNotificationType.success,
      );
    } catch (error) {
      if (!mounted) return;

      setState(() => _isHearted = wasHearted);
      showAppNotification(
        context,
        title: 'Heart update failed',
        message: wasHearted
            ? 'Could not remove ${widget.stadium.name} from hearted stadiums.'
            : 'Could not heart ${widget.stadium.name}.',
        type: AppNotificationType.error,
      );
    } finally {
      if (mounted) {
        setState(() => _isUpdatingFavorite = false);
      }
    }
  }
}

class _LocationPanel extends StatelessWidget {
  const _LocationPanel({required this.stadium});

  final Stadium stadium;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        style: TextButton.styleFrom(
          foregroundColor: colors.action,
          padding: EdgeInsets.zero,
          minimumSize: const Size(0, 30),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
        onPressed: () => _openGoogleMaps(stadium),
        icon: const Icon(Icons.map_rounded, size: 16),
        label: const Text(
          'View on map',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
    );
  }

  Future<void> _openGoogleMaps(Stadium stadium) async {
    final query = Uri.encodeComponent('${stadium.name}, ${stadium.location}');
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$query',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _BookingBackground extends StatelessWidget {
  const _BookingBackground({required this.colors});

  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors.backgroundGradient,
        ),
      ),
    );
  }
}

class _StadiumHero extends StatelessWidget {
  const _StadiumHero({required this.stadium, required this.gradient});

  final Stadium stadium;
  final List<Color> gradient;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      padding: const EdgeInsets.all(14),
      child: Container(
        height: 220,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradient,
          ),
          borderRadius: BorderRadius.circular(26),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -18,
              bottom: -24,
              child: Icon(
                stadium.icon,
                size: 168,
                color: Colors.white.withValues(alpha: .13),
              ),
            ),
            Positioned(
              left: 18,
              right: 18,
              bottom: 18,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          stadium.name,
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          stadium.location,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: .7),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '\$${stadium.price}/h',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.day,
    required this.isSelected,
    required this.onTap,
  });

  final BookingDay day;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 96,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? colors.activeNavFill : colors.glassFill,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? colors.selection : colors.glassBorder,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              day.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isSelected ? colors.selection : Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              day.date,
              style: TextStyle(
                color: Colors.white.withValues(alpha: .54),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeSlotButton extends StatelessWidget {
  const _TimeSlotButton({
    required this.slot,
    required this.isSelected,
    required this.isBooked,
    required this.onTap,
  });

  final BookingSlot slot;
  final bool isSelected;
  final bool isBooked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isBooked
              ? Colors.white.withValues(alpha: .045)
              : isSelected
              ? colors.selection
              : colors.glassFill,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isBooked
                ? colors.glassBorder.withValues(alpha: .4)
                : isSelected
                ? colors.selection
                : colors.glassBorder,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              slot.time,
              style: TextStyle(
                color: isBooked
                    ? Colors.white.withValues(alpha: .28)
                    : isSelected
                    ? colors.onSelection
                    : Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (isBooked) ...[
              const SizedBox(height: 3),
              Text(
                'Booked',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .26),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.colors});

  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _LegendItem(color: colors.selection, label: 'Selected'),
        const SizedBox(width: 16),
        _LegendItem(color: Colors.grey, label: 'Available'),
        const SizedBox(width: 16),
        _LegendItem(
          color: const Color.fromARGB(
            255,
            255,
            255,
            255,
          ).withValues(alpha: .08),
          label: 'Booked',
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: .58),
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({
    required this.icon,
    this.onTap,
    this.isLoading = false,
    this.color,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final bool isLoading;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: _GlassPanel(
        borderRadius: 16,
        padding: EdgeInsets.zero,
        child: SizedBox(
          width: 46,
          height: 46,
          child: isLoading
              ? Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        colors.selection,
                      ),
                    ),
                  ),
                )
              : Icon(
                  icon,
                  color: color ?? Colors.white.withValues(alpha: .86),
                  size: 22,
                ),
        ),
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.borderRadius = 24,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: colors.glassFill,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: colors.glassBorder),
            boxShadow: [
              BoxShadow(
                color: colors.shadow,
                blurRadius: 30,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
