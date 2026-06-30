import 'dart:typed_data';

import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:flutter/material.dart';
import 'package:stadium/src/services/booking_service.dart';
import 'package:stadium/src/services/booking_requester_profile_service.dart';
import 'package:stadium/src/services/profile_picture_service.dart';
import 'package:stadium/src/theme/app_theme.dart';
import 'package:stadium/src/utils/stadium_schedule.dart';
import 'package:stadium/src/widgets/app_confirmation_dialog.dart';
import 'package:stadium/src/widgets/app_notification.dart';

class ManagerRequestsPage extends StatefulWidget {
  const ManagerRequestsPage({
    super.key,
    required this.user,
    this.repository,
    this.profileRepository,
    this.onRequestsChanged,
  });

  final models.User user;
  final ManagerBookingRequestsRepository? repository;
  final BookingRequesterProfileRepository? profileRepository;
  final VoidCallback? onRequestsChanged;

  @override
  State<ManagerRequestsPage> createState() => _ManagerRequestsPageState();
}

class _ManagerRequestsPageState extends State<ManagerRequestsPage> {
  late Future<List<StadiumBooking>> _requestsFuture = _loadRequests();
  final Set<String> _processingIds = {};

  ManagerBookingRequestsRepository get _repository =>
      widget.repository ?? managerBookingRequestsService;
  BookingRequesterProfileRepository get _profileRepository =>
      widget.profileRepository ?? bookingRequesterProfileService;

