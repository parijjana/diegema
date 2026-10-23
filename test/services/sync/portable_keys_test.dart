import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:diegema/database/app_database_io.dart';
import 'package:diegema/domain/models/audiobook.dart';
import 'package:diegema/services/sync/portable_keys_io.dart';

UnifiedAudiobook book(String id, List<String> files,
        {String origin = 'local'}) =>
    UnifiedAudiobook(
      id: id,
      title: id,
      author: '',
      description: '',
      origin: origin,
      chapters: [
        for (var i = 0; i < files.length; i++)
          AudiobookChapter(
              id: '${id}_$i',
              title: 'Ch $i',
              audioPathOrUrl: files[i],
              durationSeconds: 0,
              isStream: false),
      ],
    );

void main() {
  late Directory dir;
  setUp(() async => dir = await Directory.systemTemp.createTemp('ck'));
  tearDown(() async => dir.delete(recursive: true));

  String write(String rel, List<int> bytes) {
    final f = File(p.join(dir.path, rel))
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes);
    return f.path;
  }

  test('LibriVox books key by archive id, local ids never do', () {
    expect(librivoxKeyFor(book('emma_librivox', [], origin: 'librivox')),
        'lv:emma_librivox');
    expect(librivoxKeyFor(book('local_abc', [], origin: 'librivox')), isNull);
    expect(librivoxKeyFor(book('emma_librivox', [])), isNull);
  });

  test('the same files in different folders give the same content key',
      () async {
    final a = [
      write('mac/b/01.mp3', List.filled(70000, 1)),
      write('mac/b/02.mp3', [2, 2])
    ];
    final b = [
      write('phone/x/01.mp3', List.filled(70000, 1)),
      write('phone/x/02.mp3', [2, 2])
    ];
    expect(await contentKeyFor(a), await contentKeyFor(b));
    expect(await contentKeyFor(a), startsWith('ck:'));
  });

  test('different audio gives a different key', () async {
    final a = await contentKeyFor([
      write('a.m4b', [1, 2, 3])
    ]);
    final b = await contentKeyFor([
      write('b.m4b', [1, 2, 4])
    ]);
    final c = await contentKeyFor([
      write('c.m4b', [1, 2, 3, 0])
    ]);
    expect({a, b, c}, hasLength(3));
  });

  test('chapters sharing one M4B count the file once', () async {
    final f = write('book.m4b', [9, 9, 9]);
    expect(await contentKeyFor([f, f, f]), await contentKeyFor([f]));
  });

  test('unreadable files give no key', () async {
    expect(await contentKeyFor([p.join(dir.path, 'missing.mp3')]), isNull);
    expect(await contentKeyFor([]), isNull);
  });

  test('fillPortableKeys sets keys once and retries unreadable books',
      () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.saveAudiobook(book('emma_librivox', [], origin: 'librivox'));
    await db.saveAudiobook(book('local_1', [
      write('l/1.mp3', [1])
    ]));
    final missing = p.join(dir.path, 'later.mp3');
    await db.saveAudiobook(book('local_2', [missing]));

    expect(await fillPortableKeys(db), 2);
    expect((await db.portableKeys())['emma_librivox'], 'lv:emma_librivox');
    expect(await fillPortableKeys(db), 0);

    File(missing).writeAsBytesSync([5]);
    expect(await fillPortableKeys(db), 1);
  });
}
