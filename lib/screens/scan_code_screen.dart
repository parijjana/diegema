import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// "Scan a code" (phones) -- STUB for v1.
///
/// Linked-device sync is off in v1 (DIEGEMA_SYNC flag), so nothing reaches
/// this screen. The camera scanner (mobile_scanner, which pulls Google ML Kit
/// and Firebase datatransport into the Android release) was removed from the
/// dependencies for the store build (audit S-03).
///
/// The full implementation is in git history:
///   git show cab5cea:lib/screens/scan_code_screen.dart
/// To restore it in v1.1: re-add `mobile_scanner` to pubspec.yaml, restore
/// that file, re-add the CAMERA permission and the proguard keep rules for
/// `dev.steenbakker.mobile_scanner` / `com.google.mlkit`, and update the
/// privacy policy and Play data-safety form.
class ScanCodeScreen extends StatelessWidget {
  const ScanCodeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(title: const Text('Scan a code')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(Sp.x4),
          child: Text(
            'Scanning a code is not available in this version.',
            textAlign: TextAlign.center,
            style: AppType.bodyLg.copyWith(color: c.text),
          ),
        ),
      ),
    );
  }
}