  Future<List<StadiumBooking>> _loadRequests() {
    return _repository.listPendingRequests(widget.user.$id);
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
          child: RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        'Requests',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Request history',
                      onPressed: _openRequestHistory,
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
                const SizedBox(height: 6),
                Text(
                  'Accept or deny pending booking requests.',
                  style: TextStyle(color: Colors.white.withValues(alpha: .68)),
                ),
                const SizedBox(height: 18),
                FutureBuilder<List<StadiumBooking>>(
                  future: _requestsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return _RequestsStatusCard(
                        icon: Icons.error_outline_rounded,
                        title: 'Could not load requests',
                        subtitle: _errorMessage(snapshot.error),
                        actionLabel: 'Retry',
                        onAction: _refresh,
                      );
                    }

                    final requests = snapshot.data ?? const [];
                    if (requests.isEmpty) {
                      return _RequestsStatusCard(
                        icon: Icons.inbox_rounded,
                        title: 'No pending requests',
                        subtitle:
                            'When users request bookings for your stadium, they will appear here.',
                        actionLabel: 'Refresh',
                        onAction: _refresh,
                      );
                    }

                    return Column(
                      children: [
                        for (var index = 0; index < requests.length; index++)
                          Padding(
                            padding: EdgeInsets.only(
                              bottom: index == requests.length - 1 ? 0 : 12,
                            ),
                            child: _RequestCard(
                              request: requests[index],
                              isProcessing: _processingIds.contains(
                                requests[index].rowId,
                              ),
                              onAccept: () => _accept(requests[index]),
                              onDeny: () => _deny(requests[index]),
                              onProfileTap: () =>
                                  _openRequesterProfile(requests[index]),
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
      ),
    );
  }

  String _errorMessage(Object? error) {
    if (error is AppwriteException) {
      return error.message ?? 'Please verify booking permissions.';
    }

    return 'Please try again.';
  }

  void _refresh() {
    setState(() {
      _requestsFuture = _loadRequests();
    });
  }

  void _openRequestHistory() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ManagerRequestHistoryPage(
          managerId: widget.user.$id,
          repository: _repository,
          profileRepository: _profileRepository,
        ),
      ),
    );
  }

  void _openRequesterProfile(StadiumBooking request) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _RequesterProfileSheet(
        managerId: widget.user.$id,
        request: request,
        repository: _profileRepository,
      ),
    );
  }

  Future<void> _accept(StadiumBooking request) async {
    if (_processingIds.contains(request.rowId)) return;

    final shouldAccept = await showAppConfirmationDialog(
      context: context,
      icon: Icons.check_circle_rounded,
      title: 'Accept request?',
      message:
          'Confirm ${request.userName} for ${request.dayLabel} at ${request.slotTime}.',
      confirmLabel: 'Accept',
      cancelLabel: 'Review',
    );
    if (!shouldAccept || !mounted) return;

    setState(() => _processingIds.add(request.rowId));

    try {
      await _repository.acceptRequest(
        managerId: widget.user.$id,
        request: request,
      );
      if (!mounted) return;

      showAppNotification(
        context,
        title: 'Request accepted',
        message:
            '${request.stadiumName} ${request.dayLabel} at ${request.slotTime} is confirmed.',
        type: AppNotificationType.success,
      );
      widget.onRequestsChanged?.call();
      _refresh();
    } on BookingSlotUnavailableException {
      if (!mounted) return;

      showAppNotification(
        context,
        title: 'Slot unavailable',
        message: 'That slot is no longer available. The request was denied.',
        type: AppNotificationType.warning,
      );
      widget.onRequestsChanged?.call();
      _refresh();
    } on AppwriteException catch (error) {
      if (!mounted) return;

      showAppNotification(
        context,
        title: 'Accept failed',
        message: error.message ?? 'Could not accept request.',
        type: AppNotificationType.error,
      );
    } on BookingServiceException catch (error) {
      if (!mounted) return;

      showAppNotification(
        context,
        title: 'Accept failed',
        message: error.message,
        type: AppNotificationType.error,
      );
    } catch (error, stackTrace) {
      if (!mounted) return;

      debugPrint('=== ACCEPT REQUEST ERROR ===');
      debugPrint('Error: $error');
      debugPrint('Stack trace: $stackTrace');
      debugPrint('============================');

      showAppNotification(
        context,
        title: 'Accept failed',
        message: error.toString(),
        type: AppNotificationType.error,
      );
    } finally {
      if (mounted) {
        setState(() => _processingIds.remove(request.rowId));
      }
    }
  }

  Future<void> _deny(StadiumBooking request) async {
    if (_processingIds.contains(request.rowId)) return;

    final shouldDeny = await showAppConfirmationDialog(
      context: context,
      icon: Icons.block_rounded,
      title: 'Deny request?',
      message:
          'Deny ${request.userName} for ${request.dayLabel} at ${request.slotTime}?',
      confirmLabel: 'Deny',
      cancelLabel: 'Review',
      isDestructive: true,
    );
    if (!shouldDeny || !mounted) return;

    setState(() => _processingIds.add(request.rowId));

    try {
      await _repository.denyRequest(
        managerId: widget.user.$id,
        request: request,
      );
      if (!mounted) return;

      showAppNotification(
        context,
        title: 'Request denied',
        message: 'The booking request was denied.',
        type: AppNotificationType.success,
      );
      widget.onRequestsChanged?.call();
      _refresh();
    } on AppwriteException catch (error) {
      if (!mounted) return;

      showAppNotification(
        context,
        title: 'Deny failed',
        message: error.message ?? 'Could not deny request.',
        type: AppNotificationType.error,
      );
    } on BookingServiceException catch (error) {
      if (!mounted) return;

      showAppNotification(
        context,
        title: 'Deny failed',
        message: error.message,
        type: AppNotificationType.error,
      );
    } catch (error, stackTrace) {
      if (!mounted) return;

      debugPrint('=== DENY REQUEST ERROR ===');
      debugPrint('Error: $error');
      debugPrint('Stack trace: $stackTrace');
      debugPrint('==========================');

      showAppNotification(
        context,
        title: 'Deny failed',
        message: error.toString(),
        type: AppNotificationType.error,
      );
    } finally {
      if (mounted) {
        setState(() => _processingIds.remove(request.rowId));
      }
    }
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    this.isProcessing = false,
    this.onAccept,
    this.onDeny,
    this.onProfileTap,
  });

  final StadiumBooking request;
  final bool isProcessing;
  final VoidCallback? onAccept;
  final VoidCallback? onDeny;
  final VoidCallback? onProfileTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final showActions = onAccept != null && onDeny != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.glassFill,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            request.stadiumName,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onProfileTap,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: colors.activeNavFill,
                      child: const Icon(Icons.person_rounded, size: 22),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Requested by',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: .5),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            request.userName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (onProfileTap != null)
                      Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.white.withValues(alpha: .5),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${request.dayLabel}, ${bookingMonthDayLabel(request.dayDate)} at ${request.slotTime}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: .88),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          if (showActions)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: isProcessing ? null : onDeny,
                    child: const Text('Deny'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: isProcessing ? null : onAccept,
                    child: isProcessing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Accept'),
                  ),
                ),
              ],
            )
          else
            Align(
              alignment: Alignment.centerLeft,
              child: _RequestStatusBadge(status: request.status),
            ),
        ],
      ),
    );
  }
}

class ManagerRequestHistoryPage extends StatelessWidget {
  const ManagerRequestHistoryPage({
    super.key,
    required this.managerId,
    required this.repository,
    required this.profileRepository,
  });

