import 'dart:convert';
import 'dart:io';

import 'package:diegema/sync_cli/sync_tool.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('on Windows the CLI finds the app in its %APPDATA% support folder',
      () async {
    final appData = await Directory.systemTemp.createTemp('dg_appdata');
    addTearDown(() => appData.delete(recursive: true));
    final data = p.join(appData.path, 'Overengineered Hobbies', 'Diegema');
    await Directory(data).create(recursive: true);
    await File(p.join(data, 'shared_preferences.json'))
        .writeAsString(jsonEncode({'flutter.sync.device_id.v1': 'pc000001'}));

    final app = await AppData.resolve(environment: {'APPDATA': appData.path});

    expect(app.database.path, p.join(data, 'diegema.sqlite'));
    expect(app.secrets!.path, p.join(data, 'sync_secrets.json'));
    expect(app.deviceId, 'pc000001');
  }, skip: !Platform.isWindows);
}
