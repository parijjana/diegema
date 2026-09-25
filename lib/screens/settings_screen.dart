import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_info.dart';
import '../core/app_settings.dart';
import '../core/playback_constants.dart';
import '../core/player_controls_style.dart';
import '../theme/app_theme.dart';
import '../widgets/card_stack.dart';

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
    final settings = SettingsScope.of(context);
    final themeLabel = switch (settings.themeMode) {
      ThemeMode.system => 'System',
      ThemeMode.light => 'Light',
      ThemeMode.dark => 'Dark',
    };
    final groups = [
      _SettingsGroup(
        title: 'Theme & colours',
        icon: Icons.palette_rounded,
        summary: [
          ('Theme', themeLabel),
          ('Background', settings.background.name),
          (
            'Accent',
            '${settings.accent.name} (${settings.accent.family.label.toLowerCase()})'
          ),
          ('Shadows', settings.shadows.label),
          ('Card stacks', settings.cardStacks ? 'On' : 'Off'),
        ],
        preview: _ColoursPreview(
            background: settings.background, accent: settings.accent),
        controls: (context, settings) => [
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
          const SizedBox(height: Sp.x5),
          const _GroupHeading(
            label: 'Background',
            description: 'Each option pairs a light-mode background '
                'with a dark-mode one.',
          ),
          _BackgroundPicker(
            value: settings.background,
            onChanged: settings.setBackground,
          ),
          const SizedBox(height: Sp.x5),
          const _GroupHeading(
            label: 'Accent',
            description: 'Colours the play button, highlights and '
                'links.',
          ),
          for (final family in AccentFamily.values)
            _AccentFamilyRow(
              family: family,
              value: settings.accent,
              onChanged: settings.setAccent,
            ),
          const SizedBox(height: Sp.x1),
          _ThreeWayToggle<ShadowStyle>(
            label: 'Shadows',
            description: 'Drop shadows under cards and buttons: dark '
                'in light mode, a soft glow of the accent in dark mode.',
            value: settings.shadows,
            options: [
              for (final style in ShadowStyle.values)
                _Choice(style, style.label),
            ],
            onChanged: settings.setShadows,
          ),
          const SizedBox(height: Sp.x5),
          _ThreeWayToggle<bool>(
            label: 'Card stacks',
            description: 'Settings, Library and Discover as a stack of '
                'cards you flick through, instead of lists.',
            value: settings.cardStacks,
            options: const [_Choice(false, 'Off'), _Choice(true, 'On')],
            onChanged: settings.setCardStacks,
          ),
        ],
      ),
      _SettingsGroup(
        title: 'Player layout',
        icon: Icons.dashboard_customize_rounded,
        summary: [
          ('Player buttons', settings.controlsStyle.label),
          ('Playback controls', settings.transportStyle.label),
        ],
        controls: (context, settings) => [
          _ThreeWayToggle<PlayerControlsStyle>(
            label: 'Player buttons',
            description: 'How Up next, Speed and Sleep look on the '
                'Now Playing screen.',
            value: settings.controlsStyle,
            options: [
              for (final style in PlayerControlsStyle.values)
                _Choice(style, style.label),
            ],
            onChanged: settings.setControlsStyle,
          ),
          const SizedBox(height: Sp.x5),
          _ThreeWayToggle<PlayerControlsStyle>(
            label: 'Playback controls',
            description: 'Shape and size of the play, skip and '
                'chapter buttons.',
            value: settings.transportStyle,
            options: [
              for (final style in PlayerControlsStyle.values)
                _Choice(style, style.label),
            ],
            onChanged: settings.setTransportStyle,
          ),
        ],
      ),
      _SettingsGroup(
        title: 'Playback',
        icon: Icons.fast_forward_rounded,
        summary: [('Skip interval', '${settings.skipSeconds} seconds')],
        controls: (context, settings) => [
          _ChoiceGroup<int>(
            label: 'Skip interval',
            description: 'How far the rewind and fast-forward buttons jump.',
            value: settings.skipSeconds,
            options: [
              for (final seconds in kSkipSecondsOptions)
                _Choice(seconds, '$seconds seconds'),
            ],
            onChanged: settings.setSkipSeconds,
          ),
        ],
      ),
      _SettingsGroup(
        title: 'About',
        icon: Icons.info_outline_rounded,
        summary: [
          (kAppName, 'Version $kAppVersion'),
          ('Audiobooks', 'From LibriVox volunteers'),
          ('Sounds', 'BigSoundBank (CC0)'),
        ],
        controls: (context, settings) => [
          const _InfoRow(label: kAppName, value: 'Version $kAppVersion'),
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
            onTap: () =>
                _open('https://librivox.org/pages/volunteer-for-librivox/'),
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
          const _InfoRow(
            label: 'Ambience sounds',
            value: 'Recordings by Joseph Sardin, BigSoundBank.com, '
                'released under CC0. The white, pink and brown noise '
                'is generated by $kAppName. Details in '
                'assets/ambience/CREDITS.md.',
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
    ];
    return settings.cardStacks
        ? _SettingsDeck(groups: groups)
        : _SettingsList(groups: groups);
  }
}

Future<void> _open(String url) async {
  try {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (e) {
    debugPrint('Could not open $url: $e');
  }
}

/// One card in the deck: a group of related settings.
class _SettingsGroup {
  final String title;
  final IconData icon;

  /// What the card's face shows while it sits in the deck: the current
  /// value of each setting inside, so most visits end without opening it.
  final List<(String, String)> summary;

  /// An optional picture of the current state (the colours card).
  final Widget? preview;

  /// The controls, built inside the opened card with live settings so they
  /// rebuild as the user changes them.
  final List<Widget> Function(BuildContext context, AppSettings settings)
      controls;

  const _SettingsGroup({
    required this.title,
    required this.icon,
    required this.summary,
    required this.controls,
    this.preview,
  });

  String get heroTag => 'settings-card-$title';
}

/// Settings as a rolodex of cards (see [CardStack]), Theme & colours at the
/// front. Tap a card to open it full screen with its controls.
class _SettingsDeck extends StatelessWidget {
  final List<_SettingsGroup> groups;
  const _SettingsDeck({required this.groups});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= Dim.wideBreakpoint;
      final gutter = wide ? Sp.gutterDesktop : Sp.gutterPhone;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SettingsHeading(
            gutter: gutter,
            hint: 'Tap a card to open it.',
          ),
          Expanded(
            child: CardStack(
              padding: EdgeInsets.fromLTRB(gutter, Sp.x2, gutter, Sp.x5),
              cards: [
                for (final g in groups)
                  StackCard(
                    title: g.title,
                    leading: CardIconBadge(g.icon),
                    heroTag: g.heroTag,
                    semanticLabel: '${g.title} settings. '
                        '${g.summary.map((e) => '${e.$1}: ${e.$2}').join(', ')}',
                    face: (context) => ExcludeSemantics(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final (label, value) in g.summary)
                            Padding(
                              padding: const EdgeInsets.only(bottom: Sp.x3),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(label,
                                      style: AppType.caption
                                          .copyWith(color: c.textSecondary)),
                                  Text(value,
                                      style: AppType.label.copyWith(
                                          color: c.text,
                                          fontWeight: FontWeight.w700)),
                                ],
                              ),
                            ),
                          if (g.preview != null) ...[
                            const SizedBox(height: Sp.x2),
                            g.preview!,
                          ],
                        ],
                      ),
                    ),
                    onOpen: () => openStackCard(
                      context,
                      title: g.title,
                      leading: CardIconBadge(g.icon),
                      heroTag: g.heroTag,
                      body: (context) {
                        final settings = SettingsScope.of(context);
                        final wide = MediaQuery.sizeOf(context).width >=
                            Dim.wideBreakpoint;
                        final gutter = wide ? Sp.gutterDesktop : Sp.gutterPhone;
                        return Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 640),
                            child: ListView(
                              padding: EdgeInsets.fromLTRB(
                                  gutter, Sp.x5, gutter, Sp.x8),
                              children: g.controls(context, settings),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
    });
  }
}

