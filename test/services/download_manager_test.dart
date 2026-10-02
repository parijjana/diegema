import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:diegema/core/utils/book_identity.dart';
import 'package:diegema/database/app_database.dart';
import 'package:diegema/domain/models/audiobook.dart';
import 'package:diegema/domain/models/librivox_book.dart';
import 'package:diegema/services/download_manager.dart';
import 'package:diegema/services/downloads_location_io.dart';

import '../support/fake_download_engine.dart';

List<int> _zip(Map<String, List<int>> entries) {
  final archive = Archive();
  entries.forEach(
      (name, bytes) => archive.addFile(ArchiveFile.bytes(name, bytes)));
  return ZipEncoder().encode(archive);
}

LibriVoxBook _book(String id, String title) => LibriVoxBook(
      id: id,
      title: title,
      description: 'About $title',
      totalTimeSecs: 0,
      authors: [LibriVoxAuthor(id: '1', firstName: 'Jane', lastName: 'Austen')],
      urlRss: '',
      urlZipFile:
          'https://archive.org/compress/${title.toLowerCase()}_librivox',
      urlIarchive:
          'https://archive.org/details/${title.toLowerCase()}_librivox',
      language: 'English',
      narrators: const ['Reader'],
    );

AudiobookChapter _feed(int i) => AudiobookChapter(
    id: 's$i',
    title: 'Chapter ${i + 1}',
    audioPathOrUrl: 'https://x/$i.mp3',
    durationSeconds: 60 * (i + 1),
    isStream: true);

Future<void> _settle() => Future<void>.delayed(Duration.zero);

