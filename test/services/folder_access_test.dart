import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:diegema/services/folder_access.dart';
import 'package:diegema/services/library_locations_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('diegema/folder_access');
  late List<MethodCall> calls;
  late Map<String, Object?> Function(String bookmark)? openResult;

  setUp(() {
    calls = [];
    openResult = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'bookmark':
          return 'fresh-${(call.arguments as Map)['path']}';
        case 'open':
          return openResult
              ?.call((call.arguments as Map)['bookmark'] as String);
      }
      return null;
    });
  });

  tearDown(() => TestDefaultBinaryMessengerBinding
      .instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, null));

  LibraryLocationsStore newStore() =>
      LibraryLocationsStore(overrides: <String, List<String>>{}..clear());

  group('LibraryLocationsStore bookmarks', () {
    test('stored with the location, refreshed on re-add, cleared on remove',
        () async {
      final store = newStore();
      expect(await store.add('/Books/A', bookmark: 'b1'), isTrue);
      await store.add('/Books/B');
      expect(await store.readBookmarks(), {'/Books/A': 'b1'});

      expect(await store.add('/Books/A', bookmark: 'b2'), isFalse);
      expect(await store.readBookmarks(), {'/Books/A': 'b2'});

      await store.remove('/Books/A');
      expect(await store.read(), ['/Books/B']);
      expect(await store.readBookmarks(), isEmpty);
    });

    test('a path containing a tab survives the round trip', () async {
      final store = newStore();
      await store.add('/Books/odd\tname', bookmark: 'b64+/=');
      expect(await store.readBookmarks(), {'/Books/odd\tname': 'b64+/='});
    });
  });

  group('FolderAccess', () {
    test('does nothing where bookmarks are not needed', () async {
      final access = FolderAccess(enabled: false);
      expect(await access.bookmark('/x'), isNull);
      expect(await access.open('b'), isNull);
      await access.close('/x');
      expect(calls, isEmpty);
    });

    test('a folder that cannot be opened is null, not an error', () async {
      expect(await FolderAccess(enabled: true).open('gone'), isNull);
    });
  });

  group('openLibraryLocations', () {
    test('opens every bookmarked folder and re-saves stale ones', () async {
      final store = newStore();
      await store.add('/Books/A', bookmark: 'a');
      await store.add('/Books/B', bookmark: 'b');
      openResult = (bookmark) => {
            'path': bookmark == 'a' ? '/Books/A' : '/Books/B/',
            'stale': bookmark == 'b',
          };

      await openLibraryLocations(
          store: store, access: FolderAccess(enabled: true));

      expect(calls.where((c) => c.method == 'open').length, 2);
      expect(await store.readBookmarks(),
          {'/Books/A': 'a', '/Books/B': 'fresh-/Books/B'});
    });

    test('a moved or missing folder is left alone', () async {
      final store = newStore();
      await store.add('/Books/A', bookmark: 'a');
      await store.add('/Books/B', bookmark: 'b');
      openResult = (bookmark) => {
            if (bookmark == 'a') ...{'path': '/Elsewhere/A', 'stale': true}
          };

      await openLibraryLocations(
          store: store, access: FolderAccess(enabled: true));

      expect(calls.where((c) => c.method == 'bookmark'), isEmpty);
      expect(await store.readBookmarks(), {'/Books/A': 'a', '/Books/B': 'b'});
      expect(await store.read(), ['/Books/A', '/Books/B']);
    });
  });
}
