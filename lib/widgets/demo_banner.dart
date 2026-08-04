import 'package:flutter/material.dart';
import 'glass_card.dart';
import 'librivox_volunteer_banner.dart';

/// Honest "this is a demo" disclosure for the canned web demo build, shown
/// whenever `kDemoMode` is true (see `core/demo_mode.dart`). Explains what
/// the demo is (and is not), and reuses the existing
/// [LibriVoxVolunteerBanner] call-to-action rather than inventing a new
/// one, per rework_plan.md.
class DemoBanner extends StatelessWidget {
  const DemoBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = theme.colorScheme.secondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GlassCard(
          padding: const EdgeInsets.all(14),
          borderColor: secondary.withValues(alpha: 0.4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, color: secondary, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'THIS IS A DEMO',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        letterSpacing: 1.2,
                        color: secondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'A curated, work-in-progress preview — only a couple of titles are '
                      'playable (look for the play button), the rest are browse-only '
                      'previews marked "Preview only". Streaming here, not the full app.',
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.4,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const LibriVoxVolunteerBanner(),
        const SizedBox(height: 4),
      ],
    );
  }
}
