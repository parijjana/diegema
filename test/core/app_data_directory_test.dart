import 'dart:io';

import 'package:diegema/core/app_data_directory.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _FakePathProviderPlatform extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<String?> getApplicationDocumentsPath() async => '/documents';

  @override
  Future<String?> getApplicationSupportPath() async => '/support';
}

void main() {
  setUp(() => PathProviderPlatform.instance = _FakePathProviderPlatform());

  test('Windows keeps app data in the support folder, not Documents', () async {
    final dir = await appDataDirectory(platform: TargetPlatform.windows);
    expect(dir.path, '/support');
  });

  test('Android, iOS and macOS keep the documents folder they always had',
      () async {
    for (final platform in [
      TargetPlatform.android,
      TargetPlatform.iOS,
      TargetPlatform.macOS,
    ]) {
      final dir = await appDataDirectory(platform: platform);
      expect(dir.path, '/documents', reason: '$platform');
    }
  });

  test('every service resolves the folder through appDataDirectory', () {
    // A direct call would put that service's files in Windows' Documents.
    final offenders = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => p.basename(f.path) != 'app_data_directory.dart')
        .where((f) =>
            f.readAsStringSync().contains('getApplicationDocumentsDirectory('))
        .map((f) => f.path)
        .toList();
    expect(offenders, isEmpty);
  });
}
