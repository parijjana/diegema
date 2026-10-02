/// The app-wide queue of Discover downloads: one book at a time, resumable,
/// surviving the app being backgrounded or killed. See
/// `project_docs/diegema/DOWNLOADS_MANAGEMENT.md`.
///
/// This file is the platform-free core: the state each book is in, what a
/// queued download carries, and [DownloadManager], which turns the engine's
/// updates into that state and finishes a fetched ZIP into a library book.
/// The engine itself (`background_downloader`) and the extraction need
/// `dart:io`, so they live in `download_manager_io.dart`; the web build,
/// which never downloads, gets `download_manager_web.dart` instead.
library;

import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../core/utils/book_identity.dart';
import '../database/app_database.dart';
import '../domain/models/audiobook.dart';
import '../domain/models/librivox_book.dart';
import 'downloads_location.dart';

export 'download_manager_io.dart'
    if (dart.library.html) 'download_manager_web.dart';

/// Where one book's download is, as the UI shows it.
enum DownloadPhase { queued, downloading, paused, extracting, failed, done }

/// One book's download state. [progress] is 0–1 while the size is known and
/// null when it is not (archive.org's on-the-fly ZIPs send no length).
@immutable
class BookDownload {
  final String id;
  final String title;
  final DownloadPhase phase;
  final double? progress;

  /// Why it failed, in words for the user. Only for [DownloadPhase.failed].
  final String? error;

  const BookDownload({
    required this.id,
    required this.title,
    required this.phase,
    this.progress,
    this.error,
  });

  bool get isActive =>
      phase != DownloadPhase.failed && phase != DownloadPhase.done;

  BookDownload copyWith(
          {DownloadPhase? phase, double? progress, String? error}) =>
      BookDownload(
        id: id,
        title: title,
        phase: phase ?? this.phase,
        progress: progress ?? this.progress,
        error: error,
      );
}

/// A chapter as the book will be saved, before its file exists: the feed's
/// title and length (Discover), or the old copy's (Re-download, with its id
/// so progress and bookmarks keep pointing at the same chapters).
@immutable
class DownloadChapter {
  final String? id;
  final String title;
  final int seconds;

  const DownloadChapter({this.id, required this.title, this.seconds = 0});

  Map<String, Object?> toJson() => {'id': id, 't': title, 's': seconds};

  factory DownloadChapter.fromJson(Map<String, dynamic> json) =>
      DownloadChapter(
        id: json['id'] as String?,
        title: json['t'] as String? ?? '',
        seconds: (json['s'] as num?)?.toInt() ?? 0,
      );
}

/// Everything needed to build the library book once the ZIP is in, carried
/// as the engine task's metadata so a download that finishes while the app
/// is dead can still be saved on the next launch.
@immutable
class DownloadJob {
  /// The archive.org identifier: the task id and the saved book's id.
  final String id;
  final String url;
  final String title;
  final String author;
  final String description;
  final String? cover;
  final List<String> narrators;
  final String source;
  final String origin;
  final List<DownloadChapter> chapters;

  /// A re-download of a book whose files went missing: tries archive.org's
  /// pre-built ZIP first and [fallbackUrl] when that is not there.
  final String? fallbackUrl;

  const DownloadJob({
    required this.id,
    required this.url,
    required this.title,
    this.author = '',
    this.description = '',
    this.cover,
    this.narrators = const [],
    this.source = 'Downloaded',
    this.origin = BookIdentity.originLibrivox,
    this.chapters = const [],
    this.fallbackUrl,
  });

  /// A Discover download. [feed] is the RSS chapter list, when it loaded.
  factory DownloadJob.fromLibriVox(LibriVoxBook book,
      {List<AudiobookChapter>? feed}) {
    return DownloadJob(
      id: BookIdentity.archiveIdentifierFor(
          librivoxApiId: book.id, urlIarchive: book.urlIarchive),
      url: book.urlZipFile,
      title: book.title,
      author: book.authorNames,
      description: book.description,
      cover: book.coverArtUrl,
      narrators: book.narrators,
      chapters: [
        for (final c in feed ?? const <AudiobookChapter>[])
          DownloadChapter(title: c.title, seconds: c.durationSeconds),
      ],
    );
  }

