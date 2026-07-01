import 'package:flutter/material.dart';
import 'package:stadium/src/services/admin_service.dart';
import 'package:stadium/src/theme/app_theme.dart';
import 'package:stadium/src/widgets/app_notification.dart';

class AdminStadiumsPage extends StatefulWidget {
  const AdminStadiumsPage({super.key, required this.adminRepository});

  final AdminService adminRepository;

  @override
  State<AdminStadiumsPage> createState() => _AdminStadiumsPageState();
}

class _AdminStadiumsPageState extends State<AdminStadiumsPage> {
  late Future<List<AdminStadiumBookingStats>> _stadiumsFuture = _load();
  String? _updatingFeaturedId;

  Future<List<AdminStadiumBookingStats>> _load() {
    return widget.adminRepository.listStadiumBookingStats();
  }

  void _refresh() {
    setState(() {
      _stadiumsFuture = _load();
    });
  }

  Future<void> _setFeatured(AdminStadiumBookingStats stadium) async {
    if (stadium.isFeatured || _updatingFeaturedId != null) return;
    final currentStadiums = await _stadiumsFuture;
    if (!mounted) return;
    setState(() => _updatingFeaturedId = stadium.id);
    try {
      await widget.adminRepository.setFeaturedStadium(stadium.id);
      if (!mounted) return;
      final updatedStadiums = currentStadiums
          .map((item) => item.withFeatured(item.id == stadium.id))
          .toList();
      setState(() {
        _updatingFeaturedId = null;
        _stadiumsFuture = Future.value(updatedStadiums);
      });
      showAppNotification(
        context,
        title: 'Featured stadium updated',
        message: '${stadium.name} now appears as the featured stadium.',
        type: AppNotificationType.success,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _updatingFeaturedId = null);
      showAppNotification(
        context,
        title: 'Update failed',
        message: error.toString(),
        type: AppNotificationType.error,
      );
    }
  }