/// Settings as a plain scrolling list: each group's heading, then its
/// controls.
class _SettingsList extends StatelessWidget {
  final List<_SettingsGroup> groups;
  const _SettingsList({required this.groups});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final settings = SettingsScope.of(context);
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= Dim.wideBreakpoint;
      final gutter = wide ? Sp.gutterDesktop : Sp.gutterPhone;
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, Sp.x10),
            children: [
              _SettingsHeading(gutter: gutter),
              for (final g in groups)
                Padding(
                  padding: EdgeInsets.fromLTRB(gutter, Sp.x4, gutter, Sp.x4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(children: [
                        Icon(g.icon, size: Dim.iconSm, color: c.accentText),
                        const SizedBox(width: Sp.x2),
                        Expanded(
                          child: Semantics(
                            header: true,
                            child: Text(g.title,
                                style: AppType.serif(AppType.titleMd)
                                    .copyWith(color: c.text)),
                          ),
                        ),
                      ]),
                      const SizedBox(height: Sp.x4),
                      ...g.controls(context, settings),
                      const SizedBox(height: Sp.x4),
                      Divider(color: c.border, height: 1),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }
}

class _SettingsHeading extends StatelessWidget {
  final double gutter;
  final String? hint;
  const _SettingsHeading({required this.gutter, this.hint});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: EdgeInsets.fromLTRB(gutter, Sp.x5, gutter, Sp.x2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text('Settings',
                style: AppType.serif(AppType.titleLg).copyWith(color: c.text)),
          ),
          if (hint != null) ...[
            const SizedBox(height: Sp.x1),
            Text(hint!,
                style: AppType.caption.copyWith(color: c.textSecondary)),
          ],
        ],
      ),
    );
  }
}

