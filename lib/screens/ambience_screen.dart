import 'package:flutter/material.dart';

import '../core/ambience_catalog.dart';
import '../core/app_settings.dart';
import '../core/utils/duration_format.dart';
import '../services/ambience_service.dart';
import '../theme/app_theme.dart';
import '../widgets/card_stack.dart';

/// The Ambience screen: the background-sound channel's own on/off, volume
/// and sleep timer, whether it follows the book, the user's saved mixes,
/// and the sounds. Now Playing carries only a small on/off pill for it.
class AmbienceScreen extends StatelessWidget {
  final AmbienceService service;
  const AmbienceScreen({super.key, required this.service});

  static const _sleepOptions = [15, 30, 45, 60, 90];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ValueListenableBuilder<AmbienceState>(
      valueListenable: service.state,
      builder: (context, s, _) {
        final status = s.playing
            ? 'Playing ${s.summary}'
            : s.on && s.mix.isNotEmpty && s.followBook
                ? 'Starts with the book'
                : s.mix.isEmpty
                    ? 'Pick a sound below'
                    : 'Off';
        return LayoutBuilder(builder: (context, constraints) {
          final gutter = constraints.maxWidth >= Dim.wideBreakpoint
              ? Sp.gutterDesktop
              : Sp.gutterPhone;
          final header = Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text('Ambience',
                          style: AppType.serif(AppType.titleLg)
                              .copyWith(color: c.text)),
                    ),
                    const SizedBox(height: Sp.x1),
                    Text(status,
                        style:
                            AppType.caption.copyWith(color: c.textSecondary)),
                  ],
                ),
              ),
              Switch(
                value: s.on,
                onChanged: s.mix.isEmpty ? null : service.setOn,
              ),
            ],
          );
          final sections = _sections();

          if (SettingsScope.maybeOf(context)?.cardStacks ?? false) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(gutter, Sp.x5, gutter, Sp.x2),
                  child: header,
                ),
                Expanded(
                  child: CardStack(
                    padding: EdgeInsets.fromLTRB(gutter, Sp.x2, gutter, Sp.x5),
                    cards: [
                      for (final section in sections)
                        StackCard(
                          title: section.title,
                          leading: CardIconBadge(section.icon),
                          trailing: section.trailing(s) == null
                              ? null
                              : CardTrailingText(section.trailing(s)!),
                          heroTag: 'ambience-card-${section.title}',
                          semanticLabel: [
                            section.title,
                            if (section.trailing(s) != null)
                              section.trailing(s)!,
                          ].join(', '),
                          onOpen: () => openStackCard(
                            context,
                            title: section.title,
                            leading: CardIconBadge(section.icon),
                            heroTag: 'ambience-card-${section.title}',
                            // Live: the controls rebuild as the mix changes.
                            body: (context) =>
                                ValueListenableBuilder<AmbienceState>(
                              valueListenable: service.state,
                              builder: (context, s, _) => ListView(
                                padding: EdgeInsets.fromLTRB(
                                    gutter, Sp.x5, gutter, Sp.x8),
                                children: [
                                  ...section.build(context, s),
                                  if (section.group != null) ...[
                                    const SizedBox(height: Sp.x5),
                                    _credit(context),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          }

          return ListView(
            padding: EdgeInsets.fromLTRB(gutter, Sp.x5, gutter, Sp.x8),
            children: [
              header,
              const SizedBox(height: Sp.x4),
              for (final section in sections) ...[
                if (section.group != null) ...[
                  Text(section.title,
                      style: AppType.caption.copyWith(
                          color: c.textSecondary, fontWeight: FontWeight.w700)),
                  const SizedBox(height: Sp.x2),
                ],
                ...section.build(context, s),
                const SizedBox(height: Sp.x5),
              ],
              _credit(context),
            ],
          );
        });
      },
    );
  }

  Widget _credit(BuildContext context) => Text(
        'Recordings by Joseph Sardin, BigSoundBank.com (CC0). '
        'The noises are generated by Diegema.',
        style: AppType.caption.copyWith(color: context.colors.textMuted),
      );

  /// The screen's parts, in order: a list's sections, or a stack's cards.
  List<_AmbienceSection> _sections() => [
        _AmbienceSection(
          title: 'Sound',
          icon: Icons.tune_rounded,
          trailing: (s) => '${(s.master * 100).round()}%',
          build: (context, s) {
            final c = context.colors;
            return [
              _LabelledSwitch(
                label: 'Play with the book',
                description: s.followBook
                    ? 'Starts and stops with the audiobook.'
                    : 'Plays on its own, with or without a book.',
                value: s.followBook,
                onChanged: service.setFollowBook,
              ),
              const SizedBox(height: Sp.x3),
              Text('Volume', style: AppType.label.copyWith(color: c.text)),
              Semantics(
                label: 'Ambience volume',
                child: Slider(value: s.master, onChanged: service.setMaster),
              ),
              Text(
                'Always kept quieter than the narration.',
                style: AppType.caption.copyWith(color: c.textSecondary),
              ),
            ];
          },
        ),
        _AmbienceSection(
          title: 'Sleep timer',
          icon: Icons.bedtime_rounded,
          trailing: (s) => s.sleepRemaining == null
              ? 'Off'
              : formatTimecode(s.sleepRemaining!),
          build: (context, s) => [
            _SleepRow(
              remaining: s.sleepRemaining,
              options: _sleepOptions,
              onSet: (m) => service.setSleepTimer(Duration(minutes: m)),
              onCancel: service.cancelSleepTimer,
            ),
          ],
        ),
        _AmbienceSection(
          title: 'Your mixes',
          icon: Icons.library_music_rounded,
          trailing: (s) => s.saved.isEmpty ? null : '${s.saved.length}',
          build: (context, s) => [_MixesRow(service: service, state: s)],
        ),
        for (final group in AmbienceGroup.values)
          _AmbienceSection(
            title: group.label,
            icon: _groupIcon(group),
            group: group,
            trailing: (s) {
              final on = AmbienceSound.all
                  .where((x) => x.group == group && s.mix.containsKey(x.id))
                  .length;
              return on == 0 ? null : '$on on';
            },
            build: (context, s) => [
              for (final sound in AmbienceSound.all)
                if (sound.group == group)
                  _SoundRow(
                    sound: sound,
                    level: s.mix[sound.id],
                    onToggle: () => service.toggleSound(sound.id),
                    onLevel: (v) => service.setLevel(sound.id, v),
                  ),
            ],
          ),
      ];

  static IconData _groupIcon(AmbienceGroup group) => switch (group) {
        AmbienceGroup.water => Icons.waves_rounded,
        AmbienceGroup.nature => Icons.forest_rounded,
        AmbienceGroup.weather => Icons.thunderstorm_rounded,
        AmbienceGroup.places => Icons.location_city_rounded,
        AmbienceGroup.noise => Icons.graphic_eq_rounded,
      };
}

/// One part of the Ambience screen: a section of the list, or a card.
class _AmbienceSection {
  final String title;
  final IconData icon;

  /// Set for the sound groups, which get a caption heading in the list.
  final AmbienceGroup? group;

  /// A short current value for the card's title row, or null for none.
  final String? Function(AmbienceState s) trailing;
  final List<Widget> Function(BuildContext context, AmbienceState s) build;

  const _AmbienceSection({
    required this.title,
    required this.icon,
    required this.trailing,
    required this.build,
    this.group,
  });
}

class _LabelledSwitch extends StatelessWidget {
  final String label;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _LabelledSwitch({
    required this.label,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return MergeSemantics(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppType.label.copyWith(color: c.text)),
                Text(description,
                    style: AppType.caption.copyWith(color: c.textSecondary)),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _SleepRow extends StatelessWidget {
  final Duration? remaining;
  final List<int> options;
  final ValueChanged<int> onSet;
  final VoidCallback onCancel;
  const _SleepRow({
    required this.remaining,
    required this.options,
    required this.onSet,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final left = remaining;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          left == null
              ? 'Sleep timer'
              : 'Sleep timer: ${formatTimecode(left)} left',
          style: AppType.label.copyWith(color: c.text),
        ),
        const SizedBox(height: Sp.x2),
        Wrap(
          spacing: Sp.x2,
          runSpacing: Sp.x2,
          children: [
            ChoiceChip(
              label: const Text('Off'),
              selected: left == null,
              onSelected: (_) => onCancel(),
            ),
            for (final minutes in options)
              ChoiceChip(
                label: Text('$minutes min'),
                selected: false,
                onSelected: (_) => onSet(minutes),
              ),
          ],
        ),
      ],
    );
  }
}

class _MixesRow extends StatelessWidget {
  final AmbienceService service;
  final AmbienceState state;
  const _MixesRow({required this.service, required this.state});

  Future<void> _save(BuildContext context) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save this mix'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Name'),
          onSubmitted: (v) => Navigator.of(context).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name != null) await service.saveMix(name);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Your mixes', style: AppType.label.copyWith(color: c.text)),
        const SizedBox(height: Sp.x2),
        if (state.saved.isEmpty)
          Text(
            'Pick a few sounds below, set their levels, then save the '
            'combination here.',
            style: AppType.caption.copyWith(color: c.textSecondary),
          ),
        Wrap(
          spacing: Sp.x2,
          runSpacing: Sp.x2,
          children: [
            for (final mix in state.saved)
              InputChip(
                label: Text(mix.name),
                selected: _same(mix.mix, state.mix),
                onPressed: () => service.applyMix(mix),
                deleteButtonTooltipMessage: 'Delete ${mix.name}',
                onDeleted: () {
                  final index = state.saved.indexOf(mix);
                  service.deleteMix(mix);
                  ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
                    content: Text('Deleted ${mix.name}'),
                    action: SnackBarAction(
                      label: 'Undo',
                      onPressed: () => service.restoreMix(mix, index),
                    ),
                  ));
                },
              ),
            ActionChip(
              avatar: const Icon(Icons.add_rounded),
              label: const Text('Save this mix'),
              onPressed: state.mix.isEmpty ? null : () => _save(context),
            ),
          ],
        ),
      ],
    );
  }

  static bool _same(Map<String, double> a, Map<String, double> b) =>
      a.length == b.length &&
      a.entries.every((e) => (b[e.key] ?? -1) == e.value);
}