  /// A Re-download (owner: never fall back to streaming). Uses archive.org's
  /// pre-built 64kb ZIP, not the on-the-fly `compress` endpoint, to spare
  /// their servers; `compress` only when an item has no pre-built one.
  factory DownloadJob.redownload(UnifiedAudiobook book) {
    final id = book.id;
    return DownloadJob(
      id: id,
      url: 'https://archive.org/download/$id/${id}_64kb_mp3.zip',
      fallbackUrl: 'https://archive.org/compress/$id/'
          'formats=64KBPS%20MP3&file=/$id.zip',
      title: book.title,
      author: book.author,
      description: book.description,
      cover: book.coverArtUrlOrPath,
      narrators: book.narrators,
      source: book.source ?? 'Downloaded',
      origin: book.origin,
      chapters: [
        for (final c in book.chapters)
          DownloadChapter(id: c.id, title: c.title, seconds: c.durationSeconds),
      ],
    );
  }

  /// The same job pointed at its fallback URL, with no further fallback.
  DownloadJob withFallback() => DownloadJob(
        id: id,
        url: fallbackUrl ?? url,
        title: title,
        author: author,
        description: description,
        cover: cover,
        narrators: narrators,
        source: source,
        origin: origin,
        chapters: chapters,
      );

  String encode() => jsonEncode({
        'id': id,
        'url': url,
        'title': title,
        'author': author,
        'description': description,
        'cover': cover,
        'narrators': narrators,
        'source': source,
        'origin': origin,
        'chapters': [for (final c in chapters) c.toJson()],
        'fallback': fallbackUrl,
      });

