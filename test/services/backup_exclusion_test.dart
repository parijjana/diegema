import 'dart:io';

import 'package:diegema/services/downloads_location.dart';
import 'package:diegema/services/folder_access.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/backup_exclusion');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return true;
    });
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test('on iOS the downloads root is created and flagged, nothing moved',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final docs = await Directory.systemTemp.createTemp('bk_excl_');
    addTearDown(() => docs.deleteSync(recursive: true));
    final library = Directory(p.join(docs.path, 'diegema', 'library'))
      ..createSync(recursive: true);

    final ok = await excludeDownloadsFromBackup(
      location: DownloadsLocation(documentsRoot: () async => docs.path),
      access: FolderAccess(enabled: true, channel: channel),
    );

    expect(ok, isTrue);
    expect(calls.single.method, 'excludeFromBackup');
    final root = p.join(docs.path, 'diegema', 'downloads');
    expect((calls.single.arguments as Map)['path'], root);
    expect(Directory(root).existsSync(), isTrue);
    // User imports are not touched or flagged.
    expect(library.existsSync(), isTrue);
  });

  test('off iOS it does nothing', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final ok = await excludeDownloadsFromBackup(
      location: DownloadsLocation(documentsRoot: () async => '/nonexistent'),
      access: FolderAccess(enabled: true, channel: channel),
    );
    expect(ok, isFalse);
    expect(calls, isEmpty);
  });
}