/// The colours card's face: each background's light and dark halves, with
/// the chosen accent on each.
class _ColoursPreview extends StatelessWidget {
  final BackgroundPair background;
  final AccentPalette accent;
  const _ColoursPreview({required this.background, required this.accent});

  Widget _half(BackgroundTones b, AccentTones a) => Expanded(
        child: Container(
          height: 64,
          color: b.bg,
          padding: const EdgeInsets.all(Sp.x2),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration:
                    BoxDecoration(color: a.accentFill, shape: BoxShape.circle),
              ),
              const SizedBox(width: Sp.x2),
              Expanded(
                child: Container(
                  height: 28,
                  decoration: BoxDecoration(
                    color: b.surface,
                    borderRadius: R.sm,
                    border: Border.all(color: b.border),
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: ClipRRect(
          borderRadius: R.md,
          child: Row(children: [
            _half(background.light, accent.light),
            _half(background.dark, accent.dark),
          ]),
        ),
      );
}

class _Choice<T> {
  final T value;
  final String label;
  const _Choice(this.value, this.label);
}

class _GroupHeading extends StatelessWidget {
  final String label;
  final String description;
  const _GroupHeading({required this.label, required this.description});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.x3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: AppType.label.copyWith(color: c.text)),
          const SizedBox(height: Sp.x1),
          Text(description,
              style: AppType.caption.copyWith(color: c.textSecondary)),
        ],
      ),
    );
  }
}

/// Background pairs as two-up cards, each previewing its light half and
/// its dark half side by side. One column at large text sizes.
class _BackgroundPicker extends StatelessWidget {
  final BackgroundPair value;
  final ValueChanged<BackgroundPair> onChanged;
  const _BackgroundPicker({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(1);
      final columns = scale > 1.5 || constraints.maxWidth < 300 ? 1 : 2;
      final width = (constraints.maxWidth - Sp.x3 * (columns - 1)) / columns;
      return Wrap(
        spacing: Sp.x3,
        runSpacing: Sp.x3,
        children: [
          for (final pair in BackgroundPair.all)
            SizedBox(
              width: width,
              child: _BackgroundCard(
                pair: pair,
                selected: pair == value,
                onTap: () => onChanged(pair),
              ),
            ),
        ],
      );
    });
  }
}

class _BackgroundCard extends StatelessWidget {
  final BackgroundPair pair;
  final bool selected;
  final VoidCallback onTap;
  const _BackgroundCard({
    required this.pair,
    required this.selected,
    required this.onTap,
  });

