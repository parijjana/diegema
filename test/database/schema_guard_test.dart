import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:diegema/database/app_database.dart';

void main() {
  late Directory dir;
  late File file;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('schema_guard');
    file = File(p.join(dir.path, 'diegema.sqlite'));
  });
  tearDown(() => dir.delete(recursive: true));

  Future<void> createDb() async {
    final db = AppDatabase(NativeDatabase(file));
    await db.getAllAudiobooks();
    await db.close();
  }

  Future<void> setStoredVersion(int version) async {
    final raf = await file.open(mode: FileMode.append);
    await raf.setPosition(60);
    final bytes = ByteData(4)..setUint32(0, version);
    await raf.writeFrom(bytes.buffer.asUint8List());
    await raf.close();
  }

  test('reads the schema version from the header', () async {
    expect(await AppDatabase.storedSchemaVersion(file), isNull);
    await createDb();
    expect(await AppDatabase.storedSchemaVersion(file), 3);

    await File(p.join(dir.path, 'not.sqlite')).writeAsString('hello');
    expect(
        await AppDatabase.storedSchemaVersion(
            File(p.join(dir.path, 'not.sqlite'))),
        isNull);
  });

  test(
      'an older library is copied aside before migrating; a current one '
      'is not', () async {
    await createDb();
    await AppDatabase.backupBeforeMigration(file);
    expect(dir.listSync().where((e) => e.path.endsWith('.bak')), isEmpty);

    await setStoredVersion(2);
    await AppDatabase.backupBeforeMigration(file);
    final backup = File('${file.path}.v2.bak');
    expect(await backup.exists(), isTrue);
    expect(await AppDatabase.storedSchemaVersion(backup), 2);
  });
}
