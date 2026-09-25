import 'package:flutter_test/flutter_test.dart';
import 'package:diegema/services/backfill_attempt_store.dart';

void main() {
  test('round-trips a map of ids to timestamps through the overrides store',
      () async {
    final overrides = <String, String>{};
    final store = BackfillAttemptStore(overrides: overrides);
    final at = DateTime(2026, 3, 1, 12, 30);

    await store.write({'book_a': at, 'book_b': at.add(const Duration(days: 1))});
    final read = await store.read();

    expect(read['book_a'], equals(at));
    expect(read['book_b'], equals(at.add(const Duration(days: 1))));
  });

  test('read returns empty map when nothing was ever written', () async {
    const store = BackfillAttemptStore(overrides: {});

    expect(await store.read(), isEmpty);
  });

  test('read tolerates corrupt stored JSON', () async {
    const store = BackfillAttemptStore(
        overrides: {'local_cover_backfill.attempted.v1': 'not json'});

    expect(await store.read(), isEmpty);
  });
}
