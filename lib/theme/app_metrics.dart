import 'package:flutter/material.dart';

/// Spacing scale (`design/tokens.md` §3). 4px base. The odd values in the
/// old build (3, 6, 10, 14, 18) are dropped.
abstract final class Sp {
  static const double x0 = 0;
  static const double x1 = 4;
  static const double x2 = 8;
  static const double x3 = 12;
  static const double x4 = 16;
  static const double x5 = 20;
  static const double x6 = 24;
  static const double x8 = 32;
  static const double x10 = 40;
  static const double x12 = 48;
  static const double x16 = 64;

  /// Defaults called out by the spec.
  static const double cardPadding = x4;
  static const double listGap = x3;
  static const double sectionGap = x8;
  static const double gutterPhone = x4;
  static const double gutterDesktop = x5;
}

/// Radii (`design/tokens.md` §4).
abstract final class R {
  static const xs = BorderRadius.all(Radius.circular(4));
  static const sm = BorderRadius.all(Radius.circular(8));
  static const md = BorderRadius.all(Radius.circular(12));
  static const lg = BorderRadius.all(Radius.circular(16));
  static const xl = BorderRadius.all(Radius.circular(24));
  static const pill = BorderRadius.all(Radius.circular(999));

  /// Book covers: the same radius on all four corners, scaled with the
  /// cover (4px on a thumbnail, up to 12px on the big player cover).
  ///
  /// Covers used to carry a "spine" radius (2px left, 10px right) from when
  /// they were drawn book-shaped. Square covers inside rounded cards made
  /// that clash: a near-square left edge next to the card's round corner,
  /// an over-rounded right one. Uniform, and never rounder than the 12px
  /// card around it.
  static BorderRadius coverFor(double size) =>
      BorderRadius.circular((size * 0.06).clamp(4.0, 12.0));
}

/// Sizing and touch targets (`design/tokens.md` §7).
///
/// [tapMin] is enforced by the component, not by the caller's padding. When
/// a control cluster does not fit it **wraps**; it never shrinks (no
/// `FittedBox(scaleDown)`).
abstract final class Dim {
  static const double tapMin = 48;
  static const double tapComfy = 56;
  static const double tapPrimary = 76;

  static const double iconSm = 20;
  static const double iconMd = 24;
  static const double iconLg = 28;
  static const double iconXl = 36;

  static const double focusWidth = 3;
  static const double focusOffset = 2;

  static const double scrubTrack = 6;
  static const double scrubThumb = 20;

  /// Layout breakpoint between the phone (bottom nav) and wide (side rail)
  /// shells. Compared against **container** constraints via `LayoutBuilder`,
  /// not `MediaQuery.size`, so a widget behaves correctly inside a narrow
  /// pane on a wide window.
  static const double wideBreakpoint = 760;

  /// Max width of the wide book-detail dialog (Library and Discover): two
  /// columns, cover/progress/actions beside the about text and chapters.
  static const double detailDialogMaxWidth = 880;
}

/// Motion (`design/tokens.md` §6). All animation must respect
/// `MediaQuery.disableAnimations`; use [durationFor] rather than the raw
/// constants at animation sites.
abstract final class Motion {
  static const Duration instant = Duration.zero;
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration base = Duration(milliseconds: 200);
  static const Duration slow = Duration(milliseconds: 320);
  static const Duration skeleton = Duration(milliseconds: 1600);

  static const Curve standard = Cubic(0.2, 0, 0, 1);
  static const Curve decel = Cubic(0, 0, 0, 1);
  static const Curve accel = Cubic(0.3, 0, 1, 1);

  /// Collapses [d] to zero when the platform asks for reduced motion, so a
  /// caller never has to remember the check.
  static Duration durationFor(BuildContext context, Duration d) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false ? Duration.zero : d;
}
