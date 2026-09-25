import 'package:flutter/material.dart';

/// The web build has no real local filesystem path to render (local import
/// is IO-only — see `services/local_audiobook_import_web.dart`), so this
/// just defers straight to the caller's error/fallback builder.
Widget buildLocalFileImage(
  String path, {
  double? width,
  double? height,
  BoxFit fit = BoxFit.cover,
  required Widget Function(BuildContext, Object, StackTrace?) errorBuilder,
}) {
  return Builder(
    builder: (context) =>
        errorBuilder(context, 'local file images are unsupported on web', null),
  );
}
