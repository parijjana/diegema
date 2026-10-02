import 'dart:async';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

import '../core/network/user_agent.dart';
import '../database/app_database.dart';
import '../domain/models/audiobook.dart';
import 'download_manager.dart';
import 'librivox_downloader_io.dart';

/// The real queue, for `main`. Null under `flutter test`, where there is no
/// plugin to talk to.
DownloadManager? createDownloadManager(AppDatabase db) {
  if (Platform.environment.containsKey('FLUTTER_TEST')) return null;
  return DownloadManager(
      db: db, engine: BackgroundDownloaderEngine(), finish: finishDownload);
}

/// Extracts the fetched ZIP into `<root>/<Title> [<id>]/` (mp3s only, see
/// [extractAudioFromZip]) and saves the book under its archive.org id, so a
/// book that was being streamed, or is being re-downloaded, keeps its
/// progress and bookmarks. The ZIP is left for the engine to delete.
Future<UnifiedAudiobook> finishDownload(
    AppDatabase db, DownloadJob job, String zipPath, String root) async {
  final dir = Directory(p.join(root, bookFolderName(job.title, job.id)));
  final files = await extractAudioFromZip(File(zipPath), dir);
  final book = job.toBook(files);
  await db.saveAudiobook(book);
  return book;
}

/// Bytes [book]'s downloaded files take, or null when none can be read.
Future<int?> downloadedBytes(UnifiedAudiobook book) async {
  var total = 0;
  for (final c in book.chapters) {
    if (c.isStream) continue;
    try {
      total += await File(c.audioPathOrUrl).length();
    } on FileSystemException {
      // Missing: counted as nothing.
    }
  }
  return total == 0 ? null : total;
}

/// Desktop only: whether [revealDownloadedBook] can show the folder.
bool get canRevealDownloads => Platform.isMacOS || Platform.isWindows;

/// Opens [book]'s folder in Finder / Explorer.
Future<void> revealDownloadedBook(UnifiedAudiobook book) async {
  final first = book.chapters.where((c) => !c.isStream).firstOrNull;
  if (first == null) return;
  try {
    await launchUrl(Uri.directory(p.dirname(first.audioPathOrUrl)));
  } catch (e) {
    debugPrint('Could not show the folder: $e');
  }
}

/// [DownloadEngine] over `background_downloader`: URLSessions on iOS,
/// WorkManager on Android (both carry on with the app in the background),
/// isolates on desktop. Its task database survives the app being killed,
/// which is what lets a download that finished while the app was dead be
/// saved on the next launch.
class BackgroundDownloaderEngine implements DownloadEngine {
  /// The ZIP's folder under app support: app-private on every platform.
  /// Never the shared Audiobooks folder, which accepts audio only.
  static const String _zipDir = 'pending_downloads';

  final FileDownloader _downloader = FileDownloader();
  final StreamController<EngineUpdate> _updates = StreamController.broadcast();
  // Lives as long as the app: there is one engine and nothing to stop.
  // ignore: cancel_subscriptions
  StreamSubscription<TaskUpdate>? _sub;

  @override
  Stream<EngineUpdate> get updates => _updates.stream;

  @override
  Future<void> start() async {
    _sub ??= _downloader.updates.listen((update) {
      final job = DownloadJob.decode(update.task.metaData);
      if (job == null) return;
      switch (update) {
        case TaskStatusUpdate():
          _updates.add(EngineUpdate(job,
              status: _status(update.status),
              error: update.exception?.description));
        case TaskProgressUpdate():
          // Negative values stand for statuses, which arrive separately.
          if (update.progress < 0) return;
          _updates.add(EngineUpdate(job,
              progress: update.hasExpectedFileSize ? update.progress : null));
      }
    });
    // One book at a time: spares archive.org, the battery and the disk.
    // The holding queue is native, so it keeps feeding tasks to the OS
    // while the app is suspended.
    await _downloader
        .configure(globalConfig: (Config.holdingQueue, (1, null, null)));
    _downloader.configureNotification(
      running:
          const TaskNotification('Downloading {displayName}', '{progress}'),
      paused: const TaskNotification('{displayName}', 'Paused'),
      complete: const TaskNotification('{displayName}', 'Download finished'),
      error: const TaskNotification(
          '{displayName}', "Couldn't download it. Open Diegema to retry."),
      progressBar: true,
    );
    // Tracks tasks in its database, replays what happened while the app
    // was suspended, and (after a few seconds) reschedules tasks the OS
    // killed — including any still in the holding queue, which does not
    // survive the app being killed.
    await _downloader.start();
  }

