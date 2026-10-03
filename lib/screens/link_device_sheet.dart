import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../services/sync/sync_controller.dart';
import '../theme/app_theme.dart';

/// Whether this device must dial the one that scans its code: a Mac never
/// listens. Uses the framework's platform value, so it is web-safe and a
/// test can override it.
bool get isMacHost =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

/// "Link a device": shows a code for the other device to scan.
/// [pollForScanner] defaults to [isMacHost].
Future<void> showLinkDeviceSheet(BuildContext context,
    {bool? pollForScanner}) {
  final sync = SyncScope.maybeOf(context);
  if (sync == null) return Future.value();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => LinkDeviceSheet(
        sync: sync, pollForScanner: pollForScanner ?? isMacHost),
  );
}

class LinkDeviceSheet extends StatefulWidget {
  final SyncController sync;

  /// Also call `syncNow()` every few seconds while open (a Mac).
  final bool pollForScanner;

  const LinkDeviceSheet(
      {super.key, required this.sync, required this.pollForScanner});

  @override
  State<LinkDeviceSheet> createState() => _LinkDeviceSheetState();
}

class _LinkDeviceSheetState extends State<LinkDeviceSheet> {
  static const _pollEvery = Duration(seconds: 3);

  LinkOffer? _offer;
  bool _failed = false;
  bool _copied = false;
  int _secondsLeft = 0;
  String? _linkedTo;
  late final Set<String> _before;
  Timer? _countdown;
  Timer? _poll;
  bool _polling = false;

  @override
  void initState() {
    super.initState();
    _before = {...?widget.sync.view.value?.otherDeviceIds()};
    widget.sync.view.addListener(_onView);
    _fetch();
    // A device that scanned the code only shows up after a sync; a phone is
    // dialled by it, a Mac has to dial the phone itself.
    if (widget.pollForScanner && !widget.sync.canScan) {
      _poll = Timer.periodic(_pollEvery, (_) => _pollOnce());
    }
  }

  @override
  void dispose() {
    widget.sync.view.removeListener(_onView);
    _countdown?.cancel();
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _pollOnce() async {
    if (_polling || _linkedTo != null) return;
    _polling = true;
    try {
      await widget.sync.syncNow();
    } catch (_) {
      // Nobody there yet; try again next time.
    } finally {
      _polling = false;
    }
  }

  void _onView() {
    if (_linkedTo != null || !mounted) return;
    final view = widget.sync.view.value;
    if (view == null) return;
    for (final id in view.otherDeviceIds()) {
      if (!_before.contains(id)) {
        _countdown?.cancel();
        _poll?.cancel();
        setState(() => _linkedTo = view.deviceName(id));
        return;
      }
    }
  }

  Future<void> _newCode() {
    _countdown?.cancel();
    setState(() {
      _offer = null;
      _failed = false;
      _copied = false;
    });
    return _fetch();
  }

  Future<void> _fetch() async {
    try {
      final offer = await widget.sync.createLinkOffer();
      if (!mounted) return;
      _secondsLeft = offer.expiresAt.difference(DateTime.now()).inSeconds;
      setState(() => _offer = offer);
      _countdown = Timer.periodic(const Duration(seconds: 1), (_) {
        if (_secondsLeft <= 1) {
          _countdown?.cancel();
          setState(() => _secondsLeft = 0);
        } else {
          setState(() => _secondsLeft--);
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  Future<void> _copy() async {
    final offer = _offer;
    if (offer == null) return;
    await Clipboard.setData(ClipboardData(text: offer.code));
    if (!mounted) return;
    setState(() => _copied = true);
  }

  static String _clock(int seconds) =>
      '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final Widget body;
    if (_linkedTo != null) {
      body = _linked(c);
    } else if (_failed) {
      body = _message(c, "Linking isn't available on this device right now.");
    } else if (_offer == null) {
      body = const Padding(
        padding: EdgeInsets.all(Sp.x8),
        child: Center(child: CircularProgressIndicator()),
      );
    } else {
      body = _offerBody(c, _offer!);
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Sp.x4, 0, Sp.x4, Sp.x6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text('Link a device',
                style: AppType.titleMd.copyWith(color: c.text)),
          ),
          const SizedBox(height: Sp.x2),
          body,
        ],
      ),
    );
  }

  Widget _message(AppColors c, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: Sp.x4),
        child: Text(text, style: AppType.bodyLg.copyWith(color: c.text)),
      );

  Widget _linked(AppColors c) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _message(c, 'Linked to $_linkedTo'),
          FilledButton(
            style: FilledButton.styleFrom(
                minimumSize: const Size(0, Dim.tapMin)),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      );

  Widget _offerBody(AppColors c, LinkOffer offer) {
    final expired = _secondsLeft <= 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'On your other device, open Diegema → Settings → Linked devices → '
          'Scan a code.',
          style: AppType.body.copyWith(color: c.textSecondary),
        ),
        const SizedBox(height: Sp.x4),
        Center(
          child: LayoutBuilder(builder: (context, constraints) {
            final side = constraints.maxWidth.clamp(0.0, 240.0);
            return Opacity(
              opacity: expired ? 0.15 : 1,
              child: Semantics(
                label: 'Link code',
                image: true,
                // A white tile in both themes: scanners need dark modules
                // on a light field, and the padding is the quiet zone.
                child: Container(
                  width: side,
                  height: side,
                  padding: const EdgeInsets.all(Sp.x3),
                  decoration: const BoxDecoration(
                      color: Colors.white, borderRadius: R.md),
                  child: QrImageView(
                    data: offer.code,
                    padding: EdgeInsets.zero,
                    backgroundColor: Colors.white,
                    eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square, color: Colors.black),
                    dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Colors.black),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: Sp.x3),
        Center(
          child: Text(
            expired ? 'This code has expired.' : 'Good for ${_clock(_secondsLeft)}',
            style: AppType.tabularBody(expired ? c.danger : c.textSecondary),
          ),
        ),
        const SizedBox(height: Sp.x3),
        Container(
          padding: const EdgeInsets.all(Sp.x3),
          decoration: BoxDecoration(
            color: c.surfaceSunken,
            borderRadius: R.md,
            border: Border.all(color: c.border),
          ),
          child: Text(
            offer.code,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: AppType.caption.copyWith(color: c.text),
          ),
        ),
        const SizedBox(height: Sp.x3),
        if (expired)
          FilledButton(
            style: FilledButton.styleFrom(
                minimumSize: const Size(0, Dim.tapMin)),
            onPressed: _newCode,
            child: const Text('Show a new code'),
          )
        else
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, Dim.tapMin)),
            onPressed: _copy,
            icon: Icon(_copied ? Icons.check_rounded : Icons.copy_rounded),
            label: Text(_copied ? 'Copied' : 'Copy'),
          ),
      ],
    );
  }
}
