import 'dart:async';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:stadium/src/models/stadium.dart';
import 'package:stadium/src/services/booking_service.dart';
import 'package:stadium/src/services/manager_stadium_service.dart';
import 'package:stadium/src/theme/app_theme.dart';
import 'package:stadium/src/utils/stadium_schedule.dart';
import 'package:stadium/src/widgets/app_notification.dart';
import 'package:stadium/src/widgets/stadium_image.dart';

class ManagerStadiumPage extends StatefulWidget {
  const ManagerStadiumPage({
    super.key,
    required this.user,
    this.repository,
    this.bookingsRepository,
    this.refreshVersion = 0,
  });

  final models.User user;
  final ManagerStadiumRepository? repository;
  final BookingsRepository? bookingsRepository;
  final int refreshVersion;

  @override
  State<ManagerStadiumPage> createState() => _ManagerStadiumPageState();
}

class _ManagerStadiumPageState extends State<ManagerStadiumPage> {
  late Future<Stadium?> _stadiumFuture = _loadStadium();

  ManagerStadiumRepository get _repository =>
      widget.repository ?? managerStadiumService;

  BookingsRepository get _bookingsRepository =>
      widget.bookingsRepository ?? bookingService;

  Future<Stadium?> _loadStadium() {
    return _repository.managerStadium(widget.user.$id);
  }

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
          child: FutureBuilder<Stadium?>(
            future: _stadiumFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return _ManagerStatusView(
                  title: 'Could not load your stadium',
                  subtitle: _errorMessage(snapshot.error),
                  actionLabel: 'Retry',
                  onAction: _refresh,
                  icon: Icons.error_outline_rounded,
                );
              }

              final stadium = snapshot.data;
              if (stadium == null) {
                return _ManagerStatusView(
                  title: 'Create your stadium',
                  subtitle:
                      'No stadium found for your manager account yet. Create it now so regular users can discover and book it.',
                  actionLabel: 'Create stadium',
                  onAction: _openCreateForm,
                  icon: Icons.add_business_rounded,
                );
              }

              return _ManagerStadiumDetails(
                managerId: widget.user.$id,
                stadium: stadium,
                bookingsRepository: _bookingsRepository,
                refreshVersion: widget.refreshVersion,
              );
            },
          ),
        ),
      ),
    );
  }

  String _errorMessage(Object? error) {
    if (error is AppwriteException) {
      return error.message ?? 'Please verify your Appwrite stadiums table.';
    }

    return 'Please try again in a moment.';
  }

  void _refresh() {
    setState(() {
      _stadiumFuture = _loadStadium();
    });
  }

  Future<void> _openCreateForm() async {
    final created = await showModalBottomSheet<Stadium>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CreateManagerStadiumSheet(
        onSubmit: (form) => _repository.createManagerStadium(
          managerId: widget.user.$id,
          name: form.name,
          location: form.location,
          price: form.price,
          imageBytes: form.imageBytes,
          imageFilename: form.imageFilename,
        ),
      ),
    );

    if (!mounted || created == null) return;

    showAppNotification(
      context,
      title: 'Stadium created',
      message: '${created.name} is now available for users.',
      type: AppNotificationType.success,
    );

    _refresh();
  }
}

class _ManagerStatusView extends StatelessWidget {
  const _ManagerStatusView({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colors.glassFill,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: colors.glassBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 34),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .7),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: Text(actionLabel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ManagerStadiumDetails extends StatelessWidget {
  const _ManagerStadiumDetails({
    required this.managerId,
    required this.stadium,
    required this.bookingsRepository,
    required this.refreshVersion,
  });

  final String managerId;
  final Stadium stadium;
  final BookingsRepository bookingsRepository;
  final int refreshVersion;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
      physics: const BouncingScrollPhysics(),
      children: [
        Text(
          'Your stadium',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'This is what regular users will see and book.',
          style: TextStyle(color: Colors.white.withValues(alpha: .68)),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: colors.glassFill,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: colors.glassBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: StadiumImage(
                      fileId: stadium.imageFileId,
                      fallbackIcon: stadium.icon,
                      iconSize: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      stadium.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _DetailRow(label: 'Location', value: stadium.location),
              _DetailRow(label: 'Price / hour', value: '\$${stadium.price}'),
              _DetailRow(label: 'Rating', value: stadium.rating.toString()),
              _DetailRow(label: 'Availability', value: stadium.available),
            ],
          ),
        ),
        const SizedBox(height: 22),
        _ManagerSchedulePanel(
          managerId: managerId,
          stadium: stadium,
          bookingsRepository: bookingsRepository,
          refreshVersion: refreshVersion,
        ),
      ],
    );
  }
}

