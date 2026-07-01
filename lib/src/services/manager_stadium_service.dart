import 'dart:async';
import 'dart:typed_data';

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
    Uint8List? imageBytes,
    String? imageFilename,
  });

  Future<List<Stadium>> listPublicStadiums({int limit = 20, int offset = 0});
}

abstract class RealtimeManagerStadiumRepository {
  Stream<void> watchPublicStadiums();
}

class ManagerStadiumService
    implements ManagerStadiumRepository, RealtimeManagerStadiumRepository {
  ManagerStadiumService(this._tables, this._storage, this._realtime);

  static const databaseId = 'stadium_booking';
  static const tableId = 'stadiums';
  static const _defaultRating = 4.8;
  static const _defaultIconKey = 'stadium';
  static const imageBucketId = 'profile-pictures';
  static const maximumImageSize = 5 * 1024 * 1024;

  final TablesDB _tables;
  final Storage _storage;
  final Realtime _realtime;

  @override
  Stream<void> watchPublicStadiums() {
    late final RealtimeSubscription subscription;
    late final StreamController<void> controller;
    controller = StreamController<void>(
      onListen: () {
        subscription = _realtime.subscribe([
          Channel.tablesdb(databaseId).table(tableId).row(),
        ]);
        subscription.stream.listen(
          (_) => controller.add(null),
          onError: controller.addError,
        );
      },
      onCancel: () => subscription.close(),
    );
    return controller.stream;
  }

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
    Uint8List? imageBytes,
    String? imageFilename,
  }) async {
    if (imageBytes != null && imageBytes.lengthInBytes > maximumImageSize) {
      throw ArgumentError('Choose an image smaller than 5 MB.');
    }

    String? uploadedFileId;
    if (imageBytes != null) {
      final file = await _storage.createFile(
        bucketId: imageBucketId,
        fileId: ID.unique(),
        file: InputFile.fromBytes(
          bytes: imageBytes,
          filename: imageFilename ?? 'stadium.jpg',
        ),
        permissions: [
          Permission.read(Role.users()),
          Permission.update(Role.user(managerId)),
          Permission.delete(Role.user(managerId)),
        ],
      );
      uploadedFileId = file.$id;
    }

    final payload = {
      'name': name,
      'location': location,
      'price': price,
      'rating': _defaultRating,
      'available': nextAvailabilityLabel(),
      'icon': _defaultIconKey,
      'imageFileId': ?uploadedFileId,
    };

    try {
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
    } catch (_) {
      if (uploadedFileId != null) {
        try {
          await _storage.deleteFile(
            bucketId: imageBucketId,
            fileId: uploadedFileId,
          );
        } on AppwriteException {
          // Preserve the database error if cleanup also fails.
        }
      }
      rethrow;
    }
  }

  @override
  Future<List<Stadium>> listPublicStadiums({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      models.RowList rows;
      try {
        rows = await _tables.listRows(
          databaseId: databaseId,
          tableId: tableId,
          queries: [
            Query.orderDesc('isFeatured'),
            Query.limit(limit),
            Query.offset(offset),
          ],
        );
      } on AppwriteException catch (error) {
        if (error.code != 400 && error.code != 404) rethrow;
        // Keep older deployments usable until the featured column is pushed.
        rows = await _tables.listRows(
          databaseId: databaseId,
          tableId: tableId,
          queries: [Query.limit(limit), Query.offset(offset)],
        );
      }

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
      imageFileId: _optionalString(data['imageFileId']),
      isFeatured: data['isFeatured'] == true,
    );
  }

  String? _optionalString(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}

final ManagerStadiumRepository managerStadiumService = ManagerStadiumService(
  TablesDB(client),
  Storage(client),
  Realtime(client),
);
