import '../database/app_database.dart';
import '../domain/models/audiobook.dart';
import 'download_manager.dart';

/// Web mirror of `download_manager_io.dart`: the web demo is streaming-only
/// and has no filesystem, so there is no queue at all.
DownloadManager? createDownloadManager(AppDatabase db) => null;

Future<UnifiedAudiobook> finishDownload(
        AppDatabase db, DownloadJob job, String zipPath, String root) async =>
    throw UnsupportedError('No downloads on the web');

Future<int?> downloadedBytes(UnifiedAudiobook book) async => null;

bool get canRevealDownloads => false;

Future<void> revealDownloadedBook(UnifiedAudiobook book) async {}
