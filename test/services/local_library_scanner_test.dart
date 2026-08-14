import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:diegema/core/utils/book_identity.dart';
import 'package:diegema/database/app_database.dart';
import 'package:diegema/services/local_library_scanner.dart';

/// The downloads-folder scan used to be untestable: it called
/// `getApplicationDocumentsDirectory()` directly, so under `flutter_test`
/// it threw `MissingPluginException` on every run — which `LibraryScreen`
/// caught, printed, and turned into an error state. With the documents root
/// injectable the real walk can be driven against a temp directory.
void main() {
  late AppDatabase db;
  late Directory root;
  late Directory downloads;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    root = await Directory.systemTemp.createTemp('scanner_test');
    downloads =
        Directory(p.join(root.path, 'diegema', 'downloads'));
  });

  tearDown(() async {
    await db.close();
    if (await root.exists()) await root.delete(recursive: true);
  });

  Future<void> scan() =>
      scanDownloadedLibrary(db, documentsRoot: () async => root.path);

  Directory bookFolder(String name, List<String> files) {
    final dir = Directory(p.join(downloads.path, name))
      ..createSync(recursive: true);
    for (final f in files) {
      File(p.join(dir.path, f)).writeAsBytesSync(const [0]);
    }
    return dir;
  }

  test('registers a downloaded book folder, chapters in filename order',
      () async {
    final dir = bookFolder('Pride_and_Prejudice',
        ['02-chapter-two.mp3', '01-chapter-one.mp3', 'cover.jpg']);

    await scan();

    final books = await db.getAllAudiobooks();
    expect(books, hasLength(1));
    final book = books.single;
    expect(book.title, 'Pride and Prejudice');
    expect(book.id, BookIdentity.localIdForPath(dir.path));
    expect(book.origin, BookIdentity.originLocal);
    expect(book.isDownloaded, isTrue);
    // Sorted by path, and the non-audio file is ignored.
    expect(book.chapters.map((c) => c.title),
        ['01-chapter-one', '02-chapter-two']);
    expect(book.chapters.every((c) => !c.isStream), isTrue);
  });

  test('is idempotent — a second scan adds nothing', () async {
    bookFolder('Middlemarch', ['01.mp3']);

    await scan();
    await scan();

    expect(await db.getAllAudiobooks(), hasLength(1));
  });

  test('skips folders with no audio and a missing downloads directory',
      () async {
    // No downloads directory at all.
    await scan();
    expect(await db.getAllAudiobooks(), isEmpty);

    bookFolder('Just_Art', ['cover.jpg']);
    await scan();
    expect(await db.getAllAudiobooks(), isEmpty);
  });

  test('no documents root means no scan and no throw', () async {
    bookFolder('Middlemarch', ['01.mp3']);

    await scanDownloadedLibrary(db, documentsRoot: () async => null);

    expect(await db.getAllAudiobooks(), isEmpty);
  });
}
