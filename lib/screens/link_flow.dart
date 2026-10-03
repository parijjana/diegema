import 'package:flutter/material.dart';

import '../services/sync/sync_controller.dart';
import '../theme/app_theme.dart';

/// The words for each result of joining with a code. Null for results that
/// need no message of their own.
String joinMessage(JoinOutcome outcome) => switch (outcome) {
      JoinOutcome.linked =>
        "Linked. Your devices will keep each other's place.",
      JoinOutcome.linkedNotSynced =>
        "Linked. They'll sync when both are open on the same Wi-Fi.",
      JoinOutcome.invalid => "That isn't a Diegema link code.",
      JoinOutcome.expired =>
        'That code has expired. Show a new one on the other device.',
      JoinOutcome.otherGroup =>
        'This device is already linked to other devices.',
    };

bool joinSucceeded(JoinOutcome o) =>
    o == JoinOutcome.linked || o == JoinOutcome.linkedNotSynced;

/// Joins with [code]. If this device is already linked to other devices,
/// asks first and, on a yes, joins again replacing them. Returns the final
/// outcome, or null if the person chose to keep their current devices.
Future<JoinOutcome?> joinWithConfirm(
    BuildContext context, SyncController sync, String code) async {
  var outcome = await sync.joinWithCode(code);
  if (outcome != JoinOutcome.otherGroup) return outcome;
  if (!context.mounted) return null;
  final switchOver = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Switch devices?'),
      content: const Text(
          'This device is already linked to other devices. Switch to the new ones?'),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep current')),
        FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Switch')),
      ],
    ),
  );
  if (switchOver != true) return null;
  outcome = await sync.joinWithCode(code, replaceGroup: true);
  return outcome;
}

/// "Paste a code": a text field, then join. Works on every platform, and is
/// how desktops join. Resolves true once linked.
Future<bool> showPasteCodeDialog(BuildContext context) async {
  final sync = SyncScope.maybeOf(context);
  if (sync == null) return false;
  final messenger = ScaffoldMessenger.of(context);
  final linked = await showDialog<JoinOutcome>(
    context: context,
    builder: (_) => _PasteCodeDialog(sync: sync),
  );
  if (linked != null) {
    messenger.showSnackBar(SnackBar(content: Text(joinMessage(linked))));
  }
  return linked != null;
}

class _PasteCodeDialog extends StatefulWidget {
  final SyncController sync;
  const _PasteCodeDialog({required this.sync});

  @override
  State<_PasteCodeDialog> createState() => _PasteCodeDialogState();
}

class _PasteCodeDialogState extends State<_PasteCodeDialog> {
  final _text = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final code = _text.text.trim();
    if (code.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    JoinOutcome? outcome;
    try {
      outcome = await joinWithConfirm(context, widget.sync, code);
    } catch (_) {
      outcome = JoinOutcome.invalid;
    }
    if (!mounted) return;
    if (outcome != null && joinSucceeded(outcome)) {
      Navigator.of(context).pop(outcome);
      return;
    }
    setState(() {
      _busy = false;
      _error = outcome == null ? null : joinMessage(outcome);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AlertDialog(
      title: const Text('Paste a code'),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Paste the code from your other device.',
              style: AppType.body.copyWith(color: c.textSecondary)),
          const SizedBox(height: Sp.x3),
          TextField(
            controller: _text,
            autofocus: true,
            minLines: 1,
            maxLines: 3,
            enabled: !_busy,
            style: AppType.body.copyWith(color: c.text),
            decoration: const InputDecoration(labelText: 'Link code'),
            onSubmitted: (_) => _join(),
          ),
          if (_error != null) ...[
            const SizedBox(height: Sp.x2),
            Text(_error!, style: AppType.body.copyWith(color: c.danger)),
          ],
        ],
      ),
      actions: [
        TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: _busy || _text.text.trim().isEmpty ? null : _join,
            child: const Text('Link')),
      ],
    );
  }
}
