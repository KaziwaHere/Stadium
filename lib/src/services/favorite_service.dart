import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:flutter/material.dart';
import 'package:stadium/src/appwrite_client.dart';
import 'package:stadium/src/models/stadium.dart';

abstract class FavoritesRepository {
  Future<List<FavoriteStadium>> listFavorites(String userId);

  Future<Set<String>> favoriteStadiumIds(String userId);

  Future<FavoriteStadium> addFavorite({
    required String userId,
    required Stadium stadium,
  });

  Future<void> removeFavorite({
    required String userId,
    required String stadiumId,
  });

  Future<void> removeFavoriteRow({required String rowId});
}

class FavoriteService implements FavoritesRepository {
  FavoriteService(this._tables);

  static const databaseId = 'stadium_booking';
  static const tableId = 'favorites';
  static const _cacheTtl = Duration(minutes: 3);

  final TablesDB _tables;
  final Map<String, _CacheEntry<List<FavoriteStadium>>> _favoritesCache = {};
  final Map<String, Future<List<FavoriteStadium>>> _favoritesRequests = {};

  @override
  Future<List<FavoriteStadium>> listFavorites(String userId) async {
    final cached = _freshCachedFavorites(userId);
    if (cached != null) return cached;

    final existingRequest = _favoritesRequests[userId];
    if (existingRequest != null) return existingRequest;

    final request = _fetchFavorites(userId);
    _favoritesRequests[userId] = request;

    try {
      final favorites = await request;
      _favoritesCache[userId] = _CacheEntry(favorites);
      return favorites;
    } finally {
      _favoritesRequests.remove(userId);
    }
  }

  Future<List<FavoriteStadium>> _fetchFavorites(String userId) async {
    final rows = await _tables.listRows(
      databaseId: databaseId,
      tableId: tableId,
      queries: [Query.equal('userId', userId), Query.orderDesc(r'$createdAt')],
    );

    return rows.rows.map(FavoriteStadium.fromRow).toList();
  }

  @override
  Future<Set<String>> favoriteStadiumIds(String userId) async {
    final favorites = await listFavorites(userId);
    return favorites.map((favorite) => favorite.stadiumId).toSet();
  }

  @override
  Future<FavoriteStadium> addFavorite({
    required String userId,
    required Stadium stadium,
  }) async {
    final existing = await _favoriteForStadium(
      userId: userId,
      stadiumId: stadium.id,
    );

    if (existing != null) return existing;

    final row = await _tables.createRow(
      databaseId: databaseId,
      tableId: tableId,
      rowId: ID.unique(),
      data: {
        'userId': userId,
        'stadiumId': stadium.id,
        'name': stadium.name,
        'location': stadium.location,
        'rating': stadium.rating,
        'price': stadium.price,
        'available': stadium.available,
        'icon': stadium.iconKey,
        if (stadium.imageFileId != null) 'imageFileId': stadium.imageFileId,
      },
      permissions: [
        Permission.read(Role.user(userId)),
        Permission.update(Role.user(userId)),
        Permission.delete(Role.user(userId)),
      ],
    );

    final favorite = FavoriteStadium.fromRow(row);
    _appendCachedFavorite(userId, favorite);
    return favorite;
  }

  @override
  Future<void> removeFavorite({
    required String userId,
    required String stadiumId,
  }) async {
    final favorite = await _favoriteForStadium(
      userId: userId,
      stadiumId: stadiumId,
    );

    if (favorite == null) return;

    await _tables.deleteRow(
      databaseId: databaseId,
      tableId: tableId,
      rowId: favorite.rowId,
    );
    _removeCachedFavorite(
      userId: userId,
      rowId: favorite.rowId,
      stadiumId: favorite.stadiumId,
    );
  }

  @override
  Future<void> removeFavoriteRow({required String rowId}) async {
    await _tables.deleteRow(
      databaseId: databaseId,
      tableId: tableId,
      rowId: rowId,
    );
    _removeCachedFavorite(rowId: rowId);
  }

  Future<FavoriteStadium?> _favoriteForStadium({
    required String userId,
    required String stadiumId,
  }) async {
    final cached = _freshCachedFavorites(userId);
    if (cached != null) {
      for (final favorite in cached) {
        if (favorite.stadiumId == stadiumId) return favorite;
      }
      return null;
    }

    final rows = await _tables.listRows(
      databaseId: databaseId,
      tableId: tableId,
      queries: [
        Query.equal('userId', userId),
        Query.equal('stadiumId', stadiumId),
        Query.limit(1),
      ],
    );

    if (rows.rows.isEmpty) return null;
    return FavoriteStadium.fromRow(rows.rows.first);
  }

  List<FavoriteStadium>? _freshCachedFavorites(String userId) {
    final cached = _favoritesCache[userId];
    if (cached == null || cached.isExpired(_cacheTtl)) return null;
    return List<FavoriteStadium>.of(cached.value);
  }

  void _appendCachedFavorite(String userId, FavoriteStadium favorite) {
    final cached = _favoritesCache[userId];
    if (cached == null || cached.isExpired(_cacheTtl)) return;

    final favorites = [
      favorite,
      ...cached.value.where((item) => item.stadiumId != favorite.stadiumId),
    ];
    _favoritesCache[userId] = _CacheEntry(favorites);
  }

  void _removeCachedFavorite({
    String? userId,
    required String rowId,
    String? stadiumId,
  }) {
    List<MapEntry<String, _CacheEntry<List<FavoriteStadium>>>> entries =
        _favoritesCache.entries.toList();
    if (userId != null) {
      final entry = _favoritesCache[userId];
      entries = entry == null ? const [] : [MapEntry(userId, entry)];
    }

    for (final entry in entries) {
      final favorites = entry.value.value.where((favorite) {
        final rowMatches = favorite.rowId == rowId;
        final stadiumMatches =
            stadiumId != null && favorite.stadiumId == stadiumId;
        return !rowMatches && !stadiumMatches;
      }).toList();
      _favoritesCache[entry.key] = _CacheEntry(favorites);
    }
  }
}

class _CacheEntry<T> {
  _CacheEntry(this.value) : createdAt = DateTime.now();

  final T value;
  final DateTime createdAt;

  bool isExpired(Duration ttl) => DateTime.now().difference(createdAt) > ttl;
}

class FavoriteStadium {
  const FavoriteStadium({
    required this.rowId,
    required this.stadiumId,
    required this.name,
    required this.location,
    required this.rating,
    required this.price,
    required this.available,
    required this.iconKey,
    this.imageFileId,
  });

  factory FavoriteStadium.fromRow(models.Row row) {
    final data = row.data;

    return FavoriteStadium(
      rowId: row.$id,
      stadiumId: data['stadiumId'].toString(),
      name: data['name'].toString(),
      location: data['location'].toString(),
      rating: (data['rating'] as num).toDouble(),
      price: (data['price'] as num).toInt(),
      available: data['available'].toString(),
      iconKey: data['icon'].toString(),
      imageFileId: _optionalImageFileId(data['imageFileId']),
    );
  }

  final String rowId;
  final String stadiumId;
  final String name;
  final String location;
  final double rating;
  final int price;
  final String available;
  final String iconKey;
  final String? imageFileId;

  IconData get icon => stadiumIconFromKey(iconKey);
}

String? _optionalImageFileId(dynamic value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

final FavoritesRepository favoriteService = FavoriteService(TablesDB(client));
