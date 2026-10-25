import 'dart:convert';
import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:path/path.dart' as p;
import '../core/app_data_directory.dart';

import '../database/app_database.dart';
import 'downloads_location.dart';
import 'search_cache_store.dart';

/// What Diegema keeps on the device, for Settings > Storage.
class StorageUsage {
  /// Downloaded books. Measured only: never cleared by [clearCaches].
  final int downloads;

  /// Saved cover images (`<documents>/diegema/covers`).
  final int covers;

  /// Discover's saved search results.
  final int searchCache;

  /// What [clearCaches] would free right now: the search cache plus covers
  /// no book in the library points at. Covers a book uses are kept.
  final int clearable;

  const StorageUsage({
    this.downloads = 0,
    this.covers = 0,
    this.searchCache = 0,
    this.clearable = 0,
  });
}

Future<String?> _coversDir(String? documentsPath) async {
  try {
    final docs = documentsPath ?? (await appDataDirectory()).path;
    return p.join(docs, 'diegema', 'covers');
  } catch (_) {
    return null;
  }
}

Future<int> _dirSize(String path) async {
  var total = 0;
  try {
    await for (final e
        in Directory(path).list(recursive: true, followLinks: false)) {
      if (e is File) {
        try {
          total += await e.length();
        } catch (_) {}
      }
    }
  } catch (_) {}
  return total;
}

/// Cover files inside [coversDir] that no book's cover points at. Only
/// plain files directly inside the covers folder qualify.
Future<List<File>> _unusedCovers(AppDatabase db, String coversDir) async {
  final used = <String>{
    for (final b in await db.getAllAudiobooks())
      if (b.coverArtUrlOrPath != null && b.coverArtUrlOrPath!.isNotEmpty)
        p.normalize(b.coverArtUrlOrPath!),
  };
  final unused = <File>[];
  try {
    await for (final e in Directory(coversDir).list(followLinks: false)) {
      if (e is File &&
          p.isWithin(coversDir, e.path) &&
          !used.contains(p.normalize(e.path))) {
        unused.add(e);
      }
    }
  } catch (_) {}
  return unused;
}

/// Sizes for the Storage section. Read-only. [documentsPath], [downloads]
/// and [searchCache] are test seams.
Future<StorageUsage> measureStorage(
  AppDatabase db, {
  String? documentsPath,
  DownloadsLocation downloads = const DownloadsLocation(),
  SearchCacheStore searchCache = const SearchCacheStore(),
}) async {
  var downloadBytes = 0;
  for (final root in await downloads.all()) {
    downloadBytes += await _dirSize(root);
  }
  final coversDir = await _coversDir(documentsPath);
  var coverBytes = 0;
  var unusedBytes = 0;
  if (coversDir != null) {
    coverBytes = await _dirSize(coversDir);
    for (final f in await _unusedCovers(db, coversDir)) {
      try {
        unusedBytes += await f.length();
      } catch (_) {}
    }
  }
  final searchBytes = utf8.encode(await searchCache.read() ?? '').length;
  return StorageUsage(
    downloads: downloadBytes,
    covers: coverBytes,
    searchCache: searchBytes,
    clearable: unusedBytes + searchBytes,
  );
}

/// Clears the caches and returns the bytes freed: Discover's saved search
/// results, the in-memory cover images, and saved covers no book uses.
///
/// Never touches downloads, a book's own cover, or anything in a library
/// folder: the only files deleted lie directly inside Diegema's own
/// `covers` folder.
Future<int> clearCaches(
  AppDatabase db, {
  String? documentsPath,
  SearchCacheStore searchCache = const SearchCacheStore(),
}) async {
  var freed = 0;
  try {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  } catch (_) {}
  final coversDir = await _coversDir(documentsPath);
  if (coversDir != null) {
    for (final f in await _unusedCovers(db, coversDir)) {
      try {
        final size = await f.length();
        await f.delete();
        freed += size;
      } catch (_) {}
    }
  }
  freed += utf8.encode(await searchCache.read() ?? '').length;
  await searchCache.clear();
  return freed;
}