class _SoundRow extends StatelessWidget {
  final AmbienceSound sound;

  /// Null when the sound is not in the mix.
  final double? level;
  final VoidCallback onToggle;
  final ValueChanged<double> onLevel;
  const _SoundRow({
    required this.sound,
    required this.level,
    required this.onToggle,
    required this.onLevel,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final on = level != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.x2),
      child: Container(
        decoration: BoxDecoration(
          color: on ? c.accentWash : c.surface,
          borderRadius: R.md,
          border: Border.all(color: on ? c.accent : c.border),
          boxShadow: c.shadowUi,
        ),
        child: Column(
          children: [
            Semantics(
              button: true,
              toggled: on,
              label: sound.name,
              excludeSemantics: true,
              child: InkWell(
                onTap: onToggle,
                borderRadius: R.md,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: Dim.tapMin),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Sp.x3),
                    child: Row(
                      children: [
                        Icon(sound.icon,
                            size: Dim.iconSm,
                            color: on ? c.accentText : c.textSecondary),
                        const SizedBox(width: Sp.x3),
                        Expanded(
                          child: Text(sound.name,
                              style: AppType.label.copyWith(
                                  color: c.text,
                                  fontWeight: on ? FontWeight.w700 : null)),
                        ),
                        Icon(
                          on
                              ? Icons.check_circle_rounded
                              : Icons.add_circle_outline_rounded,
                          size: Dim.iconSm,
                          color: on ? c.accentText : c.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (on)
              Semantics(
                label: '${sound.name} level',
                child: Slider(value: level!, onChanged: onLevel),
              ),
          ],
        ),
      ),
    );
  }
}