  @override
  Future<List<EngineUpdate>> records() async {
    final out = <EngineUpdate>[];
    for (final record in await _downloader.database.allRecords()) {
      final job = DownloadJob.decode(record.task.metaData);
      if (job == null) continue;
      out.add(EngineUpdate(job,
          status: _status(record.status),
          progress: record.progress,
          error: record.exception?.description));
    }
    return out;
  }

  @override
  Future<bool> enqueue(DownloadJob job, {required bool wifiOnly}) =>
      _downloader.enqueue(DownloadTask(
        taskId: job.id,
        url: job.url,
        headers: const {'User-Agent': kHttpUserAgent},
        baseDirectory: BaseDirectory.applicationSupport,
        directory: _zipDir,
        filename: _zipName(job.id),
        displayName: job.title,
        metaData: job.encode(),
        updates: Updates.statusAndProgress,
        requiresWiFi: wifiOnly,
        // Android stops a worker after 9 minutes; a pausable task is paused
        // and resumed instead of failing, which a big book needs.
        allowPause: true,
        retries: 3,
      ));

  @override
  Future<void> cancel(String id) async {
    await _downloader.cancelTaskWithId(id);
  }

  @override
  Future<bool> pause(String id) async {
    final task = await _downloader.taskForId(id);
    return task is DownloadTask && await _downloader.pause(task);
  }

  @override
  Future<bool> resume(String id) async {
    final task = (await _downloader.database.recordForId(id))?.task;
    return task is DownloadTask && await _downloader.resume(task);
  }

  @override
  Future<void> setWifiOnly(bool wifiOnly) async {
    final wanted = wifiOnly ? RequireWiFi.forAllTasks : RequireWiFi.forNoTasks;
    // The plugin persists this, and changing it reschedules every task, so
    // only when it actually changes.
    if (await _downloader.getRequireWiFiSetting() == wanted) return;
    await _downloader.requireWiFi(wanted);
  }

  @override
  Future<String> zipPath(String id) async {
    final dir = await Task.baseDirectoryPath(BaseDirectory.applicationSupport);
    return p.join(dir, _zipDir, _zipName(id));
  }

  @override
  Future<void> forget(String id) async {
    await _downloader.database.deleteRecordWithId(id);
    try {
      final zip = File(await zipPath(id));
      if (await zip.exists()) await zip.delete();
    } on FileSystemException {
      // Best effort: a leftover ZIP is overwritten by the next download.
    }
  }

  @override
  Future<void> askNotificationPermission() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    final permissions = _downloader.permissions;
    if (await permissions.status(PermissionType.notifications) !=
        PermissionStatus.granted) {
      await permissions.request(PermissionType.notifications);
    }
  }

  static String _zipName(String id) =>
      '${id.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_')}.zip';

  static EngineStatus _status(TaskStatus status) => switch (status) {
        TaskStatus.enqueued => EngineStatus.enqueued,
        TaskStatus.running => EngineStatus.running,
        TaskStatus.paused => EngineStatus.paused,
        TaskStatus.waitingToRetry => EngineStatus.waitingToRetry,
        TaskStatus.complete => EngineStatus.complete,
        TaskStatus.notFound => EngineStatus.notFound,
        TaskStatus.failed => EngineStatus.failed,
        TaskStatus.canceled => EngineStatus.canceled,
      };
}
