// ignore_for_file: prefer_const_constructors
// (the overrides maps must stay mutable, so these stores cannot be const)
import 'package:diegema/services/hidden_books_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('read is empty when nothing was hidden', () async {
    expect(await const HiddenBooksStore(overrides: {}).read(), isEmpty);
  });

  test('hide and unhide round-trip, and are idempotent', () async {
    final store = HiddenBooksStore(overrides: <String, List<String>>{});
    await store.hide('a');
    await store.hide('b');
    await store.hide('a');
    expect(await store.read(), {'a', 'b'});
    await store.unhide('a');
    await store.unhide('missing');
    expect(await store.read(), {'b'});
  });

  test('stores opaque ids without interpreting them', () async {
    final store = HiddenBooksStore(overrides: <String, List<String>>{});
    await store.hide('librivox:123|x y');
    expect(await store.read(), {'librivox:123|x y'});
  });

  test('changes notifies after hide and unhide', () async {
    final store = HiddenBooksStore(overrides: <String, List<String>>{});
    var n = 0;
    void l() => n++;
    HiddenBooksStore.changes.addListener(l);
    addTearDown(() => HiddenBooksStore.changes.removeListener(l));
    await store.hide('a');
    await store.unhide('a');
    expect(n, 2);
  });

  test('persists in SharedPreferences under hidden_book_ids.v1', () async {
    SharedPreferences.setMockInitialValues({});
    const store = HiddenBooksStore();
    await store.hide('a');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('hidden_book_ids.v1'), ['a']);
    expect(await store.read(), {'a'});
  });
}
