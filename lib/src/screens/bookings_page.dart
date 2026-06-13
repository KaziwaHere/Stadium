import 'package:flutter/material.dart';
import 'package:stadium/src/theme/app_theme.dart';

class BookingsPage extends StatefulWidget {
  const BookingsPage({super.key});

  @override
  State<BookingsPage> createState() => _BookingsPageState();
}

class _BookingsPageState extends State<BookingsPage> {
  int _selectedSection = 0;

  @override
  Widget build(BuildContext context) {
    return _BookingsFrame(
      title: 'My Bookings',
      subtitle: 'Your reserved stadium slots will appear here.',
      selectedSection: _selectedSection,
      onSectionChanged: (index) {
        setState(() => _selectedSection = index);
      },
    );
  }
}

class _BookingPreviewCard extends StatelessWidget {
  const _BookingPreviewCard();

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
            child: const Icon(Icons.stadium_rounded, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No active bookings',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Book a stadium from the home page to track it here.',
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

class _HeartedStadiumsSection extends StatelessWidget {
  const _HeartedStadiumsSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < _heartedStadiums.length; index++) ...[
          _HeartedStadiumCard(stadium: _heartedStadiums[index], index: index),
          if (index != _heartedStadiums.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _HeartedStadiumCard extends StatelessWidget {
  const _HeartedStadiumCard({required this.stadium, required this.index});

  final _HeartedStadium stadium;
  final int index;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final gradient =
        colors.stadiumGradients[index % colors.stadiumGradients.length];

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
                  style: TextStyle(color: Colors.white.withValues(alpha: .56)),
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
          Icon(Icons.favorite_rounded, color: colors.action, size: 22),
        ],
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
      child: Row(
        children: [
          _SegmentButton(
            label: 'Active bookings',
            isSelected: selectedIndex == 0,
            onTap: () => onChanged(0),
          ),
          const SizedBox(width: 6),
          _SegmentButton(
            label: 'Hearted',
            isSelected: selectedIndex == 1,
            onTap: () => onChanged(1),
          ),
        ],
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? colors.activeNavFill : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isSelected
                  ? colors.action
                  : Colors.white.withValues(alpha: .62),
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _HeartedStadium {
  const _HeartedStadium({
    required this.name,
    required this.location,
    required this.rating,
    required this.price,
    required this.icon,
  });

  final String name;
  final String location;
  final double rating;
  final int price;
  final IconData icon;
}

const _heartedStadiums = [
  _HeartedStadium(
    name: 'Emerald Arena',
    location: 'Downtown District',
    rating: 4.9,
    price: 85,
    icon: Icons.stadium_rounded,
  ),
  _HeartedStadium(
    name: 'Northside Pitch',
    location: 'Al Mansour',
    rating: 4.7,
    price: 62,
    icon: Icons.sports_soccer_rounded,
  ),
  _HeartedStadium(
    name: 'The Green Bowl',
    location: 'Riverside Park',
    rating: 4.8,
    price: 110,
    icon: Icons.grass_rounded,
  ),
];

class _BookingsFrame extends StatelessWidget {
  const _BookingsFrame({
    required this.title,
    required this.subtitle,
    required this.selectedSection,
    required this.onSectionChanged,
  });

  final String title;
  final String subtitle;
  final int selectedSection;
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
              Text(
                title,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
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
                duration: const Duration(milliseconds: 180),
                child: selectedSection == 0
                    ? const _BookingPreviewCard()
                    : const _HeartedStadiumsSection(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
