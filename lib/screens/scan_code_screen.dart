import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/sync/sync_controller.dart';
import '../sync/link_code.dart';
import '../theme/app_theme.dart';
import 'link_flow.dart';

/// "Scan a code" (phones): a camera view that reads the first Diegema link
/// code it sees, then joins with it. Pops true once linked.
class ScanCodeScreen extends StatefulWidget {
  const ScanCodeScreen({super.key});

  @override
  State<ScanCodeScreen> createState() => _ScanCodeScreenState();
}

class _ScanCodeScreenState extends State<ScanCodeScreen> {
  final MobileScannerController _camera =
      MobileScannerController(formats: const [BarcodeFormat.qrCode]);
  bool _handling = false;
  String? _message;

  @override
  void dispose() {
    _camera.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handling) return;
    String? code;
    for (final b in capture.barcodes) {
      final raw = b.rawValue;
      if (raw != null && raw.startsWith(LinkCode.prefix)) {
        code = raw;
        break;
      }
    }
    final sync = SyncScope.maybeOf(context);
    if (code == null || sync == null) return;
    _handling = true;
    await _camera.stop();
    if (!mounted) return;
    JoinOutcome? outcome;
    try {
      outcome = await joinWithConfirm(context, sync, code);
    } catch (_) {
      outcome = JoinOutcome.invalid;
    }
    if (!mounted) return;
    if (outcome != null && joinSucceeded(outcome)) {
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop(true);
      messenger.showSnackBar(SnackBar(content: Text(joinMessage(outcome))));
      return;
    }
    // Not joined: say why and look again.
    setState(() => _message = outcome == null ? null : joinMessage(outcome));
    _handling = false;
    await _camera.start();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(title: const Text('Scan a code')),
      body: Column(
        children: [
          Expanded(
            child: MobileScanner(
              controller: _camera,
              onDetect: _onDetect,
              errorBuilder: (context, error) => _CameraProblem(
                denied: error.errorCode ==
                    MobileScannerErrorCode.permissionDenied,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(Sp.x4),
            child: Text(
              _message ??
                  'Point the camera at the code on your other device.',
              textAlign: TextAlign.center,
              style: AppType.bodyLg
                  .copyWith(color: _message == null ? c.text : c.danger),
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraProblem extends StatelessWidget {
  final bool denied;
  const _CameraProblem({required this.denied});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Sp.x6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.no_photography_outlined,
                size: Dim.iconXl, color: c.textSecondary),
            const SizedBox(height: Sp.x3),
            Text(
              denied
                  ? 'Diegema needs the camera to scan a code. Allow it in Settings.'
                  : "The camera isn't available right now.",
              textAlign: TextAlign.center,
              style: AppType.bodyLg.copyWith(color: c.text),
            ),
            if (denied) ...[
              const SizedBox(height: Sp.x4),
              FilledButton(
                onPressed: () => openAppSettings(),
                child: const Text('Open Settings'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
