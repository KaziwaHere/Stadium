import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:appwrite/models.dart' as models;
import 'package:stadium/src/data/stadium_data.dart';
import 'package:stadium/src/models/stadium.dart';
import 'package:stadium/src/screens/stadium_booking_page.dart';
import 'package:stadium/src/services/booking_service.dart';
import 'package:stadium/src/services/favorite_service.dart';
import 'package:stadium/src/theme/app_theme.dart';
import 'package:stadium/src/widgets/app_notification.dart';

class StadiumHomePage extends StatefulWidget {
  const StadiumHomePage({
    super.key,
    required this.user,
    this.bookingsRepository,
    this.favoritesRepository,
    this.favoritesVersion,
    this.onBookingsChanged,
    this.onFavoritesChanged,
  });

  final models.User user;
  final BookingsRepository? bookingsRepository;
  final FavoritesRepository? favoritesRepository;
  final ValueListenable<int>? favoritesVersion;
  final VoidCallback? onBookingsChanged;
  final VoidCallback? onFavoritesChanged;

  @override
  State<StadiumHomePage> createState() => _StadiumHomePageState();
}

class _StadiumHomePageState extends State<StadiumHomePage> {
  late Future<Set<String>> _favoriteIdsFuture;
  final TextEditingController _searchController = TextEditingController();
  Set<String> _favoriteIds = {};
  final Set<String> _updatingFavoriteIds = {};
  String _searchQuery = '';

  FavoritesRepository get _favoritesRepository =>
      widget.favoritesRepository ?? favoriteService;

  @override
  void initState() {
    super.initState();
    _favoriteIdsFuture = _loadFavoriteIds();
    widget.favoritesVersion?.addListener(_handleFavoritesChanged);
  }

  @override
  void didUpdateWidget(StadiumHomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.favoritesVersion == widget.favoritesVersion) return;

    oldWidget.favoritesVersion?.removeListener(_handleFavoritesChanged);
    widget.favoritesVersion?.addListener(_handleFavoritesChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    widget.favoritesVersion?.removeListener(_handleFavoritesChanged);
    super.dispose();
  }

  Future<Set<String>> _loadFavoriteIds() async {
    final ids = await _favoritesRepository.favoriteStadiumIds(widget.user.$id);
    _favoriteIds = ids;
    return ids;
  }

