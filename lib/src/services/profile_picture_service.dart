import 'dart:typed_data';

import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:stadium/src/appwrite_client.dart';

class ProfilePictureService {
  ProfilePictureService(this._storage, this._account);

  static const bucketId = 'profile-pictures';
  static const preferenceKey = 'profilePictureId';
  static const maximumFileSize = 5 * 1024 * 1024;

  final Storage _storage;
  final Account _account;

  String? fileId(models.User user) {
    final value = user.prefs.data[preferenceKey]?.toString().trim();
    return value == null || value.isEmpty ? null : value;
  }

  Future<Uint8List> preview(String fileId) async {
    try {
      return await _storage.getFilePreview(
        bucketId: bucketId,
        fileId: fileId,
        width: 320,
        height: 320,
        quality: 88,
      );
    } on AppwriteException {
      return _storage.getFileView(bucketId: bucketId, fileId: fileId);
    }
  }

  Future<models.User> upload({
    required models.User user,
    required Uint8List bytes,
    required String filename,
  }) async {
    if (bytes.lengthInBytes > maximumFileSize) {
      throw ArgumentError('Choose an image smaller than 5 MB.');
    }

    final previousFileId = fileId(user);
    final file = await _storage.createFile(
      bucketId: bucketId,
      fileId: ID.unique(),
      file: InputFile.fromBytes(bytes: bytes, filename: filename),
      permissions: [
        Permission.read(Role.user(user.$id)),
        Permission.read(Role.label('admin')),
        Permission.read(Role.label('manager')),
        Permission.update(Role.user(user.$id)),
        Permission.delete(Role.user(user.$id)),
      ],
    );

    final models.User updatedUser;
    try {
      final preferences = Map<String, dynamic>.from(user.prefs.data)
        ..[preferenceKey] = file.$id;
      updatedUser = await _account.updatePrefs(prefs: preferences);
    } catch (_) {
      await _tryDelete(file.$id);
      rethrow;
    }

    await _tryDelete(previousFileId);
    return updatedUser;
  }

  Future<models.User> remove(models.User user) async {
    final previousFileId = fileId(user);
    final preferences = Map<String, dynamic>.from(user.prefs.data)
      ..remove(preferenceKey);
    final updatedUser = await _account.updatePrefs(prefs: preferences);
    await _tryDelete(previousFileId);
    return updatedUser;
  }

  Future<void> _tryDelete(String? fileId) async {
    if (fileId == null) return;

    try {
      await _storage.deleteFile(bucketId: bucketId, fileId: fileId);
    } on AppwriteException catch (_) {
      // The preference is authoritative; a failed cleanup must not undo it.
    }
  }
}

final ProfilePictureService profilePictureService = ProfilePictureService(
  Storage(client),
  Account(client),
);