  /// Null for metadata this app did not write (or an older shape).
  static DownloadJob? decode(String metaData) {
    try {
      final json = jsonDecode(metaData) as Map<String, dynamic>;
      return DownloadJob(
        id: json['id'] as String,
        url: json['url'] as String,
        title: json['title'] as String? ?? '',
        author: json['author'] as String? ?? '',
        description: json['description'] as String? ?? '',
        cover: json['cover'] as String?,
        narrators: [
          for (final n in json['narrators'] as List? ?? const []) '$n',
        ],
        source: json['source'] as String? ?? 'Downloaded',
        origin: json['origin'] as String? ?? BookIdentity.originLibrivox,
        chapters: [
          for (final c in json['chapters'] as List? ?? const [])
            DownloadChapter.fromJson(c as Map<String, dynamic>),
        ],
        fallbackUrl: json['fallback'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  /// The library book for [files] (the extracted mp3s, in order). The
  /// job's chapter titles and lengths — and ids, for a re-download — are
  /// used when they line up one to one with the files (LibriVox numbers
  /// both the same way); otherwise each file is a chapter named after it.
  /// Same id as streaming the book, so progress and bookmarks carry over.
  UnifiedAudiobook toBook(List<String> files) {
    final same = chapters.length == files.length;
    return UnifiedAudiobook(
      id: id,
      title: title,
      author: author,
      description: description,
      coverArtUrlOrPath: cover,
      source: source,
      origin: origin,
      narrators: narrators,
      isDownloaded: true,
      chapters: [
        for (var i = 0; i < files.length; i++)
          AudiobookChapter(
            id: (same ? chapters[i].id : null) ?? '${id}_local_$i',
            title: same ? chapters[i].title : _fileTitle(files[i]),
            audioPathOrUrl: files[i],
            durationSeconds: same ? chapters[i].seconds : 0,
            isStream: false,
          ),
      ],
    );
  }

  static String _fileTitle(String path) {
    final name = path.split(RegExp(r'[\\/]')).last;
    return name.toLowerCase().endsWith('.mp3')
        ? name.substring(0, name.length - 4)
        : name;
  }
}

/// The engine's view of a task, in this app's terms.
enum EngineStatus {
  enqueued,
  running,
  paused,
  waitingToRetry,
  complete,
  notFound,
  failed,
  canceled,
}

/// A status and/or progress report from the engine, or a persisted record
/// read back at startup.
@immutable
class EngineUpdate {
  final DownloadJob job;
  final EngineStatus? status;
  final double? progress;
  final String? error;

  const EngineUpdate(this.job, {this.status, this.progress, this.error});
}

/// What [DownloadManager] needs from the download plugin. A small interface
/// so the manager is tested against a fake; `download_manager_io.dart` has
/// the `background_downloader` one.
abstract class DownloadEngine {
  /// Every status and progress update, including ones replayed for tasks
  /// that moved on while the app was suspended or dead.
  Stream<EngineUpdate> get updates;

  /// Set up one-at-a-time, notifications and task tracking, replay what
  /// happened in the background and reschedule tasks the OS killed. Called
  /// after [updates] has a listener.
  Future<void> start();

  /// The persisted record of every task that has not been [forget]-ten:
  /// queued, running, paused, failed, and complete-but-not-yet-saved.
  Future<List<EngineUpdate>> records();

  Future<bool> enqueue(DownloadJob job, {required bool wifiOnly});
  Future<void> cancel(String id);
  Future<bool> pause(String id);
  Future<bool> resume(String id);

  /// Applies to queued and running tasks too, not only new ones.
  Future<void> setWifiOnly(bool wifiOnly);

  /// Where task [id]'s ZIP lands: app-private, never the shared folder.
  Future<String> zipPath(String id);

  /// Drops task [id]'s record and its ZIP, partial or whole.
  Future<void> forget(String id);

  /// Asks to show the progress notification, where the OS needs asking
  /// (Android 13+, iOS). Called before the first download.
  Future<void> askNotificationPermission();
}

/// Extracts [zipPath] into the book's folder under [root] and saves the
/// book; returns it. `download_manager_io.dart`'s [finishDownload] is the
/// real one.
typedef DownloadFinisher = Future<UnifiedAudiobook> Function(
    AppDatabase db, DownloadJob job, String zipPath, String root);

/// The one app-wide download queue, created in `main` and put in scope by
/// [DownloadsScope]. A [ChangeNotifier]: everything that shows a download
/// rebuilds from [stateFor] / [all], so closing and reopening a book's
/// detail shows the live state rather than losing it.
class DownloadManager extends ChangeNotifier {
  final AppDatabase db;
  final DownloadEngine engine;
  final DownloadFinisher finish;
  final DownloadsLocation location;

  DownloadManager({
    required this.db,
    required this.engine,
    required this.finish,
    this.location = const DownloadsLocation(),
  });

  /// Insertion order is queue order.
  final LinkedHashMap<String, BookDownload> _downloads = LinkedHashMap();
  final Map<String, DownloadJob> _jobs = {};

  /// Ids being finished right now, and ones finished this run: a completion
  /// can arrive twice (the replayed update and the persisted record), and
  /// must be extracted and saved once.
  final Set<String> _finishing = {};
  final Set<String> _finished = {};

  /// Ids the user cancelled, so the engine's "canceled" echo is expected.
  final Set<String> _cancelling = {};

  StreamSubscription<EngineUpdate>? _sub;
  bool _wifiOnly = false;
  bool _askedNotifications = false;

  bool get wifiOnly => _wifiOnly;

  /// Every download this run knows about, in queue order.
  List<BookDownload> get all => List.unmodifiable(_downloads.values);

  BookDownload? stateFor(String id) => _downloads[id];

  /// 1-based place among the books still waiting, or null when [id] is not
  /// waiting.
  int? queuePosition(String id) {
    if (_downloads[id]?.phase != DownloadPhase.queued) return null;
    var n = 0;
    for (final d in _downloads.values) {
      if (d.phase == DownloadPhase.queued) n++;
      if (d.id == id) return n;
    }
    return null;
  }

  /// Whether [id] is next in line but nothing is downloading, with Wi-Fi
  /// only on — the engine holds it until Wi-Fi is back. Inferred: the
  /// engine reports no "waiting for network" status of its own.
  bool waitingForWifi(String id) =>
      _wifiOnly &&
      queuePosition(id) == 1 &&
      !_downloads.values.any((d) =>
          d.phase == DownloadPhase.downloading ||
          d.phase == DownloadPhase.extracting);

  /// Starts listening, then lets the engine replay the background and
  /// reschedule killed tasks, then picks up what it persisted: ZIPs that
  /// finished while the app was dead are extracted and saved now.
  Future<void> start() async {
    _sub ??= engine.updates.listen(_onUpdate);
    try {
      await engine.start();
      for (final record in await engine.records()) {
        final id = record.job.id;
        _jobs[id] = record.job;
        switch (record.status) {
          case EngineStatus.complete:
            unawaited(_finish(record.job));
          case EngineStatus.canceled:
            await engine.forget(id);
          case null:
            break;
          default:
            if (!_downloads.containsKey(id)) _apply(record);
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('DownloadManager: start failed: $e');
    }
  }

  /// Queues a Discover download of [book]. [feed] is its RSS chapter list,
  /// whose titles and lengths the saved book takes when they line up.
  Future<void> download(LibriVoxBook book, {List<AudiobookChapter>? feed}) =>
      _enqueue(DownloadJob.fromLibriVox(book, feed: feed));

  /// Queues a Re-download of [book], whose files can no longer be read.
  Future<void> redownload(UnifiedAudiobook book) =>
      _enqueue(DownloadJob.redownload(book));

  Future<void> _enqueue(DownloadJob job) async {
    final current = _downloads[job.id];
    if (current != null && current.isActive) return;
    // macOS asks where downloads go before the first one, not when it
    // finishes (the user may be long gone by then).
    if (location.needsFolderChoice && await location.chooseFolder() != null) {
      // Downloads made before the folder was chosen join it now.
      await moveDownloadsToVisibleFolder(db, location: location);
    }
    if (await location.current() == null) {
      throw StateError('No folder to download into');
    }
    if (!_askedNotifications) {
      _askedNotifications = true;
      try {
        await engine.askNotificationPermission();
      } catch (e) {
        debugPrint('DownloadManager: notification permission: $e');
      }
    }
    await _submit(job);
  }

  Future<void> _submit(DownloadJob job) async {
    _jobs[job.id] = job;
    _finished.remove(job.id);
    _cancelling.remove(job.id);
    _downloads.remove(job.id); // re-queued at the back
    _downloads[job.id] = BookDownload(
        id: job.id, title: job.title, phase: DownloadPhase.queued);
    notifyListeners();
    final ok = await engine.enqueue(job, wifiOnly: _wifiOnly);
    if (!ok) _fail(job.id, "Couldn't start the download.");
  }

  /// Stops [id] and deletes whatever of it was fetched.
  Future<void> cancel(String id) async {
    _cancelling.add(id);
    _downloads.remove(id);
    notifyListeners();
    await engine.cancel(id);
    await engine.forget(id);
  }

  Future<void> pause(String id) async {
    if (await engine.pause(id)) _set(id, DownloadPhase.paused);
  }

  Future<void> resume(String id) async {
    final job = _jobs[id];
    if (await engine.resume(id)) {
      _set(id, DownloadPhase.queued);
    } else if (job != null) {
      // The partial file is gone (the OS cleared it): start over.
      await engine.forget(id);
      await _submit(job);
    }
  }

  /// Fetches a failed download again from the start.
  Future<void> retry(String id) async {
    final job = _jobs[id];
    if (job == null) return;
    await engine.forget(id);
    await _submit(job);
  }

  /// Clears a failed or finished download from the list.
  Future<void> dismiss(String id) async {
    final d = _downloads[id];
    if (d == null || d.isActive) return;
    _downloads.remove(id);
    notifyListeners();
    if (d.phase == DownloadPhase.failed) await engine.forget(id);
  }

  /// The Settings > Downloads toggle, kept in step by `app.dart`.
  Future<void> setWifiOnly(bool value) async {
    if (value == _wifiOnly) return;
    _wifiOnly = value;
    notifyListeners();
    try {
      await engine.setWifiOnly(value);
    } catch (e) {
      debugPrint('DownloadManager: Wi-Fi setting: $e');
    }
  }

  void _onUpdate(EngineUpdate update) {
    final id = update.job.id;
    _jobs.putIfAbsent(id, () => update.job);
    switch (update.status) {
      case EngineStatus.complete:
        unawaited(_finish(_jobs[id]!));
      case EngineStatus.notFound when update.job.fallbackUrl != null:
        // No pre-built ZIP for this item: the form LibriVox itself links.
        unawaited(() async {
          await engine.forget(id);
          await _submit(update.job.withFallback());
        }());
      case EngineStatus.canceled:
        // A cancel this app did not ask for (the OS, or the notification's
        // Cancel button) still deletes the partial file.
        if (_downloads.remove(id) != null) notifyListeners();
        unawaited(engine.forget(id));
      default:
        if (_finishing.contains(id) || _finished.contains(id)) return;
        if (_cancelling.contains(id)) return;
        _apply(update);
    }
  }

  /// Folds a non-final update (or a failure) into the book's state.
  void _apply(EngineUpdate update) {
    final id = update.job.id;
    final current = _downloads[id] ??
        BookDownload(
            id: id, title: update.job.title, phase: DownloadPhase.queued);
    final progress = update.progress;
    final known = progress != null && progress >= 0 && progress <= 1;
    final BookDownload next;
    switch (update.status) {
      case EngineStatus.enqueued:
      case EngineStatus.waitingToRetry:
        next = current.copyWith(phase: DownloadPhase.queued);
      case EngineStatus.running:
        next = current.copyWith(
            phase: DownloadPhase.downloading,
            progress: known ? progress : null);
      case EngineStatus.paused:
        next = current.copyWith(phase: DownloadPhase.paused);
      case EngineStatus.failed:
      case EngineStatus.notFound:
        next = current.copyWith(
            phase: DownloadPhase.failed,
            error: update.status == EngineStatus.notFound
                ? 'archive.org has no download for this book.'
                : "Couldn't download it. Check your connection and try "
                    'again.');
      case EngineStatus.complete:
      case EngineStatus.canceled:
        return;
      case null:
        // Progress only. A progress tick for a book still shown as queued
        // means it has started.
        if (!known || current.phase == DownloadPhase.paused) return;
        next = current.copyWith(
            phase: DownloadPhase.downloading, progress: progress);
    }
    _downloads[id] = next;
    notifyListeners();
  }

  Future<void> _finish(DownloadJob job) async {
    final id = job.id;
    if (_finishing.contains(id) || _finished.contains(id)) return;
    _finishing.add(id);
    _downloads[id] = BookDownload(
        id: id, title: job.title, phase: DownloadPhase.extracting);
    notifyListeners();
    try {
      final root = await location.current();
      if (root == null) throw StateError('No folder to download into');
      await finish(db, job, await engine.zipPath(id), root);
      _finished.add(id);
      _downloads[id] =
          BookDownload(id: id, title: job.title, phase: DownloadPhase.done);
    } catch (e) {
      debugPrint('DownloadManager: finishing $id failed: $e');
      _downloads[id] = BookDownload(
          id: id,
          title: job.title,
          phase: DownloadPhase.failed,
          error: "Couldn't add the download to your library.");
    } finally {
      _finishing.remove(id);
      // The ZIP is spent either way: saved, or broken (Retry fetches anew).
      await engine.forget(id);
      notifyListeners();
    }
  }

  void _set(String id, DownloadPhase phase) {
    final d = _downloads[id];
    if (d == null) return;
    _downloads[id] = d.copyWith(phase: phase);
    notifyListeners();
  }

  void _fail(String id, String reason) {
    final d = _downloads[id];
    if (d == null) return;
    _downloads[id] = d.copyWith(phase: DownloadPhase.failed, error: reason);
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

/// Puts the [DownloadManager] in scope for the whole app, like
/// `SettingsScope`. Absent on the web, in the demo and in widget tests that
/// do not supply one; download controls then do not offer to download.
class DownloadsScope extends InheritedNotifier<DownloadManager> {
  const DownloadsScope({
    super.key,
    required DownloadManager manager,
    required super.child,
  }) : super(notifier: manager);

  static DownloadManager? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DownloadsScope>()?.notifier;
}
