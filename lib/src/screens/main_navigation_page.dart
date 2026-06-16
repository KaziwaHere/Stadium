import 'dart:ui';

import 'package:appwrite/models.dart' as models;
import 'package:flutter/material.dart';
import 'package:stadium/src/screens/bookings_page.dart';
import 'package:stadium/src/screens/profile_page.dart';
import 'package:stadium/src/screens/stadium_home_page.dart';
import 'package:stadium/src/services/favorite_service.dart';
import 'package:stadium/src/theme/app_theme.dart';

class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({
    super.key,
    required this.user,
    required this.onSignedOut,
    this.favoritesRepository,
  });

  final models.User user;
  final VoidCallback onSignedOut;
  final FavoritesRepository? favoritesRepository;

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  int _selectedIndex = 0;
  final ValueNotifier<int> _favoritesVersion = ValueNotifier<int>(0);

  @override
  void dispose() {
    _favoritesVersion.dispose();
    super.dispose();
  }

  void _notifyFavoritesChanged() {
    _favoritesVersion.value++;
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      StadiumHomePage(
        user: widget.user,
        favoritesRepository: widget.favoritesRepository,
        favoritesVersion: _favoritesVersion,
        onFavoritesChanged: _notifyFavoritesChanged,
      ),
      BookingsPage(
        user: widget.user,
        favoritesRepository: widget.favoritesRepository,
        favoritesVersion: _favoritesVersion,
        onFavoritesChanged: _notifyFavoritesChanged,
      ),
      ProfilePage(user: widget.user, onSignedOut: widget.onSignedOut),
    ];

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          _AnimatedTabView(selectedIndex: _selectedIndex, pages: pages),
          Positioned(
            left: 22,
            right: 22,
            bottom: 18,
            child: _GlassBottomNavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) {
                if (index == _selectedIndex) return;

                setState(() => _selectedIndex = index);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedTabView extends StatelessWidget {
  const _AnimatedTabView({required this.selectedIndex, required this.pages});

  final int selectedIndex;
  final List<Widget> pages;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        for (var index = 0; index < pages.length; index++)
          _AnimatedTabPage(
            isSelected: selectedIndex == index,
            slideOffset: Offset(index < selectedIndex ? -0.035 : 0.035, 0),
            child: pages[index],
          ),
      ],
    );
  }
}

class _AnimatedTabPage extends StatelessWidget {
  const _AnimatedTabPage({
    required this.isSelected,
    required this.slideOffset,
    required this.child,
  });

  final bool isSelected;
  final Offset slideOffset;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    const duration = Duration(milliseconds: 280);
    const curve = Curves.easeOutCubic;

    return IgnorePointer(
      ignoring: !isSelected,
      child: AnimatedOpacity(
        opacity: isSelected ? 1 : 0,
        duration: duration,
        curve: curve,
        child: AnimatedSlide(
          offset: isSelected ? Offset.zero : slideOffset,
          duration: duration,
          curve: curve,
          child: child,
        ),
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                const itemCount = 3;
                const horizontalMargin = 5.0;
                const verticalMargin = 6.0;
                final itemWidth = constraints.maxWidth / itemCount;

                return Stack(
                  children: [
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                      left: (itemWidth * selectedIndex) + horizontalMargin,
                      top: verticalMargin,
                      bottom: verticalMargin,
                      width: itemWidth - (horizontalMargin * 2),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.activeNavFill,
                          borderRadius: BorderRadius.circular(17),
                        ),
                      ),
                    ),
                    Row(
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
                  ],
                );
              },
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
    const duration = Duration(milliseconds: 240);
    const curve = Curves.easeOutCubic;
    final inactiveColor = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: .58);
    final color = isSelected ? colors.selection : inactiveColor;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween<double>(end: isSelected ? 1 : 0),
                duration: duration,
                curve: curve,
                builder: (context, value, child) {
                  return Transform.translate(
                    offset: Offset(0, -value),
                    child: Transform.scale(
                      scale: 1 + (value * .08),
                      child: Icon(
                        icon,
                        color: Color.lerp(
                          inactiveColor,
                          colors.selection,
                          value,
                        ),
                        size: 21,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 2),
              AnimatedDefaultTextStyle(
                duration: duration,
                curve: curve,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
