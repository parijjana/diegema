import '../database/app_database.dart';

/// Resolves a directory, or `null` when there is none on this platform.
typedef DirectoryResolver = Future<String?> Function();

/// Web mirror of `downloads_location_io.dart`. The web demo is
/// streaming-only and has no filesystem, so there is never a root.
class DownloadsLocation {
  final DirectoryResolver? documentsRoot;
  final DirectoryResolver? visibleRoot;

  const DownloadsLocation({this.documentsRoot, this.visibleRoot});

  Future<String?> privateRoot() async => null;
  Future<String?> userVisibleRoot() async => null;
  Future<String?> current() async => null;
  bool get needsFolderChoice => false;
  Future<String?> chooseFolder() async => null;
  Future<List<String>> all() async => const [];
  Future<bool> requestMediaDelete(List<String> files) async => false;
}

Future<void> openDownloadsFolder() async {}

Future<int> moveDownloadsToVisibleFolder(AppDatabase db,
        {DownloadsLocation location = const DownloadsLocation()}) async =>
    0;
