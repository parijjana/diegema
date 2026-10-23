import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:diegema/core/utils/book_identity.dart';
import 'package:diegema/database/app_database.dart';
import 'package:diegema/domain/models/audiobook.dart';
import 'package:diegema/services/redownload_io.dart';

void main() {
  late AppDatabase db;
  late Directory root;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    root = await Directory.systemTemp.createTemp('redownload');
  });

  tearDown(() async {
    await db.close();
    await root.delete(recursive: true);
  });

  UnifiedAudiobook gone() => UnifiedAudiobook(
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

  test(
      'a missing downloaded file is unreadable; streams and imports are not '
      'offered a re-download', () async {
    expect(await downloadedChapterReadable(gone(), 0), isFalse);
    expect(canRedownload(gone()), isTrue);
    final local = UnifiedAudiobook(
        id: '${BookIdentity.localIdPrefix}x',
        title: 't',
        author: 'a',
        description: '',
        source: 'Library folder',
        origin: BookIdentity.originLocal,
        isDownloaded: true,
        chapters: const []);
    expect(canRedownload(local), isFalse);
  });
  // Re-downloading itself: see download_manager_test.dart.
}
