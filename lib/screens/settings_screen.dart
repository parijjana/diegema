import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_info.dart';
import '../core/app_settings.dart';
import '../core/playback_constants.dart';
import '../theme/app_theme.dart';

/// The settings panel — Phase 1 of `settings_panel_plan.md`.
///
/// Deliberately small. The bar the plan sets for a row here is *does this
/// earn its complexity?*, after a Wikipedia integration was built and then
/// removed for failing it. Every setting is a persisted key, a migration
/// risk, a support question and a branch in behaviour forever, so a good
/// default beats a toggle. What is here either fixes something (the theme
/// was never saved) or is close to free (the skip interval was already
/// rendered from a number).
///
/// Options are laid out as full-width rows rather than a segmented control
/// or a chip wrap: this app's stated audience includes low-vision readers,
/// large text scales are a supported case, and a row of side-by-side chips
/// is exactly the shape that overflowed at 1.3× and 2× on 08-12.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final settings = SettingsScope.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final gutter = constraints.maxWidth >= Dim.wideBreakpoint
            ? Sp.gutterDesktop
            : Sp.gutterPhone;

        return ListView(
          padding: EdgeInsets.fromLTRB(gutter, Sp.x5, gutter, Sp.x8),
          children: [
            Semantics(
              header: true,
              child: Text(
                'Settings',
                style: AppType.serif(AppType.titleLg).copyWith(color: c.text),
              ),
            ),
            const SizedBox(height: Sp.x6),

            _Section(
              title: 'Appearance',
              children: [
                _ChoiceGroup<ThemeMode>(
                  label: 'Theme',
                  description: 'System follows your device setting.',
                  value: settings.themeMode,
                  options: const [
                    _Choice(ThemeMode.system, 'System'),
                    _Choice(ThemeMode.light, 'Light'),
                    _Choice(ThemeMode.dark, 'Dark'),
                  ],
                  onChanged: settings.setThemeMode,
                ),
              ],
            ),

            _Section(
              title: 'Playback',
              children: [
                _ChoiceGroup<int>(
                  label: 'Skip interval',
                  description:
                      'How far the rewind and fast-forward buttons jump.',
                  value: settings.skipSeconds,
                  options: [
                    for (final seconds in kSkipSecondsOptions)
                      _Choice(seconds, '$seconds seconds'),
                  ],
                  onChanged: settings.setSkipSeconds,
                ),
              ],
            ),

            _Section(
              title: 'About',
              children: [
                const _InfoRow(
                    label: kAppName, value: 'Version $kAppVersion'),
                // Credit as LibriVox asks for it ("we much prefer if you
                // do credit us (with a link to our site)" —
                // librivox.org/pages/public-domain), their objective in
                // their own words, and a plain statement that this is an
                // independent project.
                const _InfoRow(
                  label: 'Audiobooks from LibriVox',
                  value: 'The recordings in Discover come from LibriVox '
                      '(librivox.org), read and produced by volunteers. '
                      'LibriVox recordings are in the public domain.',
                ),
                const _InfoRow(
                  label: 'LibriVox\'s objective',
                  value: '"To make all books in the public domain '
                      'available, narrated by real people and distributed '
                      'for free, in audio format on the internet."',
                ),
                const _InfoRow(
                  label: 'We support LibriVox',
                  value: 'We strongly support LibriVox and its mission. If '
                      'you enjoy these recordings, consider volunteering to '
                      'read or proof-listen.',
                ),
                _LinkRow(
                  label: 'Visit librivox.org',
                  onTap: () => _open('https://librivox.org/'),
                ),
                _LinkRow(
                  label: 'Volunteer for LibriVox',
                  onTap: () => _open(
                      'https://librivox.org/pages/volunteer-for-librivox/'),
                ),
                const _InfoRow(
                  label: 'Independent project',
                  value: '$kAppName is not affiliated with or endorsed by '
                      'LibriVox or the Internet Archive.',
                ),
                const _InfoRow(
                  label: 'Cover art',
                  value: 'Public domain. Per-image sources and asserted '
                      'rights are listed in assets/demo/covers/CREDITS.md.',
                ),
                _LinkRow(
                  label: 'Open source licences',
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: kAppName,
                    applicationVersion: kAppVersion,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

Future<void> _open(String url) async {
  try {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (e) {
    debugPrint('Could not open $url: $e');
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.sectionGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              title,
              style: AppType.titleSm.copyWith(color: c.textSecondary),
            ),
          ),
          const SizedBox(height: Sp.x3),
          ...children,
        ],
      ),
    );
  }
}

class _Choice<T> {
  final T value;
  final String label;
  const _Choice(this.value, this.label);
}

/// A labelled set of mutually exclusive options, one row each.
///
/// Selection is carried by a check icon *and* a bolder label *and* a
/// contrasting border — never colour alone (`design/tokens.md` §8, rule 4),
/// which is also what makes it legible to anyone who cannot separate the
/// accent from the surface.
class _ChoiceGroup<T> extends StatelessWidget {
  final String label;
  final String description;
  final T value;
  final List<_Choice<T>> options;
  final ValueChanged<T> onChanged;

  const _ChoiceGroup({
    required this.label,
    required this.description,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: AppType.label.copyWith(color: c.text)),
        const SizedBox(height: Sp.x1),
        Text(
          description,
          style: AppType.caption.copyWith(color: c.textSecondary),
        ),
        const SizedBox(height: Sp.x3),
        for (final option in options) ...[
          _ChoiceRow(
            label: option.label,
            selected: option.value == value,
            onTap: () => onChanged(option.value),
          ),
          const SizedBox(height: Sp.x2),
        ],
      ],
    );
  }
}

class _ChoiceRow extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ChoiceRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: R.sm,
        child: Container(
          constraints: const BoxConstraints(minHeight: Dim.tapMin),
          padding: const EdgeInsets.symmetric(
            horizontal: Sp.x4,
            vertical: Sp.x2,
          ),
          decoration: BoxDecoration(
            color: selected ? c.accentWash : Colors.transparent,
            borderRadius: R.sm,
            border: Border.all(
              color: selected ? c.borderContrast : c.border,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: AppType.body.copyWith(
                    color: c.text,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ),
              if (selected)
                Icon(Icons.check_rounded, size: Dim.iconSm, color: c.accentText),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppType.label.copyWith(color: c.text)),
          const SizedBox(height: Sp.x1),
          Text(value, style: AppType.caption.copyWith(color: c.textSecondary)),
        ],
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _LinkRow({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: R.sm,
        child: Container(
          constraints: const BoxConstraints(minHeight: Dim.tapMin),
          padding: const EdgeInsets.symmetric(vertical: Sp.x2),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: AppType.body.copyWith(color: c.accentText),
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  size: Dim.iconSm, color: c.accentText),
            ],
          ),
        ),
      ),
    );
  }
}
