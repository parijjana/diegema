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
}
