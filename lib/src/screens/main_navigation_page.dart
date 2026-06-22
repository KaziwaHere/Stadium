import 'dart:ui';

import 'package:appwrite/models.dart' as models;
import 'package:flutter/material.dart';
import 'package:stadium/src/screens/bookings_page.dart';
import 'package:stadium/src/screens/profile_page.dart';
import 'package:stadium/src/screens/stadium_home_page.dart';
import 'package:stadium/src/services/booking_service.dart';
import 'package:stadium/src/services/favorite_service.dart';
import 'package:stadium/src/theme/app_theme.dart';

class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({
    super.key,
    required this.user,
    required this.onSignedOut,
    this.bookingsRepository,
    this.favoritesRepository,
  });

  final models.User user;
  final VoidCallback onSignedOut;
  final BookingsRepository? bookingsRepository;
  final FavoritesRepository? favoritesRepository;

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  int _selectedIndex = 0;
  final ValueNotifier<int> _bookingsVersion = ValueNotifier<int>(0);
  final ValueNotifier<int> _favoritesVersion = ValueNotifier<int>(0);

  @override
  void dispose() {
    _bookingsVersion.dispose();
    _favoritesVersion.dispose();
    super.dispose();
  }

  void _notifyBookingsChanged() {
    _bookingsVersion.value++;
  }

  void _notifyFavoritesChanged() {
    _favoritesVersion.value++;
  }

  @override
  Widget build(BuildContext context) {
    final destinations = _destinations;
    final pages = destinations.map((destination) => destination.page).toList();

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
              destinations: destinations,
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

  List<_NavigationDestination> get _destinations {
    return [
      _NavigationDestination(
        icon: Icons.home_rounded,
        label: 'Home',
        page: StadiumHomePage(
          user: widget.user,
          bookingsRepository: widget.bookingsRepository,
          favoritesRepository: widget.favoritesRepository,
          favoritesVersion: _favoritesVersion,
          onBookingsChanged: _notifyBookingsChanged,
          onFavoritesChanged: _notifyFavoritesChanged,
        ),
      ),
      _NavigationDestination(
        icon: Icons.confirmation_number_rounded,
        label: 'Bookings',
        page: BookingsPage(
          user: widget.user,
          bookingsRepository: widget.bookingsRepository,
          favoritesRepository: widget.favoritesRepository,
          bookingsVersion: _bookingsVersion,
          favoritesVersion: _favoritesVersion,
          onBookingsChanged: _notifyBookingsChanged,
          onFavoritesChanged: _notifyFavoritesChanged,
        ),
      ),
      _NavigationDestination(
        icon: Icons.person_rounded,
        label: 'Profile',
        page: ProfilePage(user: widget.user, onSignedOut: widget.onSignedOut),
      ),
    ];
  }
}

class _NavigationDestination {
  const _NavigationDestination({
    required this.icon,
    required this.label,
    required this.page,
  });

  final IconData icon;
  final String label;
  final Widget page;
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
    required this.destinations,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final List<_NavigationDestination> destinations;
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
                const horizontalMargin = 5.0;
                const verticalMargin = 6.0;
                final itemWidth = constraints.maxWidth / destinations.length;

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
                        for (
                          var index = 0;
                          index < destinations.length;
                          index++
                        )
                          _NavItem(
                            icon: destinations[index].icon,
                            label: destinations[index].label,
                            isSelected: selectedIndex == index,
                            onTap: () => onDestinationSelected(index),
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
