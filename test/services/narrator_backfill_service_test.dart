import 'package:diegema/database/app_database.dart';
import 'package:diegema/domain/models/audiobook.dart';
import 'package:diegema/services/librivox_service.dart';
import 'package:diegema/services/narrator_backfill_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeService extends LibriVoxService {
  final Map<String, List<String>?> answers;
  final bool fail;
  final calls = <String>[];
  _FakeService(this.answers, {this.fail = false});

  @override
  Future<List<String>?> narratorsForArchiveId(String archiveId, String title) {
    calls.add(archiveId);
    if (fail) throw Exception('offline');
    return Future.value(answers[archiveId]);
  }
}

UnifiedAudiobook _book(String id,
        {String origin = 'librivox', List<String> n = const []}) =>
    UnifiedAudiobook(
        id: id,
        title: id,
        author: 'A',
        description: '',
        origin: origin,
        narrators: n);

void main() {
  late AppDatabase db;
  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.saveAudiobook(_book('a_1_librivox'));
    await db.saveAudiobook(_book('b_2_librivox', n: const ['Kept']));
    await db.saveAudiobook(_book('gone_3_librivox'));
    await db.saveAudiobook(_book('local_x', origin: 'local'));
  });
  tearDown(() => db.close());

  test('fills missing readers, skips filled and local, then stops rerunning',
      () async {
    final prefs = <String, Object>{};
    final svc = _FakeService({
      'a_1_librivox': ['Ann'],
      'gone_3_librivox': null
    });
    await NarratorBackfillService(db: db, service: svc, overrides: prefs).run();

    expect(svc.calls, ['a_1_librivox', 'gone_3_librivox']);
    expect((await db.getAudiobook('a_1_librivox'))!.narrators, ['Ann']);
    expect((await db.getAudiobook('b_2_librivox'))!.narrators, ['Kept']);
    expect(prefs[NarratorBackfillService.doneKey], 1);

    await NarratorBackfillService(db: db, service: svc, overrides: prefs).run();
    expect(svc.calls.length, 2);
  });

  test('a failure leaves the flag unset and retries only up to the cap',
      () async {
    final prefs = <String, Object>{};
    final svc = _FakeService({}, fail: true);
    for (var i = 0; i < 5; i++) {
      await NarratorBackfillService(db: db, service: svc, overrides: prefs)
          .run();
    }
    expect(prefs[NarratorBackfillService.doneKey], isNull);
    // One call per launch (it stops at the first failure), 3 launches max.
    expect(svc.calls.length, NarratorBackfillService.maxAttempts);
  });
}
