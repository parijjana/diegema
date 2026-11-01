import 'dart:io';

import 'package:diegema/services/windows_audio_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('libmpv verifies certificates against the bundled root list', () {
    final exe = p.join('app', 'diegema.exe');
    expect(windowsMpvProperties(exe), {
      'tls-verify': 'yes',
      'tls-ca-file': p.join('app', 'data', 'cacert.pem'),
    });
  });

  test('the root list is in the repo and the Windows build installs it', () {
    expect(File('windows/tls/cacert.pem').readAsStringSync(),
        contains('BEGIN CERTIFICATE'));
    expect(File('windows/CMakeLists.txt').readAsStringSync(),
        contains('tls/cacert.pem'));
  });
}
