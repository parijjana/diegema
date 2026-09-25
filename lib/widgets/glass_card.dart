import 'dart:ui';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final String? title;
  final double blur;
  final double opacity;
  final EdgeInsetsGeometry padding;
  final BorderRadius? borderRadius;
  final bool fullHeight;
  final Color? borderColor;

  const GlassCard({
    super.key,
    required this.child,
    this.title,
    this.blur = 20.0,
    this.opacity = 0.12,
    this.padding = const EdgeInsets.all(16.0),
    this.borderRadius,
    this.fullHeight = false,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveBorderRadius = borderRadius ?? BorderRadius.circular(20.0);
    final primaryColor = borderColor ?? theme.colorScheme.primary;

    final Widget innerContent = Column(
      mainAxisSize: fullHeight ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Text(
            title!.toUpperCase(),
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (fullHeight) Expanded(child: child) else child,
      ],
    );

    final Widget decorationLayer = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: opacity),
        borderRadius: effectiveBorderRadius,
        border: Border.all(
          color: primaryColor.withValues(alpha: 0.25),
          width: 1.5,
        ),
      ),
      child: innerContent,
    );

    // The optional drop shadow (Settings > Colours > Shadows) sits outside
    // the clip, or the blur's ClipRRect would cut it off.
    final shadows = context.colors.shadowUi;
    Widget withShadow(Widget card) => shadows.isEmpty
        ? card
        : DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: effectiveBorderRadius,
              boxShadow: shadows,
            ),
            child: card,
          );

    if (blur > 0) {
      return withShadow(ClipRRect(
        borderRadius: effectiveBorderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: blur,
            sigmaY: blur,
          ),
          child: decorationLayer,
        ),
      ));
    }

    return withShadow(decorationLayer);
  }
}
