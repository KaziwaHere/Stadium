import 'dart:typed_data';

import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:stadium/src/appwrite_client.dart';
import 'package:stadium/src/services/manager_stadium_service.dart';

class StadiumImage extends StatelessWidget {
  const StadiumImage({
    super.key,
    required this.fileId,
    required this.fallbackIcon,
    this.iconSize = 42,
    this.fit = BoxFit.cover,
  });

  final String? fileId;
  final IconData fallbackIcon;
  final double iconSize;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final id = fileId;
    if (id == null || id.isEmpty) return _fallback();

    return FutureBuilder<Uint8List>(
      future: stadiumImageLoader.load(id),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return Image.memory(
            snapshot.data!,
            fit: fit,
            width: double.infinity,
            height: double.infinity,
            gaplessPlayback: true,
          );
        }
        if (snapshot.hasError) return _fallback();
        return const Center(child: CircularProgressIndicator(strokeWidth: 2));
      },
    );
  }

  Widget _fallback() {
    return Center(
      child: Icon(
        fallbackIcon,
        size: iconSize,
        color: Colors.white.withValues(alpha: .86),
      ),
    );
  }
}

class StadiumImageLoader {
  StadiumImageLoader(this._storage);

  final Storage _storage;
  final Map<String, Future<Uint8List>> _cache = {};

  Future<Uint8List> load(String fileId) {
    return _cache.putIfAbsent(fileId, () => _load(fileId));
  }

  Future<Uint8List> _load(String fileId) async {
    try {
      return await _storage.getFilePreview(
        bucketId: ManagerStadiumService.imageBucketId,
        fileId: fileId,
        width: 1200,
        height: 800,
        quality: 86,
      );
    } on AppwriteException {
      return _storage.getFileView(
        bucketId: ManagerStadiumService.imageBucketId,
        fileId: fileId,
      );
    }
  }
}

final StadiumImageLoader stadiumImageLoader = StadiumImageLoader(
  Storage(client),
);
