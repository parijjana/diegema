import '../database/app_database.dart';
import 'downloads_location.dart';
import 'search_cache_store.dart';

/// Web mirror of `storage_usage_io.dart`: the demo has no files to measure
/// and Settings does not show the section.
class StorageUsage {
  final int downloads;
  final int covers;
  final int searchCache;
  final int clearable;

  const StorageUsage({
    this.downloads = 0,
    this.covers = 0,
    this.searchCache = 0,
    this.clearable = 0,
  });
}

Future<StorageUsage> measureStorage(
  AppDatabase db, {
  String? documentsPath,
  DownloadsLocation downloads = const DownloadsLocation(),
  SearchCacheStore searchCache = const SearchCacheStore(),
}) async =>
    const StorageUsage();

Future<int> clearCaches(
  AppDatabase db, {
  String? documentsPath,
  SearchCacheStore searchCache = const SearchCacheStore(),
}) async =>
    0;
