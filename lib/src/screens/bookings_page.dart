import 'package:appwrite/models.dart' as models;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:stadium/src/data/stadium_data.dart';
import 'package:stadium/src/models/stadium.dart';
import 'package:stadium/src/screens/stadium_booking_page.dart';
import 'package:stadium/src/services/favorite_service.dart';
import 'package:stadium/src/theme/app_theme.dart';

class BookingsPage extends StatefulWidget {
  const BookingsPage({
    super.key,
    required this.user,
    this.favoritesRepository,
    this.favoritesVersion,
    this.onFavoritesChanged,
  });

  final models.User user;
  final FavoritesRepository? favoritesRepository;
  final ValueListenable<int>? favoritesVersion;
  final VoidCallback? onFavoritesChanged;

  @override
  State<BookingsPage> createState() => _BookingsPageState();
}

class _BookingsPageState extends State<BookingsPage> {
  int _selectedSection = 0;
  late Future<List<FavoriteStadium>> _favoritesFuture;
  bool _ignoreNextFavoritesChange = false;

  FavoritesRepository get _favoritesRepository =>
      widget.favoritesRepository ?? favoriteService;

  @override
  void initState() {
    super.initState();
    _favoritesFuture = _loadFavorites();
    widget.favoritesVersion?.addListener(_handleFavoritesChanged);
  }

  @override
  void didUpdateWidget(BookingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.favoritesVersion == widget.favoritesVersion) return;

    oldWidget.favoritesVersion?.removeListener(_handleFavoritesChanged);
    widget.favoritesVersion?.addListener(_handleFavoritesChanged);
  }

  @override
  void dispose() {
    widget.favoritesVersion?.removeListener(_handleFavoritesChanged);
    super.dispose();
  }

  Future<List<FavoriteStadium>> _loadFavorites() {
    return _favoritesRepository.listFavorites(widget.user.$id);
  }

  @override
  Widget build(BuildContext context) {
    return _BookingsFrame(
      title: 'My Bookings',
      subtitle: 'Your reserved stadium slots will appear here.',
      selectedSection: _selectedSection,
      favoritesFuture: _favoritesFuture,
      onOpenFavorite: (favorite, index) =>
          _openFavorite(context, favorite, index),
      onRemoveFavorite: _removeFavorite,
      onSectionChanged: (index) {
        setState(() {
          _selectedSection = index;
          if (index == 1) {
            _favoritesFuture = _loadFavorites();
          }
        });
      },
    );
  }

  void _refreshFavorites() {
    final favoritesFuture = _loadFavorites();
    setState(() {
      _favoritesFuture = favoritesFuture;
    });
  }

  void _handleFavoritesChanged() {
    if (_ignoreNextFavoritesChange) {
      _ignoreNextFavoritesChange = false;
      return;
    }

    if (_selectedSection == 1) {
      _refreshFavorites();
    }
  }

  Future<void> _openFavorite(
    BuildContext context,
    FavoriteStadium favorite,
    int index,
  ) async {
    final stadium = _stadiumFromFavorite(favorite);
    final colors = context.appColors;
    final isHearted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => StadiumBookingPage(
          stadium: stadium,
          gradient:
              colors.stadiumGradients[index % colors.stadiumGradients.length],
          user: widget.user,
          isHearted: true,
          favoriteRowId: favorite.rowId,
          favoritesRepository: _favoritesRepository,
        ),
      ),
    );

    if (isHearted == false) {
      _refreshFavorites();
      _ignoreNextFavoritesChange = true;
      widget.onFavoritesChanged?.call();
    }
  }

  Future<void> _removeFavorite(FavoriteStadium favorite) async {
    try {
      await _favoritesRepository.removeFavoriteRow(rowId: favorite.rowId);
      setState(() {
        _favoritesFuture = _favoritesFuture.then(
          (favorites) =>
              favorites.where((item) => item.rowId != favorite.rowId).toList(),
        );
      });
      _ignoreNextFavoritesChange = true;
      widget.onFavoritesChanged?.call();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not remove ${favorite.name} from hearted stadiums.',
          ),
        ),
      );
    }
  }

  Stadium _stadiumFromFavorite(FavoriteStadium favorite) {
    for (final stadium in stadiums) {
      if (stadium.id == favorite.stadiumId) return stadium;
    }

    return Stadium(
      id: favorite.stadiumId,
      name: favorite.name,
      location: favorite.location,
      rating: favorite.rating,
      price: favorite.price,
      available: favorite.available,
      iconKey: favorite.iconKey,
      icon: favorite.icon,
      days: const [],
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
  const _HeartedStadiumsSection({
    required this.favoritesFuture,
    required this.onOpen,
    required this.onRemove,
  });

  final Future<List<FavoriteStadium>> favoritesFuture;
  final void Function(FavoriteStadium favorite, int index) onOpen;
  final ValueChanged<FavoriteStadium> onRemove;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<FavoriteStadium>>(
      future: favoritesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _HeartedStatusCard(
            icon: Icons.favorite_rounded,
            title: 'Loading hearted stadiums',
            subtitle: 'Fetching your saved stadiums.',
          );
        }

        if (snapshot.hasError) {
          return const _HeartedStatusCard(
            icon: Icons.error_rounded,
            title: 'Could not load hearted stadiums',
            subtitle: 'Check your connection and try again.',
          );
        }

        final favorites = snapshot.data ?? const [];

        if (favorites.isEmpty) {
          return const _HeartedStatusCard(
            icon: Icons.favorite_border_rounded,
            title: 'No hearted stadiums',
            subtitle: 'Tap the heart on a stadium to save it here.',
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < favorites.length; index++) ...[
              _HeartedStadiumCard(
                stadium: favorites[index],
                index: index,
                onTap: () => onOpen(favorites[index], index),
                onRemove: () => onRemove(favorites[index]),
              ),
              if (index != favorites.length - 1) const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }
}

class _HeartedStadiumCard extends StatelessWidget {
  const _HeartedStadiumCard({
    required this.stadium,
    required this.index,
    required this.onTap,
    required this.onRemove,
  });

  final FavoriteStadium stadium;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final gradient =
        colors.stadiumGradients[index % colors.stadiumGradients.length];

    return GestureDetector(
      onTap: onTap,
      child: Container(
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
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .56),
                    ),
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
            IconButton(
              tooltip: 'Remove from hearted',
              onPressed: onRemove,
              style: IconButton.styleFrom(
                foregroundColor: colors.action,
                minimumSize: const Size(42, 42),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(Icons.favorite_rounded, size: 22),
            ),
          ],
        ),
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
                  ? colors.selection
                  : Colors.white.withValues(alpha: .62),
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _BookingsFrame extends StatelessWidget {
  const _BookingsFrame({
    required this.title,
    required this.subtitle,
    required this.selectedSection,
    required this.favoritesFuture,
    required this.onOpenFavorite,
    required this.onRemoveFavorite,
    required this.onSectionChanged,
  });

  final String title;
  final String subtitle;
  final int selectedSection;
  final Future<List<FavoriteStadium>> favoritesFuture;
  final void Function(FavoriteStadium favorite, int index) onOpenFavorite;
  final ValueChanged<FavoriteStadium> onRemoveFavorite;
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
                    : _HeartedStadiumsSection(
                        favoritesFuture: favoritesFuture,
                        onOpen: onOpenFavorite,
                        onRemove: onRemoveFavorite,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeartedStatusCard extends StatelessWidget {
  const _HeartedStatusCard({
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
            child: Icon(icon, color: Colors.white),
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
                const SizedBox(height: 5),
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