class _ManagerSchedulePanel extends StatefulWidget {
  const _ManagerSchedulePanel({
    required this.managerId,
    required this.stadium,
    required this.bookingsRepository,
    required this.refreshVersion,
  });

  final String managerId;
  final Stadium stadium;
  final BookingsRepository bookingsRepository;
  final int refreshVersion;

  @override
  State<_ManagerSchedulePanel> createState() => _ManagerSchedulePanelState();
}

class _ManagerSchedulePanelState extends State<_ManagerSchedulePanel> {
  int _selectedDayIndex = 0;
  late Future<List<BookedSlot>> _bookedSlotsFuture = _loadBookedSlots();
  late DateTime _now = DateTime.now();
  final Set<String> _blockingSlotKeys = {};
  Timer? _clockTimer;

  BookingDay get _selectedDay => widget.stadium.days[_selectedDayIndex];

  List<BookingSlot> get _visibleSlots {
    if (widget.stadium.days.isEmpty) return const [];
    return _visibleSlotsFor(_selectedDay);
  }

  @override
  void initState() {
    super.initState();
    _startClock();
  }

  @override
  void didUpdateWidget(_ManagerSchedulePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stadium.id != widget.stadium.id ||
        oldWidget.bookingsRepository != widget.bookingsRepository ||
        oldWidget.refreshVersion != widget.refreshVersion) {
      _selectedDayIndex = 0;
      _bookedSlotsFuture = _loadBookedSlots();
    } else if (_selectedDayIndex >= widget.stadium.days.length) {
      _selectedDayIndex = 0;
    }
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  Future<List<BookedSlot>> _loadBookedSlots() {
    return widget.bookingsRepository.bookedSlots(widget.stadium.id);
  }

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
      child: FutureBuilder<List<BookedSlot>>(
        future: _bookedSlotsFuture,
        builder: (context, snapshot) {
          final slotsByKey = {
            for (final slot in snapshot.data ?? const <BookedSlot>[])
              slot.slotKey: slot,
          };

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Times',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (snapshot.connectionState != ConnectionState.done)
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          colors.selection,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Tap an available time to mark it booked.',
                style: TextStyle(color: Colors.white.withValues(alpha: .62)),
              ),
              const SizedBox(height: 16),
              if (snapshot.hasError)
                _ScheduleStatus(
                  icon: Icons.error_outline_rounded,
                  title: 'Could not load booked times',
                  subtitle: 'Check your connection and try again.',
                )
              else if (widget.stadium.days.isEmpty)
                const _ScheduleStatus(
                  icon: Icons.access_time_rounded,
                  title: 'No times set',
                  subtitle: 'Users will see times here when slots are added.',
                )
              else ...[
                SizedBox(
                  height: 92,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemBuilder: (context, index) {
                      final day = widget.stadium.days[index];
                      return _ManagerDayChip(
                        day: day,
                        isSelected: index == _selectedDayIndex,
                        onTap: () {
                          setState(() {
                            _selectedDayIndex = index;
                          });
                        },
                      );
                    },
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 10),
                    itemCount: widget.stadium.days.length,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Times',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .86),
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
                if (_visibleSlots.isEmpty)
                  _ScheduleStatus(
                    icon: Icons.access_time_filled_rounded,
                    title: 'No upcoming times left',
                    subtitle: 'Choose another day.',
                  )
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _visibleSlots.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 2.55,
                        ),
                    itemBuilder: (context, index) {
                      final slot = _visibleSlots[index];
                      final bookedSlot =
                          slotsByKey[bookingSlotKey(
                            _selectedDay.date,
                            slot.time,
                          )];

                      return _ManagerTimeSlot(
                        slot: slot,
                        status: bookedSlot?.status,
                        isProcessing: _blockingSlotKeys.contains(
                          bookingSlotKey(_selectedDay.date, slot.time),
                        ),
                        onTap: switch (bookedSlot?.status) {
                          null => () => _markSlotBooked(_selectedDay, slot),
                          BookingService.activeStatus =>
                            () => _unmarkSlotBooked(_selectedDay, slot),
                          _ => null,
                        },
                      );
                    },
                  ),
              ],
              const SizedBox(height: 16),
              const _ManagerScheduleLegend(),
            ],
          );
        },
      ),
    );
  }

  List<BookingSlot> _visibleSlotsFor(BookingDay day) {
    return day.slots
        .where((slot) => !bookingSlotHasPassed(day, slot, now: _now))
        .toList();
  }

  void _startClock() {
    _clockTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted || widget.stadium.days.isEmpty) return;

      setState(() {
        _now = DateTime.now();
      });
    });
  }

  Future<void> _markSlotBooked(BookingDay day, BookingSlot slot) async {
    final slotKey = bookingSlotKey(day.date, slot.time);
    if (_blockingSlotKeys.contains(slotKey)) return;

    setState(() => _blockingSlotKeys.add(slotKey));
    try {
      await widget.bookingsRepository.markSlotBookedByManager(
        managerId: widget.managerId,
        stadium: widget.stadium,
        day: day,
        slot: slot,
      );
      if (!mounted) return;

      showAppNotification(
        context,
        title: 'Time marked booked',
        message: '${day.label} at ${slot.time} is no longer available.',
        type: AppNotificationType.success,
      );
      setState(() {
        _bookedSlotsFuture = _loadBookedSlots();
      });
    } on BookingSlotUnavailableException {
      if (!mounted) return;

      showAppNotification(
        context,
        title: 'Time unavailable',
        message: 'That time is already booked.',
        type: AppNotificationType.warning,
      );
      setState(() {
        _bookedSlotsFuture = _loadBookedSlots();
      });
    } on BookingSlotExpiredException {
      if (!mounted) return;

      showAppNotification(
        context,
        title: 'Time has passed',
        message: 'Choose an upcoming time.',
        type: AppNotificationType.warning,
      );
    } on AppwriteException catch (error) {
      if (!mounted) return;

      showAppNotification(
        context,
        title: 'Could not mark time',
        message: error.message ?? 'Please try again.',
        type: AppNotificationType.error,
      );
    } on BookingServiceException catch (error) {
      if (!mounted) return;

      showAppNotification(
        context,
        title: 'Could not mark time',
        message: error.message,
        type: AppNotificationType.error,
      );
    } catch (_) {
      if (!mounted) return;

      showAppNotification(
        context,
        title: 'Could not mark time',
        message: 'Please try again.',
        type: AppNotificationType.error,
      );
    } finally {
      if (mounted) {
        setState(() => _blockingSlotKeys.remove(slotKey));
      }
    }
  }

  Future<void> _unmarkSlotBooked(BookingDay day, BookingSlot slot) async {
    final slotKey = bookingSlotKey(day.date, slot.time);
    if (_blockingSlotKeys.contains(slotKey)) return;

    setState(() => _blockingSlotKeys.add(slotKey));
    try {
      await widget.bookingsRepository.unmarkSlotBookedByManager(
        managerId: widget.managerId,
        stadium: widget.stadium,
        day: day,
        slot: slot,
      );
      if (!mounted) return;

      showAppNotification(
        context,
        title: 'Time marked available',
        message: '${day.label} at ${slot.time} can be booked again.',
        type: AppNotificationType.success,
      );
      setState(() {
        _bookedSlotsFuture = _loadBookedSlots();
      });
    } on BookingSlotUnavailableException {
      if (!mounted) return;

      showAppNotification(
        context,
        title: 'Cannot unblock time',
        message: 'This time belongs to a user booking or pending request.',
        type: AppNotificationType.warning,
      );
      setState(() {
        _bookedSlotsFuture = _loadBookedSlots();
      });
    } on AppwriteException catch (error) {
      if (!mounted) return;

      showAppNotification(
        context,
        title: 'Could not unblock time',
        message: error.message ?? 'Please try again.',
        type: AppNotificationType.error,
      );
    } on BookingServiceException catch (error) {
      if (!mounted) return;

      showAppNotification(
        context,
        title: 'Could not unblock time',
        message: error.message,
        type: AppNotificationType.error,
      );
    } catch (_) {
      if (!mounted) return;

      showAppNotification(
        context,
        title: 'Could not unblock time',
        message: 'Please try again.',
        type: AppNotificationType.error,
      );
    } finally {
      if (mounted) {
        setState(() => _blockingSlotKeys.remove(slotKey));
      }
    }
  }
}

