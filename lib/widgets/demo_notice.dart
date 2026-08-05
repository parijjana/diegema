import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';

/// Honest "this is a demo" disclosure for the canned web demo build, shown
/// whenever `kDemoMode` is true. Replaces `demo_banner.dart`, which was
/// built on `GlassCard` and an 11px `THIS IS A DEMO` uppercase label.
///
/// The disclosure itself is unchanged in substance — the demo must never
/// let anyone believe they were shown a working app that isn't one — only
/// its rendering. It also carries the LibriVox volunteer call-to-action, so
/// the old two-banner stack becomes one surface.
class DemoNotice extends StatelessWidget {
  const DemoNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      padding: const EdgeInsets.all(Sp.x4),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: R.md,
        border: Border.all(color: c.borderContrast),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: c.cta, size: Dim.iconMd),
          const SizedBox(width: Sp.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('This is a preview',
                    style: AppType.titleSm.copyWith(color: c.text)),
                const SizedBox(height: Sp.x1),
                Text(
                  'A curated, work-in-progress demo. Only a couple of titles '
                  'actually play; the rest are browse-only and marked '
                  '"Preview only".',
                  style: AppType.body.copyWith(color: c.textSecondary),
                ),
                const SizedBox(height: Sp.x3),
                Wrap(
                  spacing: Sp.x3,
                  runSpacing: Sp.x2,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => launchUrl(
                        Uri.parse('https://librivox.org/pages/volunteer-for-librivox/'),
                        mode: LaunchMode.externalApplication,
                      ),
                      icon: const Icon(Icons.volunteer_activism_outlined),
                      label: const Text('Volunteer for LibriVox'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