  Widget _half(BackgroundTones t, BorderRadius radius) => Expanded(
        child: Container(
          height: 56,
          padding: const EdgeInsets.all(Sp.x2),
          decoration: BoxDecoration(color: t.bg, borderRadius: radius),
          alignment: Alignment.bottomLeft,
          // A little card on the background, the way content sits on it.
          child: Container(
            width: 28,
            height: 18,
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: R.sm,
              border: Border.all(color: t.border),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      inMutuallyExclusiveGroup: true,
      selected: selected,
      label: '${pair.name} background',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: R.md,
        child: Container(
          padding: const EdgeInsets.all(Sp.x2),
          decoration: BoxDecoration(
            color: selected ? c.accentWash : c.surface,
            borderRadius: R.md,
            border: Border.all(
              color: selected ? c.accent : c.border,
              width: selected ? 2 : 1,
            ),
            boxShadow: c.shadowUi,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: R.sm,
                child: Row(children: [
                  _half(pair.light, BorderRadius.zero),
                  _half(pair.dark, BorderRadius.zero),
                ]),
              ),
              const SizedBox(height: Sp.x2),
              Row(
                children: [
                  if (selected) ...[
                    Icon(Icons.check_rounded,
                        size: Dim.iconSm, color: c.accentText),
                    const SizedBox(width: Sp.x1),
                  ],
                  Expanded(
                    child: Text(
                      pair.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.label.copyWith(
                        color: c.text,
                        fontWeight: selected ? FontWeight.w700 : null,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One accent family (Matte, Neon or Bold): a caption and a row of named
/// swatches, each drawn in the fill it would give the play button in the
/// current brightness.
class _AccentFamilyRow extends StatelessWidget {
  final AccentFamily family;
  final AccentPalette value;
  final ValueChanged<AccentPalette> onChanged;
  const _AccentFamilyRow({
    required this.family,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final brightness = Theme.of(context).brightness;
    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(family.label,
              style: AppType.caption.copyWith(
                  color: c.textSecondary, fontWeight: FontWeight.w700)),
          const SizedBox(height: Sp.x2),
          Wrap(
            spacing: Sp.x2,
            runSpacing: Sp.x3,
            children: [
              for (final palette in AccentPalette.all)
                if (palette.family == family)
                  _AccentSwatch(
                    palette: palette,
                    tones: palette.tones(brightness),
                    selected: palette == value,
                    onTap: () => onChanged(palette),
                  ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AccentSwatch extends StatelessWidget {
  final AccentPalette palette;
  final AccentTones tones;
  final bool selected;
  final VoidCallback onTap;
  const _AccentSwatch({
    required this.palette,
    required this.tones,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      inMutuallyExclusiveGroup: true,
      selected: selected,
      label: '${palette.name}, ${palette.family.label.toLowerCase()} accent',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: R.md,
        child: SizedBox(
          width: 64,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Sp.x1),
            child: Column(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: tones.accentFill,
                    // The ring sits outside the swatch so the selection
                    // reads on every fill, dark or light.
                    border: Border.all(
                      color: selected ? c.text : c.border,
                      width: selected ? 3 : 1,
                    ),
                    boxShadow: c.shadowUi,
                  ),
                  child: selected
                      ? Icon(Icons.check_rounded,
                          size: Dim.iconSm, color: tones.textOnAccent)
                      : null,
                ),
                const SizedBox(height: Sp.x1),
                Text(
                  palette.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: AppType.caption.copyWith(
                    color: c.text,
                    fontWeight: selected ? FontWeight.w700 : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A labelled three-way toggle: one rounded track split into equal
/// segments, the chosen one filled. Used where the options are short words
/// that read as one control (the owner asked for a toggle, not rows).
///
/// Large text scales are handled by letting each label wrap to two lines
/// inside its segment rather than overflowing the track, and the selection
/// is carried by a check icon and the fill, never colour alone.
class _ThreeWayToggle<T> extends StatelessWidget {
  final String label;
  final String description;
  final T value;
  final List<_Choice<T>> options;
  final ValueChanged<T> onChanged;

  const _ThreeWayToggle({
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
        Container(
          padding: const EdgeInsets.all(Sp.x1),
          decoration: BoxDecoration(
            color: c.surfaceSunken,
            borderRadius: R.pill,
            border: Border.all(color: c.borderContrast),
            boxShadow: c.shadowUi,
          ),
          child: Row(
            children: [
              for (final option in options)
                Expanded(
                  child: _ToggleSegment(
                    label: option.label,
                    selected: option.value == value,
                    onTap: () => onChanged(option.value),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ToggleSegment extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ToggleSegment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final foreground = selected ? c.textOnAccent : c.textSecondary;
    return Semantics(
      button: true,
      inMutuallyExclusiveGroup: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: selected ? c.accentFill : Colors.transparent,
        borderRadius: R.pill,
        child: InkWell(
          onTap: onTap,
          borderRadius: R.pill,
          child: Container(
            constraints: const BoxConstraints(minHeight: Dim.tapMin),
            padding: const EdgeInsets.symmetric(horizontal: Sp.x2),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (selected) ...[
                  Icon(Icons.check_rounded,
                      size: Dim.iconSm, color: foreground),
                  const SizedBox(width: Sp.x1),
                ],
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.label.copyWith(
                      color: foreground,
                      fontWeight: selected ? FontWeight.w700 : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
                Icon(Icons.check_rounded,
                    size: Dim.iconSm, color: c.accentText),
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