class _ManagerTimeSlot extends StatelessWidget {
  const _ManagerTimeSlot({
    required this.slot,
    required this.status,
    required this.isProcessing,
    required this.onTap,
  });

  final BookingSlot slot;
  final String? status;
  final bool isProcessing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isPending = status == BookingService.pendingStatus;
    final isAccepted = status == BookingService.activeStatus;
    final label = switch (status) {
      BookingService.pendingStatus => 'Pending',
      BookingService.activeStatus => 'Booked',
      _ => 'Available',
    };
    final highlightColor = isPending ? Colors.amber : colors.action;

    return GestureDetector(
      onTap: isProcessing ? null : onTap,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isAccepted || isPending
              ? highlightColor.withValues(alpha: .12)
              : colors.glassFill,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isAccepted || isPending
                ? highlightColor.withValues(alpha: .56)
                : colors.glassBorder,
          ),
        ),
        child: isProcessing
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(colors.selection),
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    slot.time,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    label,
                    style: TextStyle(
                      color: isAccepted || isPending
                          ? highlightColor
                          : Colors.white.withValues(alpha: .52),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _ManagerDayChip extends StatelessWidget {
  const _ManagerDayChip({
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

class _ManagerScheduleLegend extends StatelessWidget {
  const _ManagerScheduleLegend();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        _LegendDot(color: colors.glassBorder, label: 'Available'),
        _LegendDot(color: Colors.amber, label: 'Pending'),
        _LegendDot(color: colors.action, label: 'Booked'),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

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
            color: Colors.white.withValues(alpha: .62),
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _ScheduleStatus extends StatelessWidget {
  const _ScheduleStatus({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: .72)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
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

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: .65),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CreateManagerStadiumSheet extends StatefulWidget {
  const _CreateManagerStadiumSheet({required this.onSubmit});

  final Future<Stadium> Function(_StadiumFormValue value) onSubmit;

  @override
  State<_CreateManagerStadiumSheet> createState() =>
      _CreateManagerStadiumSheetState();
}

class _CreateManagerStadiumSheetState
    extends State<_CreateManagerStadiumSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _priceController = TextEditingController(text: '80');
  bool _isSaving = false;
  bool _isPickingImage = false;
  Uint8List? _imageBytes;
  String? _imageFilename;

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Create stadium profile',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _StadiumImagePicker(
                    bytes: _imageBytes,
                    isPicking: _isPickingImage,
                    onPick: _pickImage,
                    onRemove: _imageBytes == null
                        ? null
                        : () => setState(() {
                            _imageBytes = null;
                            _imageFilename = null;
                          }),
                  ),
                  const SizedBox(height: 14),
                  _FormInput(
                    controller: _nameController,
                    label: 'Stadium name',
                    validator: _required,
                  ),
                  _FormInput(
                    controller: _locationController,
                    label: 'Location',
                    validator: _required,
                  ),
                  _FormInput(
                    controller: _priceController,
                    label: 'Price per hour',
                    keyboardType: TextInputType.number,
                    validator: _priceValidator,
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isSaving ? null : _save,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check_rounded),
                      label: Text(_isSaving ? 'Saving...' : 'Create stadium'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) return 'This field is required';
    return null;
  }

  String? _priceValidator(String? value) {
    final requiredError = _required(value);
    if (requiredError != null) return requiredError;

    final parsed = int.tryParse(value!.trim());
    if (parsed == null || parsed <= 0) return 'Enter a valid positive number';
    return null;
  }

  Future<void> _pickImage() async {
    setState(() => _isPickingImage = true);
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1800,
        maxHeight: 1200,
        imageQuality: 88,
      );
      if (image == null || !mounted) return;

      final bytes = await image.readAsBytes();
      if (bytes.lengthInBytes > ManagerStadiumService.maximumImageSize) {
        throw ArgumentError('Choose an image smaller than 5 MB.');
      }
      setState(() {
        _imageBytes = bytes;
        _imageFilename = image.name;
      });
    } on PlatformException catch (error) {
      if (!mounted) return;
      _showImageError(error.message ?? 'Could not open your photo library.');
    } on ArgumentError catch (error) {
      if (!mounted) return;
      _showImageError(error.message?.toString() ?? 'Invalid image.');
    } catch (_) {
      if (!mounted) return;
      _showImageError('Could not load that image.');
    } finally {
      if (mounted) setState(() => _isPickingImage = false);
    }
  }

  void _showImageError(String message) {
    showAppNotification(
      context,
      title: 'Image unavailable',
      message: message,
      type: AppNotificationType.error,
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final stadium = await widget.onSubmit(
        _StadiumFormValue(
          name: _nameController.text.trim(),
          location: _locationController.text.trim(),
          price: int.parse(_priceController.text.trim()),
          imageBytes: _imageBytes,
          imageFilename: _imageFilename,
        ),
      );

      if (!mounted) return;
      Navigator.of(context).pop(stadium);
    } on AppwriteException catch (error) {
      if (!mounted) return;

      showAppNotification(
        context,
        title: 'Could not create stadium',
        message: error.message ?? 'Please check your Appwrite stadiums table.',
        type: AppNotificationType.error,
      );
    } catch (_) {
      if (!mounted) return;

      showAppNotification(
        context,
        title: 'Could not create stadium',
        message: 'Please try again.',
        type: AppNotificationType.error,
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}

class _StadiumImagePicker extends StatelessWidget {
  const _StadiumImagePicker({
    required this.bytes,
    required this.isPicking,
    required this.onPick,
    required this.onRemove,
  });

  final Uint8List? bytes;
  final bool isPicking;
  final VoidCallback onPick;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Stadium photo',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isPicking ? null : onPick,
            borderRadius: BorderRadius.circular(20),
            child: Ink(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                color: colors.glassFill,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: colors.glassBorder),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(19),
                child: bytes == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (isPicking)
                            const CircularProgressIndicator(strokeWidth: 2.5)
                          else
                            const Icon(
                              Icons.add_photo_alternate_rounded,
                              size: 38,
                            ),
                          const SizedBox(height: 10),
                          Text(
                            isPicking
                                ? 'Opening gallery...'
                                : 'Choose a stadium photo',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Optional · JPG, PNG, or WebP · up to 5 MB',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: .55),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      )
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.memory(bytes!, fit: BoxFit.cover),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: .5),
                                ],
                              ),
                            ),
                          ),
                          const Positioned(
                            left: 14,
                            bottom: 12,
                            child: Text(
                              'Tap to choose another photo',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                          Positioned(
                            right: 8,
                            top: 8,
                            child: IconButton.filledTonal(
                              tooltip: 'Remove photo',
                              onPressed: onRemove,
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FormInput extends StatelessWidget {
  const _FormInput({
    required this.controller,
    required this.label,
    this.keyboardType,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}

class _StadiumFormValue {
  const _StadiumFormValue({
    required this.name,
    required this.location,
    required this.price,
    this.imageBytes,
    this.imageFilename,
  });

  final String name;
  final String location;
  final int price;
  final Uint8List? imageBytes;
  final String? imageFilename;
}
