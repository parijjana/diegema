import 'package:flutter/widgets.dart';

/// The in-app text size (Settings > Appearance), applied on top of whatever
/// scale the system already asks for.
///
/// Two limits keep layouts holding: text never drops below 13px (the app's
/// floor, or its nominal size if that was already smaller), and the result
/// never exceeds 2x the nominal size, the largest scale the screens are
/// tested at, unless the system itself already asks for more.
class AppTextScaler extends TextScaler {
  final TextScaler base;
  final double factor;

  const AppTextScaler(this.base, this.factor);

  @override
  double scale(double fontSize) {
    final basis = base.scale(fontSize);
    final floor = fontSize < 13.0 ? fontSize : 13.0;
    final cap = basis > fontSize * 2 ? basis : fontSize * 2;
    return (basis * factor).clamp(floor, cap).toDouble();
  }

  @override
  double get textScaleFactor => scale(14.0) / 14.0;

  @override
  bool operator ==(Object other) =>
      other is AppTextScaler && other.base == base && other.factor == factor;

  @override
  int get hashCode => Object.hash(base, factor);
}
