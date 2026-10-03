import 'package:flutter/material.dart';

import '../core/utils/sync_format.dart';
import '../sync/sync_view.dart';
import '../theme/app_theme.dart';

/// Library book detail: where the book stands on the user's other linked
/// devices. Every jump is an explicit tap on a button here; showing the
/// section moves nothing.
///
/// Null-safe by construction: the caller builds it only when there is a
/// sync view and something to show (see [OtherDevicesSection.hasContent]).
class OtherDevicesSection extends StatelessWidget {
  final SyncView view;

  /// The book's portable key.
  final String bookKey;

  /// This device's place in the book (`deviceId` unused), for "ahead" and
  /// "behind". Null when nothing is saved here yet: the start.
  final DevicePosition? local;

  /// Jump to a place the user chose.
  final ValueChanged<DevicePosition> onJump;

  const OtherDevicesSection({
    super.key,
    required this.view,
    required this.bookKey,
    required this.local,
    required this.onJump,
  });

  static bool hasContent(SyncView view, String key) =>
      view.positions(key).isNotEmpty || view.finishedOn(key).isNotEmpty;

  DevicePosition get _here => local ?? const DevicePosition('', 0, 0, 0);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final positions = view.positions(bookKey);
    final finished = view.finishedOn(bookKey);
    final furthest = view.furthestElsewhere(bookKey);
    final now = DateTime.now().millisecondsSinceEpoch;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text('On your other devices',
              style: AppType.titleSm.copyWith(color: c.text)),
        ),
        const SizedBox(height: Sp.x3),
        if (finished.isNotEmpty) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.check_rounded, size: Dim.iconSm, color: c.accentText),
              const SizedBox(width: Sp.x2),
              Expanded(
                child: Text('Finished on ${deviceListLabel(view, finished)}',
                    style: AppType.body.copyWith(color: c.textSecondary)),
              ),
            ],
          ),
          const SizedBox(height: Sp.x3),
        ],
        for (final p in positions)
          Padding(
            padding: const EdgeInsets.only(bottom: Sp.listGap),
            child: _DevicePositionRow(
              name: view.deviceName(p.deviceId),
              place: formatSyncPosition(p.chapter, p.seconds),
              when: relativeTime(p.atMillis, now),
              relation: p.isAhead(_here)
                  ? 'Ahead of this device'
                  : _here.isAhead(p)
                      ? 'Behind this device'
                      : null,
              onJump: () => onJump(p),
            ),
          ),
        if (furthest != null && furthest.isAhead(_here))
          Padding(
            padding: const EdgeInsets.only(top: Sp.x1),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  minimumSize: const Size(Dim.tapMin, Dim.tapMin),
                  foregroundColor: c.accentText,
                ),
                onPressed: () => onJump(furthest),
                icon: const Icon(Icons.last_page_rounded),
                label: const Text('Go to furthest'),
              ),
            ),
          ),
        if (furthest != null && furthest.isAhead(_here))
          Text(
            'Furthest: ${view.deviceName(furthest.deviceId)}, '
            '${formatSyncPosition(furthest.chapter, furthest.seconds)}',
            style: AppType.caption.copyWith(color: c.textMuted),
          ),
      ],
    );
  }
}

class _DevicePositionRow extends StatelessWidget {
  final String name;
  final String place;
  final String when;
  final String? relation;
  final VoidCallback onJump;

  const _DevicePositionRow({
    required this.name,
    required this.place,
    required this.when,
    required this.relation,
    required this.onJump,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: R.md,
        border: Border.all(color: c.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Sp.x3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(name,
                style: AppType.bodyLg
                    .copyWith(color: c.text, fontWeight: FontWeight.w600)),
            const SizedBox(height: Sp.x1),
            Text('$place · $when',
                style: AppType.body.copyWith(color: c.textSecondary)),
            if (relation != null) ...[
              const SizedBox(height: Sp.x1),
              Text(relation!,
                  style: AppType.caption.copyWith(color: c.accentText)),
            ],
            const SizedBox(height: Sp.x2),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(Dim.tapMin, Dim.tapMin),
                  shape: const RoundedRectangleBorder(borderRadius: R.md),
                ),
                onPressed: onJump,
                child: const Text('Jump here'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
