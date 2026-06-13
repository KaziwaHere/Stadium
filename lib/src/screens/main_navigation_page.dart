import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:stadium/src/screens/bookings_page.dart';
import 'package:stadium/src/screens/profile_page.dart';
import 'package:stadium/src/screens/stadium_home_page.dart';
import 'package:stadium/src/theme/app_theme.dart';

class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({super.key});

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  int _selectedIndex = 0;

  static const _pages = [StadiumHomePage(), BookingsPage(), ProfilePage()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          IndexedStack(index: _selectedIndex, children: _pages),
          Positioned(
            left: 22,
            right: 22,
            bottom: 18,
            child: _GlassBottomNavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) {
                setState(() => _selectedIndex = index);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassBottomNavigationBar extends StatelessWidget {
  const _GlassBottomNavigationBar({
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return SafeArea(
      minimum: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            height: 58,
            decoration: BoxDecoration(
              color: colors.navFill,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: colors.glassBorder),
              boxShadow: [
                BoxShadow(
                  color: colors.shadow,
                  blurRadius: 22,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Row(
              children: [
                _NavItem(
                  icon: Icons.home_rounded,
                  label: 'Home',
                  isSelected: selectedIndex == 0,
                  onTap: () => onDestinationSelected(0),
                ),
                _NavItem(
                  icon: Icons.confirmation_number_rounded,
                  label: 'Bookings',
                  isSelected: selectedIndex == 1,
                  onTap: () => onDestinationSelected(1),
                ),
                _NavItem(
                  icon: Icons.person_rounded,
                  label: 'Profile',
                  isSelected: selectedIndex == 2,
                  onTap: () => onDestinationSelected(2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final color = isSelected
        ? colors.action
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: .58);

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? colors.activeNavFill
                : const Color.fromARGB(0, 231, 18, 18),
            borderRadius: BorderRadius.circular(17),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 21),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
