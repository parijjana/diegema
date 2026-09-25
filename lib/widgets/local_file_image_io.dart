import 'dart:io';

import 'package:flutter/material.dart';

/// Renders the image file at [path] via [Image.file].
Widget buildLocalFileImage(
  String path, {
  double? width,
  double? height,
  BoxFit fit = BoxFit.cover,
  required Widget Function(BuildContext, Object, StackTrace?) errorBuilder,
}) {
  return Image.file(
    File(path),
    width: width,
    height: height,
    fit: fit,
    errorBuilder: errorBuilder,
  );
}
