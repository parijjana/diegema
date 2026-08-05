import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Opaque surface card — the replacement for `GlassCard`.
///
/// `GlassCard` applied `ImageFilter.blur(20, 20)` plus an `onSurface` alpha
/// wash to nearly every surface, including full-height layout containers.
/// Two problems: it composited a full-screen blur every frame, and it made
/// text contrast a function of whatever happened to be scrolling
/// underneath — i.e. unprovable. This is an opaque `surface` fill, a
/// hairline `border`, and a shadow token. No blur, no coloured glow.
///
/// The old widget's `title` slot rendered `title.toUpperCase()` at 10px
/// with `letterSpacing: 1.5`; here [title] is a real sentence-case
/// `title-sm` heading.
class AppCard extends StatelessWidget {
  final Widget child;
  final String? title;

  /// Optional trailing widget on the [title] row (an action, a count).
  final Widget? titleTrailing;

  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;

  /// A *meaningful* border colour (selection, state). Pass a token from
  /// `context.colors` that meets 3:1 — [AppColors.borderContrast] or
  /// [AppColors.accent]. When null the card uses the decorative hairline.
  final Color? emphasisBorder;

  final List<BoxShadow>? shadow;
  final Color? background;
  final VoidCallback? onTap;
  final bool fullHeight;

  const AppCard({
    super.key,
    required this.child,
    this.title,
    this.titleTrailing,
    this.padding = const EdgeInsets.all(Sp.cardPadding),
    this.borderRadius = R.md,
    this.emphasisBorder,
    this.shadow,
    this.background,
    this.onTap,
    this.fullHeight = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final borderColor = emphasisBorder ?? c.border;

    final Widget content = Column(
      mainAxisSize: fullHeight ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Row(
            children: [
              Expanded(
                child: Text(title!,
                    style: AppType.titleSm.copyWith(color: c.text)),
              ),
              if (titleTrailing != null) titleTrailing!,
            ],
          ),
          const SizedBox(height: Sp.x3),
        ],
        if (fullHeight) Expanded(child: child) else child,
      ],
    );

    final Widget body = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: background ?? c.surface,
        borderRadius: borderRadius,
        border: Border.all(
          color: borderColor,
          width: emphasisBorder != null ? 2 : 1,
        ),
        boxShadow: shadow ?? c.shadow1,
      ),
      child: content,
    );

    if (onTap == null) return body;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: body,
      ),
    );
  }
}