  final String managerId;
  final ManagerBookingRequestsRepository repository;
  final BookingRequesterProfileRepository profileRepository;

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
                'Request History',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'All visible booking requests for your stadium.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white.withValues(alpha: .62),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 24),
              FutureBuilder<List<StadiumBooking>>(
                future: repository.listRequestHistory(managerId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done &&
                      !snapshot.hasData) {
                    return const _RequestsStatusCard(
                      icon: Icons.history_rounded,
                      title: 'Loading history',
                      subtitle: 'Fetching stadium request history.',
                      actionLabel: 'Refresh',
                      onAction: null,
                    );
                  }

                  if (snapshot.hasError) {
                    return _RequestsStatusCard(
                      icon: Icons.error_outline_rounded,
                      title: 'Could not load history',
                      subtitle: 'Check your connection and try again.',
                      actionLabel: 'Back',
                      onAction: () => Navigator.of(context).pop(),
                    );
                  }

                  final requests = snapshot.data ?? const [];
                  if (requests.isEmpty) {
                    return const _RequestsStatusCard(
                      icon: Icons.history_rounded,
                      title: 'No request history',
                      subtitle: 'Stadium requests will appear here.',
                      actionLabel: 'Refresh',
                      onAction: null,
                    );
                  }

                  return Column(
                    children: [
                      for (var index = 0; index < requests.length; index++)
                        Padding(
                          padding: EdgeInsets.only(
                            bottom: index == requests.length - 1 ? 0 : 12,
                          ),
                          child: _RequestCard(
                            request: requests[index],
                            onProfileTap: () => showModalBottomSheet<void>(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (context) => _RequesterProfileSheet(
                                managerId: managerId,
                                request: requests[index],
                                repository: profileRepository,
                              ),
                            ),
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

class _RequesterProfileSheet extends StatefulWidget {
  const _RequesterProfileSheet({
    required this.managerId,
    required this.request,
    required this.repository,
  });

  final String managerId;
  final StadiumBooking request;
  final BookingRequesterProfileRepository repository;

  @override
  State<_RequesterProfileSheet> createState() => _RequesterProfileSheetState();
}

class _RequesterProfileSheetState extends State<_RequesterProfileSheet> {
  late Future<BookingRequesterProfile> _profileFuture = _load();

  Future<BookingRequesterProfile> _load() {
    return widget.repository.getProfile(
      managerId: widget.managerId,
      requestId: widget.request.rowId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: FutureBuilder<BookingRequesterProfile>(
            future: _profileFuture,
            builder: (context, snapshot) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .22),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Requester profile',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (snapshot.connectionState != ConnectionState.done)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(28),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (snapshot.hasError)
                    Center(
                      child: Column(
                        children: [
                          const Icon(Icons.error_outline_rounded, size: 36),
                          const SizedBox(height: 10),
                          const Text('Could not load this profile.'),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () => setState(() {
                              _profileFuture = _load();
                            }),
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  else
                    _RequesterProfileContent(
                      profile: snapshot.requireData,
                      request: widget.request,
                    ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.action,
                        foregroundColor: colors.onAction,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Done'),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _RequesterProfileContent extends StatelessWidget {
  const _RequesterProfileContent({
    required this.profile,
    required this.request,
  });

  final BookingRequesterProfile profile;
  final StadiumBooking request;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final displayName = profile.name.isEmpty ? request.userName : profile.name;

    return Column(
      children: [
        _RequesterAvatar(profile: profile),
        const SizedBox(height: 12),
        Text(
          displayName,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 18),
        _ProfileDetailRow(
          icon: Icons.phone_rounded,
          label: 'Phone number',
          value: profile.phone.isEmpty ? 'Not provided' : profile.phone,
        ),
        const SizedBox(height: 10),
        _ProfileDetailRow(
          icon: Icons.event_rounded,
          label: 'Requested time',
          value: '${request.dayLabel} at ${request.slotTime}',
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.glassFill,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.glassBorder),
          ),
          child: Text(
            'Profile access is limited to users requesting your stadium.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: .56),
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}

class _RequesterAvatar extends StatelessWidget {
  const _RequesterAvatar({required this.profile});

  final BookingRequesterProfile profile;

  @override
  Widget build(BuildContext context) {
    final fileId = profile.profilePictureId;
    final fallback = CircleAvatar(
      radius: 42,
      child: Text(
        profile.name.trim().isEmpty
            ? '?'
            : profile.name.trim().substring(0, 1).toUpperCase(),
        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
      ),
    );
    if (fileId == null) return fallback;

    return FutureBuilder<Uint8List>(
      future: profilePictureService.preview(fileId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return fallback;
        return CircleAvatar(
          radius: 42,
          backgroundImage: MemoryImage(snapshot.data!),
        );
      },
    );
  }
}

class _ProfileDetailRow extends StatelessWidget {
  const _ProfileDetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.glassFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.glassBorder),
      ),
      child: Row(
        children: [
          Icon(icon, color: colors.mutedIcon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .5),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestStatusBadge extends StatelessWidget {
  const _RequestStatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final (label, labelColor) = switch (status) {
      BookingService.activeStatus => ('Accepted', colors.action),
      BookingService.pendingStatus => ('Pending', Colors.amber),
      BookingService.deniedStatus => ('Denied', Colors.redAccent),
      BookingService.cancelledStatus => ('Cancelled', Colors.white70),
      _ => (status, Colors.white70),
    };

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

class _RequestsStatusCard extends StatelessWidget {
  const _RequestsStatusCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback? onAction;

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
              if (onAction != null) ...[
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(actionLabel),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
