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

  const LinkedDevicesScreen({super.key, this.pollForScanner});

  @override
  State<LinkedDevicesScreen> createState() => _LinkedDevicesScreenState();
}

class _LinkedDevicesScreenState extends State<LinkedDevicesScreen> {
  final TextEditingController _name = TextEditingController();
  String _savedName = '';
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      _loadName();
    }
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
    final canScan = SyncScope.maybeOf(context)?.canScan ?? false;

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
            const SizedBox(height: Sp.sectionGap),
            Semantics(
              header: true,
              child: Text('Link another device',
                  style: AppType.titleSm.copyWith(color: c.textSecondary)),
            ),
            const SizedBox(height: Sp.x3),
            FilledButton.icon(
              style: _actionStyle,
              onPressed: () => showLinkDeviceSheet(context,
                  pollForScanner: widget.pollForScanner),
              icon: const Icon(Icons.qr_code_2_rounded),
              label: const Text('Link a device'),
            ),
            if (canScan) ...[
              const SizedBox(height: Sp.x2),
              OutlinedButton.icon(
                style: _actionStyle,
                onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<bool>(
                        builder: (_) => const ScanCodeScreen())),
                icon: const Icon(Icons.qr_code_scanner_rounded),
                label: const Text('Scan a code'),
              ),
            ],
            const SizedBox(height: Sp.x2),
            OutlinedButton.icon(
              style: _actionStyle,
              onPressed: () => showPasteCodeDialog(context),
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
                  ),
                ),
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

  const _DeviceRow({required this.name, required this.platform});

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
      padding: const EdgeInsets.all(Sp.x3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name,
              style: AppType.bodyLg
                  .copyWith(color: c.text, fontWeight: FontWeight.w600)),
          if (platform != null) ...[
            const SizedBox(height: Sp.x1),
            Text(platform!,
                style: AppType.body.copyWith(color: c.textSecondary)),
          ],
        ],
      ),
    );
  }
}
