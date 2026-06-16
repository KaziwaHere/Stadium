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

  final TablesDB _tables;

  @override
  Future<List<FavoriteStadium>> listFavorites(String userId) async {
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
      },
      permissions: [
        Permission.read(Role.user(userId)),
        Permission.update(Role.user(userId)),
        Permission.delete(Role.user(userId)),
      ],
    );

    return FavoriteStadium.fromRow(row);
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
  }

  @override
  Future<void> removeFavoriteRow({required String rowId}) {
    return _tables.deleteRow(
      databaseId: databaseId,
      tableId: tableId,
      rowId: rowId,
    );
  }

  Future<FavoriteStadium?> _favoriteForStadium({
    required String userId,
    required String stadiumId,
  }) async {
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

  IconData get icon => stadiumIconFromKey(iconKey);
}

final FavoritesRepository favoriteService = FavoriteService(TablesDB(client));
