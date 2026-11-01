import 'dart:io' show Platform;

import 'package:diegema/core/app_licenses.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Inter OFL text is bundled and registered', () async {
    registerAppLicenses();
    final entries = await LicenseRegistry.licenses.toList();
    final inter = entries.where((e) => e.packages.contains('Inter typeface'));
    expect(inter, isNotEmpty);
    final text = inter.first.paragraphs.map((p) => p.text).join('\n');
    expect(text, contains('SIL Open Font License'));
  });

  test('the Windows notice names the libmpv licence and ships its text',
      () async {
    registerAppLicenses();
    final entries = await LicenseRegistry.licenses.toList();
    final mpv = entries.where((e) => e.packages.contains('mpv'));
    expect(mpv, isNotEmpty);
    final text = mpv.first.paragraphs.map((p) => p.text).join('\n');
    expect(text, contains('GNU LESSER GENERAL PUBLIC LICENSE'));
    expect(text, contains('GNU GENERAL PUBLIC LICENSE'));
    expect(text, isNot(contains('not yet been confirmed')));
    expect(
        entries
            .where((e) => e.packages.contains('Mozilla CA root certificates')),
        isNotEmpty);
  }, skip: Platform.isWindows ? false : 'Windows-only notice');
}
