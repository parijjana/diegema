import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show FontLoader;
import 'package:path/path.dart' as p;
import 'package:diegema/theme/app_typography.dart';

/// Loads real fonts into the golden-test renderer.
///
/// `flutter_test` ships one font — a placeholder that draws every glyph as
/// a filled rectangle. Goldens taken without this are unreadable, which
/// defeats the point of committing frames of a transition so a human can
/// judge whether it reads well.
///
/// Two families are loaded:
///
/// - **Inter**, the app's own bundled sans, read straight off disk rather
///   than through `rootBundle` so it does not depend on how the test asset
///   bundle was built.
/// - **MaterialIcons**, from the Flutter SDK's own font cache, located
///   relative to the Dart executable running the test so it works on any
///   machine and in CI. Without it every icon — including the play button
///   the player screen is built around — renders as an empty box.
Future<void> loadGoldenFonts() async {
  await _loadFamily('Inter', [
    'assets/fonts/Inter-Regular.ttf',
    'assets/fonts/Inter-Medium.ttf',
    'assets/fonts/Inter-SemiBold.ttf',
    'assets/fonts/Inter-Bold.ttf',
  ]);

  final icons = _materialIconsPath();
  if (icons != null) await _loadFamily('MaterialIcons', [icons]);

  final serif = _serifPath();
  if (serif != null) {
    // Registered under every name the app asks for, not just its own: the
    // engine does not fall through `fontFamilyFallback` when the *primary*
    // family is simply unknown, so registering it as 'Georgia' alone still
    // left every serif heading as placeholder rectangles.
    for (final family in AppType.serifFallback) {
      await _loadFamily(family, [serif]);
    }
  }
}

Future<void> _loadFamily(String family, List<String> paths) async {
  final loader = FontLoader(family);
  var any = false;
  for (final path in paths) {
    final file = File(path);
    if (!file.existsSync()) continue;
    any = true;
    loader.addFont(
        file.readAsBytes().then((b) => ByteData.sublistView(b)));
  }
  if (any) await loader.load();
}

/// Locates `MaterialIcons-Regular.otf` inside the Flutter SDK's font
/// cache. The executable running a widget test is `flutter_tester`, buried
/// at `<flutter>/bin/cache/artifacts/engine/<platform>/flutter_tester`, so
/// the cache root is found by walking up until the font turns up rather
/// than by hard-coding a depth.
String? _materialIconsPath() {
  const relative = ['artifacts', 'material_fonts', 'MaterialIcons-Regular.otf'];

  final roots = <String>[
    if (Platform.environment['FLUTTER_ROOT'] case final root?)
      p.join(root, 'bin', 'cache'),
  ];
  var dir = p.dirname(Platform.resolvedExecutable);
  for (var i = 0; i < 8; i++) {
    roots.add(dir);
    final parent = p.dirname(dir);
    if (parent == dir) break;
    dir = parent;
  }

  for (final root in roots) {
    final font = p.joinAll([root, ...relative]);
    if (File(font).existsSync()) return font;
  }
  return null;
}

/// The app asks for a serif face by name (`Iowan Old Style`, then
/// `Palatino`, then `Georgia`) and never bundles one — on a real device it
/// resolves from the platform's own stack. The test renderer has no system
/// fonts at all, so without this the wordmark and every book title render
/// as placeholder rectangles. Georgia is loaded under its own name, which
/// is genuinely one of the app's declared fallbacks, so the goldens show a
/// serif the app really would use.
///
/// This is why the goldens are macOS-generated (as is CI).
String? _serifPath() {
  const candidates = [
    '/System/Library/Fonts/Supplemental/Georgia.ttf',
    '/Library/Fonts/Georgia.ttf',
  ];
  for (final path in candidates) {
    if (File(path).existsSync()) return path;
  }
  return null;
}