  Future<void> _openWeeklyHistory() async {
    try {
      final stadiums = await _stadiumsFuture;
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AdminWeeklyHistoryPage(stadiums: stadiums),
        ),
      );
    } catch (_) {
      if (mounted) _refresh();
    }
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
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
                child: _Header(
                  onBack: Navigator.of(context).pop,
                  onHistory: _openWeeklyHistory,
                ),
              ),
              Expanded(
                child: FutureBuilder<List<AdminStadiumBookingStats>>(
                  future: _stadiumsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        !snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return _Status(
                        icon: Icons.cloud_off_rounded,
                        title: 'Could not load stadiums',
                        subtitle: snapshot.error.toString(),
                        onRetry: _refresh,
                      );
                    }
                    final stadiums = snapshot.data ?? const [];
                    if (stadiums.isEmpty) {
                      return const _Status(
                        icon: Icons.stadium_outlined,
                        title: 'No stadiums yet',
                        subtitle:
                            'Stadiums will appear here after they are created.',
                      );
                    }
                    return RefreshIndicator(
                      onRefresh: () async => _refresh(),
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                        children: [
                          _OverallWeeklyReport(stadiums: stadiums),
                          const SizedBox(height: 18),
                          const _SectionTitle('Stadium activity'),
                          const SizedBox(height: 10),
                          for (
                            var index = 0;
                            index < stadiums.length;
                            index++
                          ) ...[
                            _StadiumCard(
                              stadium: stadiums[index],
                              isUpdatingFeatured:
                                  _updatingFeaturedId == stadiums[index].id,
                              onFeatured: () => _setFeatured(stadiums[index]),
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => AdminStadiumBookingsPage(
                                    stadium: stadiums[index],
                                  ),
                                ),
                              ),
                            ),
                            if (index != stadiums.length - 1)
                              const SizedBox(height: 12),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AdminStadiumBookingsPage extends StatelessWidget {
  const AdminStadiumBookingsPage({super.key, required this.stadium});

  final AdminStadiumBookingStats stadium;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors.backgroundGradient),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
                child: _Header(
                  title: stadium.name,
                  subtitle: '${stadium.bookingCount} approved bookings',
                  onBack: Navigator.of(context).pop,
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                  children: [
                    _StadiumWeeklyReport(stadium: stadium),
                    const SizedBox(height: 18),
                    if (stadium.bookings.isEmpty)
                      const _InlineEmptyBookings()
                    else ...[
                      const _SectionTitle('Approved bookings'),
                      const SizedBox(height: 10),
                      for (
                        var index = 0;
                        index < stadium.bookings.length;
                        index++
                      ) ...[
                        _BookingCard(booking: stadium.bookings[index]),
                        if (index != stadium.bookings.length - 1)
                          const SizedBox(height: 10),
                      ],
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AdminWeeklyHistoryPage extends StatelessWidget {
  const AdminWeeklyHistoryPage({super.key, required this.stadiums});

  final List<AdminStadiumBookingStats> stadiums;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final weeks = _historyWeeks(stadiums);
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors.backgroundGradient),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
                child: _Header(
                  title: 'Weekly history',
                  subtitle: 'Completed bookings and 3% admin earnings',
                  onBack: Navigator.of(context).pop,
                ),
              ),
              Expanded(
                child: weeks.isEmpty
                    ? const _Status(
                        icon: Icons.history_rounded,
                        title: 'No weekly history',
                        subtitle: 'Completed weeks will appear here.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                        itemCount: weeks.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (_, index) => _WeeklyHistoryCard(
                          weekStart: weeks[index],
                          stadiums: stadiums,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeeklyHistoryCard extends StatelessWidget {
  const _WeeklyHistoryCard({required this.weekStart, required this.stadiums});
  final DateTime weekStart;
  final List<AdminStadiumBookingStats> stadiums;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final currentWeek = _weekStart(now);
    final reportTime = weekStart == currentWeek
        ? now
        : weekStart
              .add(const Duration(days: 7))
              .subtract(const Duration(microseconds: 1));
    final reports =
        stadiums
            .map((stadium) => stadium.weeklyReport(now: reportTime))
            .where((report) => report.approvedBookings > 0)
            .toList()
          ..sort((a, b) => b.approvedBookings.compareTo(a.approvedBookings));
    final completed = reports.fold<int>(
      0,
      (sum, report) => sum + report.completedBookings,
    );
    final bookings = reports.fold<int>(
      0,
      (sum, report) => sum + report.approvedBookings,
    );
    final gross = reports.fold<double>(
      0,
      (sum, report) => sum + report.grossRevenue,
    );
    final commission = reports.fold<double>(
      0,
      (sum, report) => sum + report.adminCommission,
    );
    final weekEnd = weekStart.add(const Duration(days: 6));

    return _ReportPanel(
      title: weekStart == currentWeek
          ? 'This week'
          : _weekRange(weekStart, weekEnd),
      subtitle: '$bookings bookings across ${reports.length} stadiums',
      metrics: [
        _Metric('Admin share', _money(commission), Icons.payments_rounded),
        _Metric('Completed', '$completed', Icons.task_alt_rounded),
        _Metric('Gross sales', _money(gross), Icons.attach_money_rounded),
        _Metric('Stadiums', '${reports.length}', Icons.stadium_rounded),
      ],
      footer: reports.isEmpty
          ? 'No bookings'
          : 'Most active: ${reports.first.stadiumName} · ${reports.first.approvedBookings} bookings',
    );
  }
}

List<DateTime> _historyWeeks(List<AdminStadiumBookingStats> stadiums) {
  final weeks = <DateTime>{};
  for (final stadium in stadiums) {
    for (final booking in stadium.bookings) {
      final start = booking.startsAt;
      if (start != null) weeks.add(_weekStart(start));
    }
  }
  final result = weeks.toList()..sort((a, b) => b.compareTo(a));
  return result;
}

DateTime _weekStart(DateTime value) {
  final date = DateTime(value.year, value.month, value.day);
  return date.subtract(Duration(days: date.weekday - DateTime.monday));
}

String _weekRange(DateTime start, DateTime end) =>
    '${_shortDate(start)} – ${_shortDate(end)}';

String _shortDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}';
}

class _InlineEmptyBookings extends StatelessWidget {
  const _InlineEmptyBookings();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 24),
    child: Column(
      children: [
        Icon(Icons.event_available_rounded, color: Colors.white70, size: 38),
        SizedBox(height: 10),
        Text(
          'No approved bookings',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
        SizedBox(height: 5),
        Text(
          'Pending, denied, and cancelled bookings are not counted.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white60),
        ),
      ],
    ),
  );
}

class _Header extends StatelessWidget {
  const _Header({
    required this.onBack,
    this.onHistory,
    this.title = 'Stadium bookings',
    this.subtitle = 'Approved and non-cancelled reservations',
  });

  final VoidCallback onBack;
  final VoidCallback? onHistory;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton.filledTonal(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
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
        if (onHistory != null)
          IconButton(
            tooltip: 'Weekly history',
            onPressed: onHistory,
            icon: const Icon(Icons.history_rounded),
          ),
      ],
    );
  }
}