  void _handleFavoritesChanged() {
    final favoriteIdsFuture = _loadFavoriteIds();
    setState(() {
      _favoriteIdsFuture = favoriteIdsFuture;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final filteredStadiums = _filteredStadiums;
    final isSearching = _searchQuery.trim().isNotEmpty;

    return FutureBuilder<Set<String>>(
      future: _favoriteIdsFuture,
      builder: (context, snapshot) {
        return Scaffold(
          body: Stack(
            children: [
              const _AmbientBackground(),
              SafeArea(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () => FocusScope.of(context).unfocus(),
                  child: CustomScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                        sliver: SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _TopBar(),
                              const SizedBox(height: 24),
                              const SizedBox(height: 10),
                              const SizedBox(height: 22),
                              _SearchPanel(
                                controller: _searchController,
                                onChanged: _handleSearchChanged,
                                onClear: _clearSearch,
                              ),
                              const SizedBox(height: 26),
                              if (!isSearching) ...[
                                const _SectionHeader(
                                  title: 'Featured stadium',
                                  action: 'View all',
                                ),
                                const SizedBox(height: 14),
                                _FeaturedStadium(
                                  stadium: stadiums.first,
                                  gradient: colors.stadiumGradients.first,
                                  isHearted: _isHearted(stadiums.first),
                                  isUpdating: _isUpdating(stadiums.first),
                                  onHeart: () =>
                                      _toggleFavorite(stadiums.first),
                                  onBook: () => _openBookingPage(
                                    context,
                                    stadiums.first,
                                    colors.stadiumGradients.first,
                                  ),
                                ),
                                const SizedBox(height: 28),
                              ],
                              _SectionHeader(
                                title: isSearching
                                    ? 'Search results'
                                    : 'Available near you',
                                action: isSearching
                                    ? '${filteredStadiums.length} found'
                                    : 'Map',
                              ),
                              const SizedBox(height: 14),
                            ],
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 110),
                        sliver: filteredStadiums.isEmpty
                            ? SliverToBoxAdapter(
                                child: _EmptySearchResult(query: _searchQuery),
                              )
                            : SliverList.separated(
                                itemBuilder: (context, index) {
                                  final stadium = filteredStadiums[index];
                                  return _StadiumCard(
                                    stadium: stadium,
                                    gradient:
                                        colors.stadiumGradients[index %
                                            colors.stadiumGradients.length],
                                    isHearted: _isHearted(stadium),
                                    isUpdating: _isUpdating(stadium),
                                    onHeart: () => _toggleFavorite(stadium),
                                    onTap: () => _openBookingPage(
                                      context,
                                      stadium,
                                      colors.stadiumGradients[index %
                                          colors.stadiumGradients.length],
                                    ),
                                  );
                                },
                                separatorBuilder: (context, index) =>
                                    const SizedBox(height: 14),
                                itemCount: filteredStadiums.length,
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  bool _isHearted(Stadium stadium) => _favoriteIds.contains(stadium.id);

  bool _isUpdating(Stadium stadium) =>
      _updatingFavoriteIds.contains(stadium.id);

  List<Stadium> get _filteredStadiums {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return stadiums;

    return stadiums.where((stadium) {
      return stadium.name.toLowerCase().contains(query) ||
          stadium.location.toLowerCase().contains(query) ||
          stadium.available.toLowerCase().contains(query) ||
          stadium.price.toString().contains(query);
    }).toList();
  }

  void _handleSearchChanged(String value) {
    setState(() => _searchQuery = value);
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _searchQuery = '');
  }

  Future<void> _toggleFavorite(Stadium stadium) async {
    if (_updatingFavoriteIds.contains(stadium.id)) return;

    final wasHearted = _favoriteIds.contains(stadium.id);

    setState(() {
      _updatingFavoriteIds.add(stadium.id);
      if (wasHearted) {
        _favoriteIds.remove(stadium.id);
      } else {
        _favoriteIds.add(stadium.id);
      }
    });

    try {
      if (wasHearted) {
        await _favoritesRepository.removeFavorite(
          userId: widget.user.$id,
          stadiumId: stadium.id,
        );
      } else {
        await _favoritesRepository.addFavorite(
          userId: widget.user.$id,
          stadium: stadium,
        );
      }
      widget.onFavoritesChanged?.call();
      if (!mounted) return;

      showAppNotification(
        context,
        title: wasHearted ? 'Removed from hearted' : 'Stadium hearted',
        message: wasHearted
            ? '${stadium.name} was removed from your hearted stadiums.'
            : '${stadium.name} was added to your hearted stadiums.',
        type: AppNotificationType.success,
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        if (wasHearted) {
          _favoriteIds.add(stadium.id);
        } else {
          _favoriteIds.remove(stadium.id);
        }
      });

      showAppNotification(
        context,
        title: 'Heart update failed',
        message: wasHearted
            ? 'Could not remove ${stadium.name} from hearted stadiums.'
            : 'Could not heart ${stadium.name}.',
        type: AppNotificationType.error,
      );
    } finally {
      if (mounted) {
        setState(() => _updatingFavoriteIds.remove(stadium.id));
      }
    }
  }

  Future<void> _openBookingPage(
    BuildContext context,
    Stadium stadium,
    List<Color> gradient,
  ) async {
    final isHearted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => StadiumBookingPage(
          stadium: stadium,
          gradient: gradient,
          user: widget.user,
          isHearted: _isHearted(stadium),
          bookingsRepository: widget.bookingsRepository,
          favoritesRepository: _favoritesRepository,
          onBookingCreated: widget.onBookingsChanged,
        ),
      ),
    );

    if (!mounted || isHearted == null) return;

    setState(() {
      if (isHearted) {
        _favoriteIds.add(stadium.id);
      } else {
        _favoriteIds.remove(stadium.id);
      }
    });
    widget.onFavoritesChanged?.call();
  }
}

class _AmbientBackground extends StatelessWidget {
  const _AmbientBackground();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors.backgroundGradient,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -90,
            left: -70,
            child: _Glow(size: 230, color: colors.ambientGlows[0]),
          ),
          Positioned(
            right: -100,
            top: 210,
            child: _Glow(size: 260, color: colors.ambientGlows[1]),
          ),
          Positioned(
            left: 60,
            bottom: -130,
            child: _Glow(size: 300, color: colors.ambientGlows[2]),
          ),
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [BoxShadow(color: color, blurRadius: 90, spreadRadius: 35)],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Row(
      children: [
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'Stadium',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontFamily: 'Roboto',
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Container(
                    width: 7,
                    height: 7,
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: colors.action,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                TextSpan(
                  text: 'Baghdad',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white.withValues(alpha: .72),
                    fontFamily: 'Roboto',
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const _GlassIconButton(icon: Icons.notifications_rounded),
      ],
    );
  }
}

class _SearchPanel extends StatelessWidget {
  const _SearchPanel({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return GlassContainer(
      borderRadius: 28,
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Icon(Icons.search_rounded, color: colors.mutedIcon),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: controller,
                  onChanged: onChanged,
                  textInputAction: TextInputAction.search,
                  cursorColor: colors.selection,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: 'Search stadium name or area',
                    hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: .58),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (context, value, child) {
                  if (value.text.isEmpty) return const SizedBox.shrink();
                  return _ClearSearchButton(onTap: onClear);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ClearSearchButton extends StatelessWidget {
  const _ClearSearchButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.glassBorder),
        ),
        child: Icon(
          Icons.close_rounded,
          color: Colors.white.withValues(alpha: .8),
        ),
      ),
    );
  }
}

class _EmptySearchResult extends StatelessWidget {
  const _EmptySearchResult({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return GlassContainer(
      borderRadius: 24,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: colors.glassFill,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: colors.glassBorder),
            ),
            child: Icon(
              Icons.search_off_rounded,
              color: Colors.white.withValues(alpha: .74),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No stadiums found',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'No results for "$query". Try another name or area.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .58),
                    height: 1.3,
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

class _QuickFilter extends StatelessWidget {
  const _QuickFilter({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: .09)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: Colors.white.withValues(alpha: .78)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Colors.white.withValues(alpha: .82),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.action});

  final String title;
  final String action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
        Text(
          action,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Colors.white.withValues(alpha: .72),
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _FeaturedStadium extends StatelessWidget {
  const _FeaturedStadium({
    required this.stadium,
    required this.gradient,
    required this.isHearted,
    required this.isUpdating,
    required this.onHeart,
    required this.onBook,
  });

  final Stadium stadium;
  final List<Color> gradient;
  final bool isHearted;
  final bool isUpdating;
  final VoidCallback onHeart;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return GlassContainer(
      borderRadius: 30,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 190,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradient,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: gradient.last.withValues(alpha: .28),
                  blurRadius: 28,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -18,
                  bottom: -22,
                  child: Icon(
                    stadium.icon,
                    size: 158,
                    color: Colors.white.withValues(alpha: .13),
                  ),
                ),
                Positioned(
                  left: 18,
                  top: 18,
                  child: _Pill(
                    icon: Icons.star_rounded,
                    label: '${stadium.rating} top rated',
                  ),
                ),
                Positioned(
                  right: 14,
                  top: 14,
                  child: _HeartButton(
                    isHearted: isHearted,
                    isUpdating: isUpdating,
                    onTap: onHeart,
                  ),
                ),
                Positioned(
                  left: 18,
                  right: 18,
                  bottom: 18,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              stadium.name,
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              stadium.location,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: .72),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _PriceBadge(price: stadium.price),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colors.action,
                foregroundColor: colors.onAction,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              onPressed: onBook,
              child: const Text(
                'Book now',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StadiumCard extends StatelessWidget {
  const _StadiumCard({
    required this.stadium,
    required this.gradient,
    required this.isHearted,
    required this.isUpdating,
    required this.onHeart,
    required this.onTap,
  });

  final Stadium stadium;
  final List<Color> gradient;
  final bool isHearted;
  final bool isUpdating;
  final VoidCallback onHeart;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassContainer(
        borderRadius: 24,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 88,
              height: 96,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: gradient),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                stadium.icon,
                size: 42,
                color: Colors.white.withValues(alpha: .86),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stadium.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    stadium.location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .55),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _MiniMeta(
                        icon: Icons.star_rounded,
                        label: stadium.rating.toString(),
                      ),
                      _MiniMeta(
                        icon: Icons.access_time_rounded,
                        label: stadium.available,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\$${stadium.price}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  '/ hour',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .46),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),
                _HeartButton(
                  isHearted: isHearted,
                  isUpdating: isUpdating,
                  onTap: onHeart,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HeartButton extends StatelessWidget {
  const _HeartButton({
    required this.isHearted,
    required this.isUpdating,
    required this.onTap,
  });

  final bool isHearted;
  final bool isUpdating;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return GestureDetector(
      onTap: isUpdating ? null : onTap,
      child: GlassContainer(
        borderRadius: 16,
        padding: EdgeInsets.zero,
        child: SizedBox(
          width: 46,
          height: 46,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            child: isUpdating
                ? SizedBox(
                    key: const ValueKey('heartLoading'),
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        colors.selection,
                      ),
                    ),
                  )
                : Icon(
                    key: ValueKey(isHearted),
                    isHearted
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: isHearted
                        ? colors.action
                        : Colors.white.withValues(alpha: .86),
                    size: 22,
                  ),
          ),
        ),
      ),
    );
  }
}

class _MiniMeta extends StatelessWidget {
  const _MiniMeta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: colors.mutedIcon, size: 15),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: .68),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: colors.glassFill,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: .2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: colors.star, size: 16),
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PriceBadge extends StatelessWidget {
  const _PriceBadge({required this.price});

  final int price;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: .16)),
      ),
      child: Column(
        children: [
          Text(
            '\$$price',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          Text(
            'hour',
            style: TextStyle(
              color: Colors.white.withValues(alpha: .62),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: 16,
      padding: EdgeInsets.zero,
      child: SizedBox(
        width: 46,
        height: 46,
        child: Icon(icon, color: Colors.white.withValues(alpha: .86), size: 22),
      ),
    );
  }
}

class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.borderRadius = 24,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: colors.glassFill,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: colors.glassBorder),
            boxShadow: [
              BoxShadow(
                color: colors.shadow,
                blurRadius: 30,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
