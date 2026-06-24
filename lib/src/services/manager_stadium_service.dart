import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:stadium/src/appwrite_client.dart';
import 'package:stadium/src/models/stadium.dart';
import 'package:stadium/src/utils/stadium_schedule.dart';

abstract class ManagerStadiumRepository {
  Future<Stadium?> managerStadium(String managerId);

  Future<Stadium> createManagerStadium({
    required String managerId,
    required String name,
    required String location,
    required int price,
  });

  Future<List<Stadium>> listPublicStadiums();
}

class ManagerStadiumService implements ManagerStadiumRepository {
  ManagerStadiumService(this._tables);

  static const databaseId = 'stadium_booking';
  static const tableId = 'stadiums';
  static const _defaultRating = 4.8;
  static const _defaultIconKey = 'stadium';

  final TablesDB _tables;

  @override
  Future<Stadium?> managerStadium(String managerId) async {
    try {
      final row = await _tables.getRow(
        databaseId: databaseId,
        tableId: tableId,
        rowId: managerId,
      );

      return _stadiumFromRow(row);
    } on AppwriteException catch (error) {
      if (error.code == 404) return null;
      rethrow;
    }
  }

  @override
  Future<Stadium> createManagerStadium({
    required String managerId,
    required String name,
    required String location,
    required int price,
  }) async {
    final payload = {
      'name': name,
      'location': location,
      'price': price,
      'rating': _defaultRating,
      'available': nextAvailabilityLabel(),
      'icon': _defaultIconKey,
    };

    models.Row row;

    try {
      row = await _tables.updateRow(
        databaseId: databaseId,
        tableId: tableId,
        rowId: managerId,
        data: payload,
      );
    } on AppwriteException catch (error) {
      if (error.code != 404) rethrow;

      row = await _tables.createRow(
        databaseId: databaseId,
        tableId: tableId,
        rowId: managerId,
        data: payload,
        permissions: [
          Permission.read(Role.users()),
          Permission.update(Role.user(managerId)),
          Permission.delete(Role.user(managerId)),
        ],
      );
    }

    return _stadiumFromRow(row);
  }

  @override
  Future<List<Stadium>> listPublicStadiums() async {
    try {
      final rows = await _tables.listRows(
        databaseId: databaseId,
        tableId: tableId,
        queries: [Query.limit(100)],
      );

      return rows.rows.map(_stadiumFromRow).toList();
    } on AppwriteException catch (error) {
      if (error.code == 404) return const [];
      rethrow;
    }
  }

  Stadium _stadiumFromRow(models.Row row) {
    final data = row.data;

    return Stadium(
      id: row.$id,
      name: data['name'].toString(),
      location: data['location'].toString(),
      rating: (data['rating'] as num?)?.toDouble() ?? 4.5,
      price: (data['price'] as num?)?.toInt() ?? 50,
      available: nextAvailabilityLabel(),
      iconKey: data['icon']?.toString() ?? 'stadium',
      icon: stadiumIconFromKey(data['icon']?.toString() ?? 'stadium'),
      days: buildBookingDays(),
    );
  }
}

final ManagerStadiumRepository managerStadiumService = ManagerStadiumService(
  TablesDB(client),
);
