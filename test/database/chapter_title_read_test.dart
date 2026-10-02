import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:diegema/core/utils/book_identity.dart';
import 'package:diegema/database/app_database.dart';
import 'package:diegema/domain/models/audiobook.dart';

void main() {
  test('a file-name chapter title reads back readable everywhere', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.saveAudiobook(UnifiedAudiobook(
      id: 'b',
      title: '3 Science Fiction Stories',
      author: 'William Tenn',
      description: '',
      source: 'Downloaded',
      origin: BookIdentity.originLibrivox,
      isDownloaded: true,
      chapters: [
        AudiobookChapter(
            id: 'c0',
            title: '3sfstoriesbywilliamtenn_01_tenn_64kb',
            audioPathOrUrl: '/b/01.mp3',
            durationSeconds: 0),
        AudiobookChapter(
            id: 'c1',
            title: 'Project Hush',
            audioPathOrUrl: '/b/02.mp3',
            durationSeconds: 0),
      ],
    ));
    final book = (await db.getAudiobook('b'))!;
    expect(book.chapters.map((c) => c.title), ['Part 1', 'Project Hush']);
  });
}
