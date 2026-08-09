import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';

/// Honest "this is a demo" disclosure for the canned web demo build, shown
/// whenever `kDemoMode` is true. Replaces `demo_banner.dart`, which was
/// built on `GlassCard` and an 11px `THIS IS A DEMO` uppercase label.
///
/// The disclosure itself is unchanged in substance — the demo must never
/// let anyone believe they were shown a working app that isn't one — only
/// its rendering, and the fact that it can now be collapsed. Expanded it
/// costs roughly a quarter of a 390×844 phone screen on *every* screen,
/// which is precisely the "too much chrome" problem the redesign exists to
/// fix. Collapsed it keeps a permanent, unmissable one-line marker; it can
/// never be dismissed outright, and it starts expanded on every load.
class DemoNotice extends StatefulWidget {
  const DemoNotice({super.key});

  @override
  State<DemoNotice> createState() => _DemoNoticeState();
}

class _DemoNoticeState extends State<DemoNotice> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      padding: const EdgeInsets.all(Sp.x3),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: R.md,
        border: Border.all(color: c.borderContrast),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded, color: c.cta, size: Dim.iconSm),
              const SizedBox(width: Sp.x3),
              Expanded(
                child: Text('This is a preview',
                    style: AppType.titleSm.copyWith(color: c.text)),
              ),
              Semantics(
                button: true,
                toggled: _expanded,
                label: _expanded
                    ? 'Collapse the preview notice'
                    : 'Expand the preview notice',
                excludeSemantics: true,
                child: IconButton(
                  tooltip: _expanded ? 'Collapse' : 'What does this mean?',
                  onPressed: () => setState(() => _expanded = !_expanded),
                  icon: Icon(_expanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded),
                ),
              ),
            ],
          ),
          if (_expanded) ...[
            const SizedBox(height: Sp.x2),
            Text(
              'A curated, work-in-progress demo. Only a couple of titles '
              'actually play; the rest are browse-only and marked '
              '"Preview only".',
              style: AppType.body.copyWith(color: c.textSecondary),
            ),
            const SizedBox(height: Sp.x3),
            OutlinedButton.icon(
              onPressed: () => launchUrl(
                Uri.parse(
                    'https://librivox.org/pages/volunteer-for-librivox/'),
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.volunteer_activism_outlined),
              label: const Text('Volunteer for LibriVox'),
            ),
          ],
        ],
      ),
    );
  }
}
