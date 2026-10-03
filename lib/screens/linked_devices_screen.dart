import 'dart:async';

import 'package:flutter/material.dart';

import '../services/sync/sync_controller.dart';
import '../sync/sync_view.dart';
import '../theme/app_theme.dart';
import 'link_device_sheet.dart';
import 'link_flow.dart';
import 'scan_code_screen.dart';

/// Settings -> Linked devices: this device's name, and every other device
/// whose records have reached this one, and the ways to link another:
/// show a code, scan one (phones), or paste one.
class LinkedDevicesScreen extends StatefulWidget {
  /// Passed to the "Link a device" sheet; null means "is this a Mac".
  final bool? pollForScanner;

  /// The time source for "synced 3 min ago"; tests pass a fake one.
  final DateTime Function()? now;

  const LinkedDevicesScreen({super.key, this.pollForScanner, this.now});

  @override
  State<LinkedDevicesScreen> createState() => _LinkedDevicesScreenState();
}

class _LinkedDevicesScreenState extends State<LinkedDevicesScreen> {
  final TextEditingController _name = TextEditingController();
  String _savedName = '';
  bool _loaded = false;
  SyncStatus? _status;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
    _startTicker();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      _loadName();
      _loadStatus();
    }
  }

  Future<void> _loadStatus() async {
    final sync = SyncScope.maybeOf(context);
    if (sync == null) return;
    final status = await sync.status();
    if (!mounted) return;
    setState(() => _status = status);
  }

  /// True when `await`ing [action] is followed by a status reload.
  Future<void> _then(Future<void> action) async {
    await action;
    if (mounted) await _loadStatus();
  }

  Future<bool> _confirm(String title, String body, String yes,
      {bool destructive = true}) async {
    final c = context.colors;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
              style: TextButton.styleFrom(
                  minimumSize: const Size(Dim.tapMin, Dim.tapMin)),
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              style: TextButton.styleFrom(
                  minimumSize: const Size(Dim.tapMin, Dim.tapMin),
                  foregroundColor: destructive ? c.danger : null),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(yes)),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _reset() async {
    final sync = SyncScope.maybeOf(context);
    if (sync == null) return;
    if (!await _confirm(
        'Reset sync?',
        'This device will need to be linked again. Your library stays.',
        'Reset sync')) {
      return;
    }
    await sync.resetKeys();
    if (mounted) await _loadStatus();
  }

  Future<void> _unlink() async {
    final sync = SyncScope.maybeOf(context);
    if (sync == null) return;
    if (!await _confirm(
        'Unlink this device?',
        'It stops syncing and forgets your other devices\' places. '
            'Your library stays.',
        'Unlink')) {
      return;
    }
    await sync.unlink();
    if (mounted) await _loadStatus();
  }

  Future<void> _remove(String id, String name) async {
    final sync = SyncScope.maybeOf(context);
    if (sync == null) return;
    if (!await _confirm(
        'Remove $name?',
        'It disappears from your devices\' lists. If it\'s still linked, '
            'it comes back the next time it syncs. To stop a lost device '
            'syncing, unlink all your devices and link them again.',
        'Remove')) {
      return;
    }
    await sync.forgetDevice(id);
    if (mounted) await _loadStatus();
  }

  // --- Sync now ---
  bool _syncing = false;
  Timer? _ticker;
  late DateTime _now = _clock();

  DateTime _clock() => (widget.now ?? DateTime.now)();

  void _startTicker() {
    _ticker ??= Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _now = _clock());
    });
  }

  Future<void> _syncNow() async {
    final sync = SyncScope.maybeOf(context);
    if (sync == null || _syncing) return;
    setState(() => _syncing = true);
    try {
      await sync.syncNow();
    } catch (_) {
      // The result line reports what happened; a failure is "none found".
    }
    if (!mounted) return;
    setState(() {
      _syncing = false;
      _now = _clock();
    });
  }

  static String _ago(Duration d) {
    if (d.inSeconds < 60) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    if (d.inHours < 24) {
      return d.inHours == 1 ? '1 hour ago' : '${d.inHours} hours ago';
    }
    return d.inDays == 1 ? '1 day ago' : '${d.inDays} days ago';
  }

  static String _lastSyncText(LastSync? last, DateTime now) {
    if (last == null) return 'Not synced yet since the app opened';
    final ago = _ago(now.difference(last.at));
    if (last.reached == 0) {
      return 'Last tried $ago: no linked devices found on this Wi-Fi';
    }
    final n = last.reached;
    return 'Synced $ago with $n ${n == 1 ? 'device' : 'devices'}';
  }

  Future<void> _loadName() async {
    final sync = SyncScope.maybeOf(context);
    if (sync == null) return;
    final name = await sync.deviceName();
    if (!mounted) return;
    _savedName = name;
    _name.text = name;
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _name.dispose();
    super.dispose();
  }

  bool get _canSave {
    final text = _name.text.trim();
    return text.isNotEmpty && text != _savedName;
  }

  Future<void> _save() async {
    final sync = SyncScope.maybeOf(context);
    final text = _name.text.trim();
    if (sync == null || text.isEmpty) return;
    FocusScope.of(context).unfocus();
    await sync.setDeviceName(text);
    if (!mounted) return;
    setState(() => _savedName = text);
  }

  static final ButtonStyle _actionStyle = ButtonStyle(
      minimumSize: WidgetStateProperty.all(const Size(0, Dim.tapMin)));

  static String _platformLabel(String platform) => switch (platform) {
        'macos' => 'macOS',
        'ios' => 'iOS',
        'android' => 'Android',
        'windows' => 'Windows',
        'linux' => 'Linux',
        _ => platform,
      };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final view = SyncScope.viewOf(context);
    final others = view?.otherDeviceIds() ?? const <String>[];
    final sync = SyncScope.maybeOf(context);
    final canScan = sync?.canScan ?? false;
    final status = _status;
    final isMac = widget.pollForScanner ?? isMacHost;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(title: const Text('Linked devices')),
      body: LayoutBuilder(builder: (context, constraints) {
        final gutter = constraints.maxWidth >= Dim.wideBreakpoint
            ? Sp.gutterDesktop
            : Sp.gutterPhone;
        return ListView(
          padding: EdgeInsets.fromLTRB(gutter, Sp.x4, gutter, Sp.x8),
          children: [
            Semantics(
              header: true,
              child: Text('This device',
                  style: AppType.titleSm.copyWith(color: c.textSecondary)),
            ),
            const SizedBox(height: Sp.x3),
            TextField(
              controller: _name,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
              style: AppType.body.copyWith(color: c.text),
              decoration: const InputDecoration(
                labelText: 'Device name',
                helperText: 'Other devices show this name.',
                helperMaxLines: 2,
              ),
            ),
            if (_canSave)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  style: TextButton.styleFrom(
                      minimumSize: const Size(Dim.tapMin, Dim.tapMin)),
                  onPressed: _save,
                  child: const Text('Save name'),
                ),
              ),
            if (status == SyncStatus.keysUnreadable) ...[
              const SizedBox(height: Sp.sectionGap),
              Container(
                decoration: BoxDecoration(
                  color: c.dangerWash,
                  borderRadius: R.md,
                  border: Border.all(color: c.danger),
                ),
                padding: const EdgeInsets.all(Sp.x3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        'Sync can\'t start on this device. Its saved link can\'t '
                        'be read, which can happen after restoring from a '
                        'backup.',
                        style: AppType.body.copyWith(color: c.text)),
                    const SizedBox(height: Sp.x3),
                    FilledButton(
                      style: _actionStyle.copyWith(
                          backgroundColor: WidgetStateProperty.all(c.danger)),
                      onPressed: _reset,
                      child: const Text('Reset sync'),
                    ),
                  ],
                ),
              ),
            ],
            if (status == SyncStatus.unlinked) ...[
              const SizedBox(height: Sp.x3),
              Text(
                  'Link your phone, tablet and computers to keep your place in '
                  'each book in step. Sync works when they\'re on the same '
                  'Wi-Fi.',
                  style: AppType.body.copyWith(color: c.textSecondary)),
              const SizedBox(height: Sp.sectionGap),
              Semantics(
                header: true,
                child: Text('Link another device',
                    style: AppType.titleSm.copyWith(color: c.textSecondary)),
              ),
              const SizedBox(height: Sp.x3),
              FilledButton.icon(
                style: _actionStyle,
                onPressed: () => _then(showLinkDeviceSheet(context,
                    pollForScanner: widget.pollForScanner)),
                icon: const Icon(Icons.qr_code_2_rounded),
                label: const Text('Link a device'),
              ),
              if (canScan) ...[
                const SizedBox(height: Sp.x2),
                OutlinedButton.icon(
                  style: _actionStyle,
                  onPressed: () => _then(Navigator.of(context).push(
                      MaterialPageRoute<bool>(
                          builder: (_) => const ScanCodeScreen()))),
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  label: const Text('Scan a code'),
                ),
              ],
              const SizedBox(height: Sp.x2),
              OutlinedButton.icon(
                style: _actionStyle,
                onPressed: () => _then(showPasteCodeDialog(context)),
                icon: const Icon(Icons.content_paste_rounded),
                label: const Text('Paste a code'),
              ),
            ],
            if (status == SyncStatus.linked) ...[
              const SizedBox(height: Sp.sectionGap),
              Semantics(
                header: true,
                child: Text('Sync',
                    style: AppType.titleSm.copyWith(color: c.textSecondary)),
              ),
              const SizedBox(height: Sp.x3),
              FilledButton.icon(
                style: _actionStyle,
                onPressed: _syncing ? null : _syncNow,
                icon: _syncing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.sync_rounded),
                label: Text(_syncing ? 'Syncing' : 'Sync now'),
              ),
              const SizedBox(height: Sp.x2),
              ValueListenableBuilder<LastSync?>(
                valueListenable: sync!.lastSync,
                builder: (context, last, _) => Text(_lastSyncText(last, _now),
                    style: AppType.body.copyWith(color: c.textSecondary)),
              ),
              if (isMac) ...[
                const SizedBox(height: Sp.x2),
                Text(
                    'A Mac reaches your phone only while Diegema is open or '
                    'playing on the phone.',
                    style: AppType.body.copyWith(color: c.textSecondary)),
              ],
              const SizedBox(height: Sp.sectionGap),
              Semantics(
                header: true,
                child: Text('Link another device',
                    style: AppType.titleSm.copyWith(color: c.textSecondary)),
              ),
              const SizedBox(height: Sp.x3),
              FilledButton.icon(
                style: _actionStyle,
                onPressed: () => _then(showLinkDeviceSheet(context,
                    pollForScanner: widget.pollForScanner)),
                icon: const Icon(Icons.qr_code_2_rounded),
                label: const Text('Link a device'),
              ),
              if (canScan) ...[
                const SizedBox(height: Sp.x2),
                OutlinedButton.icon(
                  style: _actionStyle,
                  onPressed: () => _then(Navigator.of(context).push(
                      MaterialPageRoute<bool>(
                          builder: (_) => const ScanCodeScreen()))),
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  label: const Text('Scan a code'),
                ),
              ],
              const SizedBox(height: Sp.x2),
              OutlinedButton.icon(
                style: _actionStyle,
                onPressed: () => _then(showPasteCodeDialog(context)),
                icon: const Icon(Icons.content_paste_rounded),
                label: const Text('Paste a code'),
              ),
              const SizedBox(height: Sp.sectionGap),
              Semantics(
                header: true,
                child: Text('Other devices',
                    style: AppType.titleSm.copyWith(color: c.textSecondary)),
              ),
              const SizedBox(height: Sp.x3),
              if (others.isEmpty)
                Text('No other devices yet.',
                    style: AppType.body.copyWith(color: c.textSecondary))
              else
                for (final id in others)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Sp.listGap),
                    child: _DeviceRow(
                      name: view!.deviceName(id),
                      platform: _platformOf(view, id),
                      onRemove: () => _remove(id, view.deviceName(id)),
                    ),
                  ),
              const SizedBox(height: Sp.sectionGap),
              OutlinedButton.icon(
                style: _actionStyle.copyWith(
                    foregroundColor: WidgetStateProperty.all(c.danger),
                    side: WidgetStateProperty.all(BorderSide(color: c.danger))),
                onPressed: _unlink,
                icon: const Icon(Icons.link_off_rounded),
                label: const Text('Unlink this device'),
              ),
            ],
          ],
        );
      }),
    );
  }

  static String? _platformOf(SyncView view, String id) {
    final p = view.devicePlatform(id);
    return p == null ? null : _platformLabel(p);
  }
}

class _DeviceRow extends StatelessWidget {
  final String name;
  final String? platform;
  final VoidCallback onRemove;

  const _DeviceRow(
      {required this.name, required this.platform, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: R.md,
        border: Border.all(color: c.border),
      ),
      constraints: const BoxConstraints(minHeight: Dim.tapMin),
      padding: const EdgeInsets.only(left: Sp.x3),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Sp.x3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: AppType.bodyLg.copyWith(
                          color: c.text, fontWeight: FontWeight.w600)),
                  if (platform != null) ...[
                    const SizedBox(height: Sp.x1),
                    Text(platform!,
                        style: AppType.body.copyWith(color: c.textSecondary)),
                  ],
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: 'Remove $name',
            constraints: const BoxConstraints(
                minWidth: Dim.tapMin, minHeight: Dim.tapMin),
            onPressed: onRemove,
            icon: Icon(Icons.delete_outline_rounded, color: c.textSecondary),
          ),
        ],
      ),
    );
  }
}
