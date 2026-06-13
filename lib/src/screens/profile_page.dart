import 'package:flutter/material.dart';
import 'package:stadium/src/theme/app_theme.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

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
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 110),
            children: [
              Row(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: colors.glassFill,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: colors.glassBorder),
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      color: Colors.white,
                      size: 34,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Profile',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Manage your account and booking preferences.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: .6),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              const _ProfileOption(
                icon: Icons.account_circle_rounded,
                title: 'Personal details',
                subtitle: 'Name, phone number, and location',
              ),
              const SizedBox(height: 12),
              const _ProfileOption(
                icon: Icons.payments_rounded,
                title: 'Payment methods',
                subtitle: 'Cards and wallet settings',
              ),
              const SizedBox(height: 12),
              const _ProfileOption(
                icon: Icons.notifications_rounded,
                title: 'Notifications',
                subtitle: 'Booking alerts and reminders',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileOption extends StatelessWidget {
  const _ProfileOption({
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.glassFill,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.glassBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colors.glassFill,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: Colors.white.withValues(alpha: .82)),
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
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.white.withValues(alpha: .56)),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: Colors.white.withValues(alpha: .42),
          ),
        ],
      ),
    );
  }
}
