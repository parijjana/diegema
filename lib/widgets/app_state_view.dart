import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// One widget for the empty / loading / error states every asynchronous
/// surface owes the user. `design/tokens.md` §8.5: a screen missing an
/// error state is not finished.
class AppStateView extends StatelessWidget {
  final IconData icon;
  final String headline;
  final String? body;
  final Widget? action;
  final Color? tone;

  /// Announced politely by a screen reader while a region is busy.
  final bool busy;

  const AppStateView._({
    required this.icon,
    required this.headline,
    this.body,
    this.action,
    this.tone,
    this.busy = false,
  });

  const AppStateView.empty({
    required IconData icon,
    required String headline,
    String? body,
    Widget? action,
  }) : this._(icon: icon, headline: headline, body: body, action: action);

  const AppStateView.error({
    required String headline,
    String? body,
    Widget? action,
  }) : this._(
          icon: Icons.error_outline_rounded,
          headline: headline,
          body: body,
          action: action,
          tone: _errorTone,
        );

  /// Sentinel meaning "resolve `danger` from the theme at build time".
  static const Color _errorTone = Color(0x00000001);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final accentTone = tone == _errorTone ? c.danger : (tone ?? c.accentText);

    // Scrollable, not a bare `Center`. An icon, a headline, a paragraph and
    // a button stack up taller than a 360x800 phone can show once the text
    // scale is raised, and a `Center` has nowhere to put the excess — it
    // overflowed by 138px at 1.3x, which clips the call-to-action button
    // right off the screen. The `minHeight` keeps the content centred
    // whenever it *does* fit, so nothing changes at the default scale.
    return Semantics(
      liveRegion: busy,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight.isFinite
                    ? constraints.maxHeight
                    : 0.0,
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(Sp.x8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 48, color: accentTone),
                      const SizedBox(height: Sp.x4),
                      Text(
                        headline,
                        textAlign: TextAlign.center,
                        style: AppType.titleMd.copyWith(color: c.text),
                      ),
                      if (body != null) ...[
                        const SizedBox(height: Sp.x2),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 460),
                          child: Text(
                            body!,
                            textAlign: TextAlign.center,
                            style:
                                AppType.bodyLg.copyWith(color: c.textSecondary),
                          ),
                        ),
                      ],
                      if (action != null) ...[
                        const SizedBox(height: Sp.x6),
                        action!,
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Loading placeholder that matches the shape of the content it stands in
/// for, instead of a bare centred spinner.
class AppLoadingView extends StatelessWidget {
  final String label;
  const AppLoadingView({super.key, this.label = 'Loading'});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      liveRegion: true,
      label: label,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
                width: Dim.iconLg,
                height: Dim.iconLg,
                child: CircularProgressIndicator(strokeWidth: 3)),
            const SizedBox(height: Sp.x4),
            Text(label, style: AppType.body.copyWith(color: c.textSecondary)),
          ],
        ),
      ),
    );
  }
}
