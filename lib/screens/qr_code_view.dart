import 'package:flutter/material.dart';

/// Draws [data] as a QR code. v1 has no sync and ships without the
/// `qr_flutter` plugin, so this is a placeholder: the link sheet is unreachable
/// while sync is off, and shows the code as text beside this tile anyway.
/// v1.1 restores the real drawing from `parked/sync-v1.1/README.md`.
class QrCodeView extends StatelessWidget {
  final String data;
  const QrCodeView({super.key, required this.data});

  @override
  Widget build(BuildContext context) => const Center(
        child: Icon(Icons.qr_code_2, size: 64, color: Colors.black54),
      );
}
