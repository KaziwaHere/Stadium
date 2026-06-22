import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:flutter/material.dart';
import 'package:stadium/src/services/booking_service.dart';
import 'package:stadium/src/theme/app_theme.dart';
import 'package:stadium/src/widgets/app_notification.dart';

class ManagerRequestsPage extends StatefulWidget {
  const ManagerRequestsPage({super.key, required this.user, this.repository});

  final models.User user;
  final ManagerBookingRequestsRepository? repository;

  @override
  State<ManagerRequestsPage> createState() => _ManagerRequestsPageState();
}

class _ManagerRequestsPageState extends State<ManagerRequestsPage> {
  late Future<List<StadiumBooking>> _requestsFuture = _loadRequests();
  final Set<String> _processingIds = {};

  ManagerBookingRequestsRepository get _repository =>
      widget.repository ?? managerBookingRequestsService;

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
          child: FutureBuilder<List<StadiumBooking>>(
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

              return RefreshIndicator(
                onRefresh: () async => _refresh(),
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
                  itemCount: requests.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final request = requests[index];
                    final isProcessing = _processingIds.contains(request.rowId);

                    return _RequestCard(
                      request: request,
                      isProcessing: isProcessing,
                      onAccept: () => _accept(request),
                      onDeny: () => _deny(request),
                    );
                  },
                ),
              );
            },
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

  Future<void> _accept(StadiumBooking request) async {
    if (_processingIds.contains(request.rowId)) return;

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
      _refresh();
    } on BookingSlotUnavailableException {
      if (!mounted) return;

      showAppNotification(
        context,
        title: 'Slot unavailable',
        message: 'That slot is no longer available. The request was denied.',
        type: AppNotificationType.warning,
      );
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
    required this.isProcessing,
    required this.onAccept,
    required this.onDeny,
  });

  final StadiumBooking request;
  final bool isProcessing;
  final VoidCallback onAccept;
  final VoidCallback onDeny;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

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
          Text(
            'Requested by: ${request.userName}',
            style: TextStyle(color: Colors.white.withValues(alpha: .7)),
          ),
          const SizedBox(height: 8),
          Text(
            '${request.dayLabel}, ${request.dayDate} at ${request.slotTime}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: .88),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
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
          ),
        ],
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
  final VoidCallback onAction;

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
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(actionLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