/// Extraction and the database write are real I/O, so a finish takes a few
/// event-loop turns; waits (up to ~2 s) for [done].
Future<void> _until(bool Function() done) async {
  for (var i = 0; i < 200 && !done(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

bool _busy(DownloadManager m, String id) =>
    m.stateFor(id)?.phase == DownloadPhase.extracting;

void main() {
  late AppDatabase db;
  late Directory root;
  late DownloadsLocation location;
  late FakeDownloadEngine engine;
  late DownloadManager manager;

  final emma = _book('1', 'Emma');
  final persuasion = _book('2', 'Persuasion');

  DownloadManager newManager() => DownloadManager(
      db: db, engine: engine, finish: finishDownload, location: location);

  /// Puts a ZIP where the fake engine says task [id]'s download landed.
  void landZip(String id, Map<String, List<int>> entries) {
    Directory(engine.zipRoot).createSync(recursive: true);
    File(p.join(engine.zipRoot, '$id.zip')).writeAsBytesSync(_zip(entries));
  }

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    root = await Directory.systemTemp.createTemp('download_manager');
    location = DownloadsLocation(
        documentsRoot: () async => root.path,
        visibleRoot: () async => p.join(root.path, 'Audiobooks', 'Diegema'));
    engine = FakeDownloadEngine()..zipRoot = p.join(root.path, 'zips');
    manager = newManager();
    await manager.start();
  });

  tearDown(() async {
    manager.dispose();
    await db.close();
    await root.delete(recursive: true);
  });

  test('queues books one behind another and asks for notifications once',
      () async {
    await manager.download(emma, feed: [_feed(0), _feed(1)]);
    await manager.download(persuasion);

    expect(engine.enqueued.map((j) => j.id),
        ['emma_librivox', 'persuasion_librivox']);
    expect(engine.enqueued.first.chapters.map((c) => c.title),
        ['Chapter 1', 'Chapter 2']);
    // archive.org's pre-built ZIP (a length, ranges), LibriVox's link as
    // the fallback.
    expect(engine.enqueued.first.url,
        'https://archive.org/download/emma_librivox/emma_librivox_64kb_mp3.zip');
    expect(engine.enqueued.first.fallbackUrl, emma.urlZipFile);
    expect(engine.permissionAsks, 1);
    expect(manager.queuePosition('emma_librivox'), 1);
    expect(manager.queuePosition('persuasion_librivox'), 2);

    final job = engine.enqueued.first;
    engine.emit(job, status: EngineStatus.running);
    engine.emit(job, progress: 0.25);
    final state = manager.stateFor('emma_librivox')!;
    expect(state.phase, DownloadPhase.downloading);
    expect(state.progress, 0.25);
    expect(manager.queuePosition('persuasion_librivox'), 1);

    // Enqueueing a book that is already in the queue does nothing.
    await manager.download(emma);
    expect(engine.enqueued, hasLength(2));
  });

  test('a finished ZIP is extracted (mp3s only) and saved with feed titles',
      () async {
    await db.saveProgress(
        audiobookId: 'emma_librivox', chapterIndex: 1, positionSeconds: 30);
    await manager.download(emma, feed: [_feed(0), _feed(1)]);
    landZip('emma_librivox', {
      '01.mp3': [1],
      '02.mp3': [2],
      'cover.jpg': [3],
    });

    engine.emit(engine.enqueued.single, status: EngineStatus.complete);
    await _until(() => !_busy(manager, 'emma_librivox'));

    expect(manager.stateFor('emma_librivox')!.phase, DownloadPhase.done);
    final saved = (await db.getAudiobook('emma_librivox'))!;
    expect(saved.isDownloaded, isTrue);
    expect(saved.source, 'Downloaded');
    expect(saved.origin, BookIdentity.originLibrivox);
    expect(saved.chapters.map((c) => c.title), ['Chapter 1', 'Chapter 2']);
    expect(saved.chapters.map((c) => c.durationSeconds), [60, 120]);
    expect(
        saved.chapters.first.audioPathOrUrl,
        p.join(root.path, 'Audiobooks', 'Diegema', 'Emma [emma_librivox]',
            '01.mp3'));
    expect(
        Directory(p.join(root.path, 'Audiobooks'))
            .listSync(recursive: true)
            .whereType<File>()
            .map((f) => p.basename(f.path)),
        unorderedEquals(['01.mp3', '02.mp3']));
    // The ZIP and the task record are dropped; progress survived.
    expect(engine.forgotten, contains('emma_librivox'));
    expect((await db.getProgress('emma_librivox'))!.positionSeconds, 30);
  });

  test('without a matching feed, chapters are named after their files',
      () async {
    await manager.download(emma, feed: [_feed(0)]);
    landZip('emma_librivox', {
      'emma_01.mp3': [1],
      'emma_02.mp3': [2],
    });
    engine.emit(engine.enqueued.single, status: EngineStatus.complete);
    await _until(() => !_busy(manager, 'emma_librivox'));
    final saved = (await db.getAudiobook('emma_librivox'))!;
    expect(saved.chapters.map((c) => c.id),
        ['emma_librivox_local_0', 'emma_librivox_local_1']);
    expect(saved.chapters.map((c) => c.durationSeconds), [0, 0]);
    expect(
        DownloadJob.fromLibriVox(emma)
            .toBook(['/a/emma_01.mp3', '/a/emma_02.MP3'])
            .chapters
            .map((c) => c.title),
        ['emma_01', 'emma_02']);
  });

  test('a ZIP with no audio fails, saves nothing and can be retried', () async {
    await manager.download(emma);
    landZip('emma_librivox', {
      'readme.txt': [1]
    });
    engine.emit(engine.enqueued.single, status: EngineStatus.complete);
    await _until(() => !_busy(manager, 'emma_librivox'));
    expect(manager.stateFor('emma_librivox')!.phase, DownloadPhase.failed);
    expect(await db.getAudiobook('emma_librivox'), isNull);

    await manager.retry('emma_librivox');
    expect(engine.enqueued, hasLength(2));
    expect(manager.stateFor('emma_librivox')!.phase, DownloadPhase.queued);
  });

  test('cancel stops the task, deletes what was fetched and clears the state',
      () async {
    await manager.download(emma);
    final job = engine.enqueued.single;
    engine.emit(job, status: EngineStatus.running);

    await manager.cancel('emma_librivox');
    expect(engine.cancelled, ['emma_librivox']);
    expect(engine.forgotten, ['emma_librivox']);
    expect(manager.stateFor('emma_librivox'), isNull);

    // The engine's own "canceled" echo, and a late progress tick, change
    // nothing.
    engine.emit(job, status: EngineStatus.canceled);
    engine.emit(job, progress: 0.5);
    expect(manager.stateFor('emma_librivox'), isNull);
  });

  test('a failure shows its reason; retry fetches it again', () async {
    await manager.download(emma);
    final job = engine.enqueued.single;
    engine.emit(job, status: EngineStatus.failed, error: 'socket closed');
    final failed = manager.stateFor('emma_librivox')!;
    expect(failed.phase, DownloadPhase.failed);
    expect(failed.error, contains('Check your connection'));

    await manager.retry('emma_librivox');
    expect(engine.forgotten, ['emma_librivox']);
    expect(engine.enqueued, hasLength(2));
    expect(manager.stateFor('emma_librivox')!.phase, DownloadPhase.queued);
  });

  test('pause and resume; a resume the engine cannot do starts over', () async {
    await manager.download(emma);
    final job = engine.enqueued.single;
    engine.emit(job, status: EngineStatus.running);
    await manager.pause('emma_librivox');
    expect(manager.stateFor('emma_librivox')!.phase, DownloadPhase.paused);

    await manager.resume('emma_librivox');
    expect(manager.stateFor('emma_librivox')!.phase, DownloadPhase.queued);
    expect(engine.enqueued, hasLength(1));

    engine.emit(job, status: EngineStatus.paused);
    engine.resumeWorks = false;
    await manager.resume('emma_librivox');
    expect(engine.enqueued, hasLength(2));
  });

  test(
      'a download that finished while the app was dead is saved once on '
      'the next launch', () async {
    await manager.download(emma, feed: [_feed(0)]);
    final job = engine.enqueued.single;
    manager.dispose();

    // The app is gone; the OS finishes the download and the plugin records
    // it. On relaunch both the persisted record and the replayed update
    // say "complete".
    landZip('emma_librivox', {
      '01.mp3': [1]
    });
    engine.persisted['emma_librivox'] =
        EngineUpdate(job, status: EngineStatus.complete);
    var finishes = 0;
    manager = DownloadManager(
        db: db,
        engine: engine,
        location: location,
        finish: (db, job, zip, root) {
          finishes++;
          return finishDownload(db, job, zip, root);
        });
    await manager.start();
    engine.emit(job, status: EngineStatus.complete);
    await _until(() => !_busy(manager, 'emma_librivox'));
    await _settle();

    expect(finishes, 1);
    expect(manager.stateFor('emma_librivox')!.phase, DownloadPhase.done);
    expect((await db.getAudiobook('emma_librivox'))!.chapters.single.title,
        'Chapter 1');
    expect(engine.persisted, isEmpty);
  });

  test('tasks still queued or failed at launch show up again', () async {
    manager.dispose();
    final a = DownloadJob.fromLibriVox(emma);
    final b = DownloadJob.fromLibriVox(persuasion);
    engine.persisted['emma_librivox'] =
        EngineUpdate(a, status: EngineStatus.running, progress: 0.4);
    engine.persisted['persuasion_librivox'] =
        EngineUpdate(b, status: EngineStatus.failed);
    manager = newManager();
    await manager.start();

    expect(engine.started, isTrue);
    expect(manager.stateFor('emma_librivox')!.progress, 0.4);
    expect(
        manager.stateFor('persuasion_librivox')!.phase, DownloadPhase.failed);
  });

  test('Wi-Fi only reaches the engine and every new task', () async {
    await manager.setWifiOnly(true);
    await manager.setWifiOnly(true);
    expect(engine.wifiSettings, [true]);

    await manager.download(emma);
    expect(engine.wifiFlags, [true]);
    expect(manager.waitingForWifi('emma_librivox'), isTrue);

    engine.emit(engine.enqueued.single, status: EngineStatus.running);
    expect(manager.waitingForWifi('emma_librivox'), isFalse);

    await manager.setWifiOnly(false);
    await manager.download(persuasion);
    expect(engine.wifiSettings, [true, false]);
    expect(engine.wifiFlags, [true, false]);
  });

  test(
      're-download uses the pre-built ZIP, falls back to compress when it '
      'is missing, and keeps chapter ids, titles and progress', () async {
    final gone = UnifiedAudiobook(
      id: 'tenn_librivox',
      title: '3 Science Fiction Stories',
      author: 'William Tenn',
      description: '',
      source: 'Downloaded',
      origin: BookIdentity.originLibrivox,
      isDownloaded: true,
      chapters: [
        for (var i = 0; i < 2; i++)
          AudiobookChapter(
              id: 'ch$i',
              title: 'Story ${i + 1}',
              audioPathOrUrl: '/nowhere/0$i.mp3',
              durationSeconds: 100),
      ],
    );
    await db.saveAudiobook(gone);
    await db.saveProgress(
        audiobookId: 'tenn_librivox', chapterIndex: 1, positionSeconds: 42);

    await manager.redownload(gone);
    expect(engine.enqueued.single.url, contains('/download/tenn_librivox/'));

    engine.emit(engine.enqueued.single, status: EngineStatus.notFound);
    await _settle();
    expect(engine.enqueued, hasLength(2));
    expect(engine.enqueued.last.url, contains('/compress/tenn_librivox/'));
    expect(manager.stateFor('tenn_librivox')!.phase, DownloadPhase.queued);

    // No third try when the fallback is missing too.
    landZip('tenn_librivox', {
      '01.mp3': [1],
      '02.mp3': [2],
    });
    engine.emit(engine.enqueued.last, status: EngineStatus.complete);
    await _until(() => !_busy(manager, 'tenn_librivox'));

    final saved = (await db.getAudiobook('tenn_librivox'))!;
    expect(saved.chapters.map((c) => c.id), ['ch0', 'ch1']);
    expect(saved.chapters.map((c) => c.title), ['Story 1', 'Story 2']);
    expect(saved.chapters.first.audioPathOrUrl,
        startsWith(p.join(root.path, 'Audiobooks', 'Diegema')));
    expect((await db.getProgress('tenn_librivox'))!.positionSeconds, 42);
  });

  test('a missing fallback ZIP fails rather than looping', () async {
    final job = DownloadJob.redownload(UnifiedAudiobook(
        id: 'x_librivox',
        title: 'X',
        author: '',
        description: '',
        isDownloaded: true,
        chapters: const []));
    await manager.redownload(job.toBook(const []));
    engine.emit(engine.enqueued.single, status: EngineStatus.notFound);
    await _settle();
    engine.emit(engine.enqueued.last, status: EngineStatus.notFound);
    await _settle();
    expect(engine.enqueued, hasLength(2));
    expect(manager.stateFor('x_librivox')!.phase, DownloadPhase.failed);
  });

  test('job metadata survives the round trip through the engine', () {
    final job = DownloadJob.fromLibriVox(emma, feed: [_feed(0)]);
    final back = DownloadJob.decode(job.encode())!;
    expect(back.id, 'emma_librivox');
    expect(back.url, job.url);
    expect(back.author, 'Jane Austen');
    expect(back.narrators, ['Reader']);
    expect(back.chapters.single.seconds, 60);
    expect(DownloadJob.decode('not json'), isNull);
  });
}