class _StadiumCard extends StatelessWidget {
  const _StadiumCard({
    required this.stadium,
    required this.onTap,
    required this.onFeatured,
    required this.isUpdatingFeatured,
  });
  final AdminStadiumBookingStats stadium;
  final VoidCallback onTap;
  final VoidCallback onFeatured;
  final bool isUpdatingFeatured;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.glassFill,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: colors.glassBorder),
          ),
          child: Row(
            children: [
              const Icon(Icons.stadium_rounded, color: Colors.white, size: 30),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stadium.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    if (stadium.location.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        stadium.location,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .58),
                        ),
                      ),
                    ],
                    const SizedBox(height: 7),
                    _ActivityLine(report: stadium.weeklyReport()),
                  ],
                ),
              ),
              IconButton(
                tooltip: stadium.isFeatured
                    ? 'Featured stadium'
                    : 'Make featured',
                onPressed: stadium.isFeatured || isUpdatingFeatured
                    ? null
                    : onFeatured,
                style: IconButton.styleFrom(
                  foregroundColor: stadium.isFeatured
                      ? colors.selection
                      : Colors.white54,
                  disabledForegroundColor: stadium.isFeatured
                      ? colors.selection
                      : Colors.white38,
                ),
                icon: isUpdatingFeatured
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        stadium.isFeatured
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                      ),
              ),
              Text(
                '${stadium.bookingCount}',
                style: TextStyle(
                  color: colors.selection,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, color: Colors.white54),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverallWeeklyReport extends StatelessWidget {
  const _OverallWeeklyReport({required this.stadiums});
  final List<AdminStadiumBookingStats> stadiums;

  @override
  Widget build(BuildContext context) {
    final reports = stadiums.map((stadium) => stadium.weeklyReport()).toList();
    final completed = reports.fold<int>(
      0,
      (total, report) => total + report.completedBookings,
    );
    final upcoming = reports.fold<int>(
      0,
      (total, report) => total + report.upcomingBookings,
    );
    final gross = reports.fold<double>(
      0,
      (total, report) => total + report.grossRevenue,
    );
    final commission = reports.fold<double>(
      0,
      (total, report) => total + report.adminCommission,
    );
    final busiest = reports.isEmpty
        ? null
        : (reports.toList()..sort(
                (a, b) => b.approvedBookings.compareTo(a.approvedBookings),
              ))
              .first;

    return _ReportPanel(
      title: 'This week',
      subtitle: 'Monday–Sunday · completed bookings earn 3%',
      metrics: [
        _Metric('Admin share', _money(commission), Icons.payments_rounded),
        _Metric('Completed', '$completed', Icons.task_alt_rounded),
        _Metric('Gross sales', _money(gross), Icons.attach_money_rounded),
        _Metric('Upcoming', '$upcoming', Icons.upcoming_rounded),
      ],
      footer: busiest == null
          ? null
          : 'Most active: ${busiest.stadiumName} · ${busiest.activityRate.toStringAsFixed(1)}%',
    );
  }
}

class _StadiumWeeklyReport extends StatelessWidget {
  const _StadiumWeeklyReport({required this.stadium});
  final AdminStadiumBookingStats stadium;

  @override
  Widget build(BuildContext context) {
    final report = stadium.weeklyReport();
    return _ReportPanel(
      title: 'Weekly report',
      subtitle: '${_adminDateLabel(report.weekStart.toIso8601String())} onward',
      metrics: [
        _Metric(
          'Admin share',
          _money(report.adminCommission),
          Icons.payments_rounded,
        ),
        _Metric(
          'Completed',
          '${report.completedBookings}',
          Icons.task_alt_rounded,
        ),
        _Metric(
          'Gross sales',
          _money(report.grossRevenue),
          Icons.attach_money_rounded,
        ),
        _Metric(
          'Activity',
          '${report.activityRate.toStringAsFixed(1)}%',
          Icons.insights_rounded,
        ),
        _Metric('Customers', '${report.uniqueCustomers}', Icons.groups_rounded),
        _Metric(
          'Upcoming',
          '${report.upcomingBookings}',
          Icons.upcoming_rounded,
        ),
      ],
      footer:
          '${report.approvedBookings} of ${AdminWeeklyStadiumReport.weeklySlotCapacity} weekly slots booked',
    );
  }
}

class _ReportPanel extends StatelessWidget {
  const _ReportPanel({
    required this.title,
    required this.subtitle,
    required this.metrics,
    this.footer,
  });
  final String title;
  final String subtitle;
  final List<_Metric> metrics;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: colors.glassFill,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(subtitle, style: const TextStyle(color: Colors.white60)),
          const SizedBox(height: 15),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: metrics.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 2.25,
            ),
            itemBuilder: (_, index) => _MetricTile(metric: metrics[index]),
          ),
          if (footer != null) ...[
            const SizedBox(height: 13),
            Text(
              footer!,
              style: TextStyle(
                color: colors.selection,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Metric {
  const _Metric(this.label, this.value, this.icon);
  final String label;
  final String value;
  final IconData icon;
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.metric});
  final _Metric metric;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .045),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(11),
        child: Row(
          children: [
            Icon(metric.icon, color: Colors.white70, size: 20),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    metric.value,
                    maxLines: 1,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    metric.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
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

class _ActivityLine extends StatelessWidget {
  const _ActivityLine({required this.report});
  final AdminWeeklyStadiumReport report;

  @override
  Widget build(BuildContext context) {
    return Text(
      '${report.approvedBookings} this week · ${report.activityRate.toStringAsFixed(1)}% active',
      style: TextStyle(
        color: context.appColors.selection,
        fontWeight: FontWeight.w800,
        fontSize: 12,
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: Colors.white,
      fontSize: 17,
      fontWeight: FontWeight.w900,
    ),
  );
}

String _money(double value) => '\$${value.toStringAsFixed(2)}';

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.booking});
  final AdminStadiumBookingEntry booking;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: colors.glassFill,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.glassBorder),
      ),
      child: Row(
        children: [
          const CircleAvatar(child: Icon(Icons.person_rounded)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  booking.userName.trim().isEmpty
                      ? 'Unknown user'
                      : booking.userName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${_adminDateLabel(booking.dayDate)} at ${booking.slotTime}',
                  style: TextStyle(color: Colors.white.withValues(alpha: .65)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Status extends StatelessWidget {
  const _Status({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onRetry,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white70, size: 42),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white60),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onRetry, child: const Text('Try again')),
            ],
          ],
        ),
      ),
    );
  }
}

String _adminDateLabel(String value) {
  final date = DateTime.tryParse(value);
  if (date == null) return value;
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}
