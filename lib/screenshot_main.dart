// ============================================================================
// store-launch-kit TEMPLATE — screenshot_main.dart  (SCAFFOLD, fill the blanks)
//
// Copy into the TARGET app as lib/screenshot_main.dart and replace every
// {{TOKEN}} / `// FILL:` block below. Most placeholder tokens are intentionally
// non-compiling — the file will NOT build until they are filled in per app.
// The exceptions are tokens that sit inside a string (/private/tmp/diegema-store-screenshots, the scene
// slugs, {{SCENE_n_WIDGET}}): those compile, so the harness detects them at
// runtime and says so (see SCENE_GUARD_UNSET) rather than failing silently.
//
// This is a STANDALONE entry point. The shipped app never imports it, so it can
// freely flip the capture-mode flags and pull in the (also-standalone) seed file.
//
// The proven MECHANICS below are app-agnostic — keep them:
//   * a _Target struct + _targets list mirroring store-fields.json,
//   * off-screen OverflowBox + MediaQuery + RepaintBoundary at a fixed SizedBox,
//   * a fresh ValueKey per shot so each scene remounts cleanly,
//   * _settle() — pump until the tree stops ANIMATING (transientCallbackCount),
//     with a per-frame timeout so a stalled macOS window cannot hang the run,
//   * the scene-mount guard (_expectedWidget + _mountAndVerify): confirm the
//     right screen is actually mounted before rasterizing it,
//   * _capture() via RenderRepaintBoundary.toImage(pixelRatio:),
//   * the SCREENSHOTS_WRITTEN_TO: / CAPTURED / SKIPPED prints + exit(0),
//   * a FlutterError hook with TWO buckets (overflow + layout error) and an
//     authoritative capture_manifest.json.
//
// Run in DEBUG (assertions on — required for overflow/layout-error detection)
// and with DEMO_MODE (AppShell honours DemoDeepLink only under kDemoMode; without
// it scene 4 never opens the book and no scene loads the hero book):
//   flutter run -d macos -t lib/screenshot_main.dart --dart-define=DEMO_MODE=true
// It opens a window, silently renders every (target x scene), writes PNGs under
// /private/tmp/diegema-store-screenshots/<store-or-device-subfolder>/ (e.g. ios/ipad13/, play/phone/),
// writes /private/tmp/diegema-store-screenshots/capture_manifest.json, prints the written paths, and exits.
// Validate the result with scripts/validate_screenshots.py /private/tmp/diegema-store-screenshots.
//
// SELECTIVE (PARTIAL) CAPTURE — re-shoot one store without re-shooting all of
// them. Optional; with no --dart-define the run is a FULL run and behaves
// exactly as it always has:
//   flutter run -d macos -t lib/screenshot_main.dart --dart-define=DEMO_MODE=true \
//     --dart-define=CAPTURE_TARGETS=ios,mac --dart-define=CAPTURE_SCENES=game
// See the SELECTIVE CAPTURE block further down for the matching rules, and
// _mergeIntoManifest() for how a partial run MERGES into the existing manifest
// instead of replacing it (a replace would turn every un-recaptured PNG into a
// validator [STRAY]).
//
// ---------------------------------------------------------------------------
// TOKEN INVENTORY — substitute exactly these, verbatim {{...}} spelling, AT THE
// LINES NAMED. This inventory ALSO spells out every token, so "replace the one
// occurrence" is WRONG; every OTHER "{{" is LITERAL (see the second list).
//
// Live substitution sites (all occurrences of a token below are live unless
// a line number is called out as prose in the second list):
//   {{IMPORTS}}                            line 128
//   /private/tmp/diegema-store-screenshots                           lines 7, 30, 31, 32, 99, 134 — all six
//                                           are live; put the SAME absolute path
//                                           in every one of them.
//   now-playing .. settings   lines 265-269 (in _sceneNames)
//   {{MORE_SCENES}}                        line 270 (in _sceneNames — delete the
//                                           whole line for exactly 5 scenes)
//   NowPlayingScreen .. SettingsScreen  lines 323-327 (in _expectedWidget)
//   {{MORE_SCENE_WIDGETS}}                 line 328 (in _expectedWidget — same
//                                           delete-for-5 / extend-for-6+ rule)
//   Diegema                           line 516
//   {{PAGE_WIDTH_HEURISTIC}}               line 574 (or delete the whole method
//                                           per its own FILL note)
//   {{SCENE_BUILDER}}                      line 583
//   {{APP_ROOT_WIDGET}}                    line 588 ONLY. The identical token
//                                           text at lines 279 and 623 NAMES this
//                                           token in prose — leave those two alone.
//   {{SEED_WRAPPED_CHILD}}                 line 625 ONLY. The identical token
//                                           text at line 599 names this token in
//                                           prose — leave that one alone.
//   AppTheme.dark()                          line 1136
//
// Literal / prose — must NOT be substituted:
//   * lines 52 + 74   — the "/private/tmp/diegema-store-screenshots" mentions inside THIS inventory (this
//                       line is one of them): a blanket search finds EIGHT in the
//                       file, but only the six listed above are live.
//   * line 259        — "{{MORE_SCENES}}" / "{{SCENE_6_SLUG}}" inside the
//                       how-to-add-a-6th-scene note (naming tokens, not using them)
//   * line 279        — "{{APP_ROOT_WIDGET}}" named in prose (see above)
//   * line 283        — the generic "{{TOKEN}}" example in the _expectedWidget note
//   * line 597        — the "nothing here is a real {{TOKEN}}" note on the three
//                       PROSE-EXAMPLE seeding blocks in _buildScene()
//   * line 599        — "{{SEED_WRAPPED_CHILD}}" named in prose (see above)
//   * line 623        — "{{APP_ROOT_WIDGET}}" named in prose (see above)
//   * line 765        — `name.contains('{{')` — LIVE CODE implementing the
//                       SCENE_GUARD_UNSET detection. A blanket sweep that strips
//                       every "{{" instead of substituting the named tokens above
//                       would silently defeat this check.
// (Line numbers above are current as of this revision; re-grep for "{{" if the file
// has since been edited and they may have drifted.)
// ---------------------------------------------------------------------------
// macOS APP SANDBOX — keep it ON, grant a DEBUG-ONLY exception.
//
// [_outRoot] is an absolute path inside the repo, and a sandboxed app can only
// write inside its own container. Do NOT disable the sandbox for a capture run
// and re-enable it afterwards: that mutates git-tracked build config on every
// run and it is easy to forget the revert. Instead add these keys to
// `macos/Runner/DebugProfile.entitlements` ONLY — never `Release.entitlements`,
// so store builds stay untouched:
//
//   <key>com.apple.security.temporary-exception.files.absolute-path.read-write</key>
//   <array><string>/private/tmp/diegema-store-screenshots/</string></array>
//   <key>com.apple.security.network.server</key><true/>
//
// The path string must stay in sync with [_outRoot] (trailing slash included).
// `network.server` is NOT optional: without it the sandbox blocks the Dart VM
// service socket and `flutter run` cannot attach. The symptom is misleading —
// the capture itself still runs and the PNGs are fine, it just looks like a
// failed run. Full write-up:
// ~/code/projects/lessons_learnt/flutter-macos-sandboxed-screenshot-capture.md
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

// FILL: imports for the screen(s) you capture, the screenshot_mode.dart flags,
// every provider/notifier you seed, and screenshot_seed.dart. Example shape:
//   import 'features/<feature>/screenshot_mode.dart';
//   import 'features/<feature>/screens/<main_screen>.dart';
//   import 'screenshot_seed.dart';
import 'app.dart';
import 'core/demo_deeplink.dart';
import 'core/demo_mode.dart';
import 'core/ui_preferences.dart';
import 'database/app_database.dart';
import 'screenshot_mode.dart';
import 'screenshot_seed.dart';
import 'services/demo_artwork_service.dart';
import 'services/demo_downloader.dart';
import 'services/demo_librivox_service.dart';

/// Built once in [main] and shared by every scene, because [_buildScene] is
/// synchronous and seeding drift is not. Sharing it is also correct rather than
/// merely convenient: each scene remounts the app against the SAME library, so
/// the shots depict one user's collection instead of five unrelated ones.
///
/// Rebuilt (same seed) before EVERY shot: AudiobookApp closes its database in
/// dispose(), and each shot remounts the app under a new key, so a shared
/// instance is closed from the second shot on (Library then shows its "Could
/// not read your library" error state — the 2026-10-04 Play run caught this).
late AppDatabase _screenshotDb;

/// The library scan `LibraryScreen` runs on mount, replaced with a no-op. The
/// real one walks the downloads directory through `path_provider`; under
/// capture the library comes from [_screenshotDb] and a filesystem walk could
/// only add books that are not in the catalogue.
Future<void> _noLibraryScan(AppDatabase db) async {}

// FILL: absolute path to the output root. The harness creates <root>/<store>/
// subfolders. Keep it inside the app repo (e.g. .../<app>/store_screenshots) so
// the review + bundling steps can find the PNGs. Must match the sandbox
// temporary-exception path in DebugProfile.entitlements (see the header).
const String _outRoot = '/private/tmp/diegema-store-screenshots';

/// How long `_settle()` waits for a screen to stop animating before giving up
/// and rasterizing anyway (recording a settle timeout). Set this comfortably
/// above the app's LONGEST entrance animation, with room for slow frames.
const Duration _settleTimeout = Duration(seconds: 8);

/// How long `_mountAndVerify()` waits for the scene's expected widget to
/// appear in the element tree before giving up and recording a mismatch.
/// Sized off DiscoverScreen's shelf load — eight category queries spaced a
/// second apart by RateLimitDispatcher — plus margin.
const Duration _mountTimeout = Duration(seconds: 20);

/// Consecutive animation-free frames `_settle()` requires before it calls the
/// tree settled. >1 so a controller that chains into another is not mistaken
/// for a fully settled tree.
const int _quietFramesRequired = 3;

/// Longest a SINGLE `endOfFrame` await may block before `_settle()` gives up on
/// that frame. Not optional: macOS stops producing frames for an occluded window
/// or a sleeping display, and an un-timed-out `await endOfFrame` then hangs the
/// whole capture run forever (this cost one 37-minute dead run). [_settleTimeout]
/// cannot save it — a deadline checked BETWEEN awaits is never reached while one
/// await is blocked. Every `endOfFrame` here goes through `_awaitFrame()`.
const Duration _frameWaitTimeout = Duration(milliseconds: 500);

// ---------------------------------------------------------------------------
// LAYOUT-ERROR ATTRIBUTION (harness-side, framework ground truth).
//
// A single FlutterError.onError hook (installed in main()) records layout errors
// against the shot being rendered RIGHT NOW. `_currentShotId` is set BEFORE
// setState for each shot, so errors thrown during the build / _settle()
// layout+paint pass attribute to the correct shot. Each shot remounts a fresh
// MaterialApp (fresh render objects), so attribution is clean and the outer
// OverflowBox scaffold itself never throws. Each shot's lists are folded into its
// capture_manifest.json entry.
//
// TWO buckets, because they fail differently:
//   _overflowByShot     — 'overflowed': content too big for its box, but it
//                         still PAINTS. Visible as clipped/striped content.
//   _layoutErrorsByShot — layout ASSERTION failures ([_layoutErrorNeedles]):
//                         the subtree never gets a size, so it paints NOTHING.
//                         Strictly worse, and invisible to every other check —
//                         the PNG has perfect pixel dimensions and is BLANK. A
//                         hook watching only 'overflowed' shipped four blank
//                         gameplay shots in the reference app. See
//                         lessons_learnt/flutter-fittedbox-infinite-width-blank-subtree.md
//
// IMPORTANT: this ONLY works in DEBUG mode (assertions on). Flutter routes these
// through FlutterError.onError only when assertions run — NEVER capture with
// --release / --profile, or both classes go silently undetected.
// ---------------------------------------------------------------------------
final Map<String, List<String>> _overflowByShot = <String, List<String>>{};
final Map<String, List<String>> _layoutErrorsByShot = <String, List<String>>{};

/// Substrings identifying a layout failure that leaves a subtree UNPAINTED.
/// App-agnostic — these are rendering-library assertions, not app strings.
/// Each needle below was confirmed against the Flutter SDK's own
/// `rendering/box.dart` (`RenderBox.debugAssertDoesMeetConstraints`) — grep
/// that file if a future SDK changes the wording upstream.
const List<String> _layoutErrorNeedles = [
  'forces an infinite', // BoxConstraints forces an infinite width/height
  'given an infinite size', // "'$runtimeType' object was given an infinite size during layout." — the RESULT-side infinite-size failure. THIS is what actually fires for an infinite-width child (the constraints-side needle above does not catch it), and is exactly the blank-subtree-at-perfect-dimensions failure this bucket exists for.
  'did not set its size', // 'RenderBox did not set its size during layout.'
  'does not meet its constraints', // "'$runtimeType' does not meet its constraints."
  'was not laid out', // RenderBox was not laid out
  'hasSize', // 'child!.hasSize': is not true
  // Catch-all for anything else. NOTE: `details.exceptionAsString()` on a
  // FlutterError returns just the ErrorSummary text (i.e. the needles above),
  // NOT a "Failed assertion:" prefix — that prefix is Dart's own formatting of
  // a raw AssertionError.toString(), a DIFFERENT and less common path than the
  // `throwError(ErrorSummary(...))` / `FlutterError.fromParts(...)` path most
  // rendering-library failures take. This needle only catches the raw-assert case.
  'Failed assertion',
];

String _currentShotId = '';

/// One store/device output target.
///
/// SOURCE OF TRUTH: the rows below MUST mirror `screenshot_targets` in
/// ~/.claude/skills/store-launch-kit/references/store-fields.json
/// (store, device, dir, filename_prefix, logical_w/h, ratio, layout,
/// window_controls). store-fields.json also lists px_w/px_h = logical x ratio —
/// that is the exact pixel size each store expects; verify captured PNGs against
/// it (see the reference doc's verification checklist).
class _Target {
  final String
      store; // store id, e.g. 'ios-app-store' (matches store-fields.json)
  final String
      device; // device id, e.g. 'ipad-13-landscape' (matches store-fields.json)
  final String
      dir; // output subfolder under _outRoot; may be nested, e.g. 'ios/ipad13'
  final String
      prefix; // filename prefix to disambiguate orientations sharing a dir
  final double w,
      h,
      ratio; // logical size + pixelRatio  (px = w*ratio by h*ratio)
  final ScreenshotLayout layout;
  final ScreenshotWindowControls controls;
  final List<int> scenes; // scene numbers to render for this target
  const _Target(this.store, this.device, this.dir, this.prefix, this.w, this.h,
      this.ratio, this.layout, this.controls, this.scenes);
}

// FILL: one row per screenshot_targets entry in store-fields.json.
// FOLDER LAYOUT: multi-device stores use device subfolders (ios/iphone69,
// ios/ipad13, play/phone, play/tablet); single-device stores stay flat
// (mac, microsoft). The iPad 13" PORTRAIT and LANDSCAPE shots share ios/ipad13/
// because App Store Connect has ONE iPad 13" section that accepts both
// orientations — landscape is written with the 'land-' filename prefix.
// LANDSCAPE is expressed purely by w>h (+ MediaQuery size); the ScreenshotLayout
// enum is deliberately NOT expanded — a landscape iPad reuses ScreenshotLayout.tablet.
//
// REVIEWER DECISION POINT — scene selection per target:
//   * desktop + tablet: render the full scene set.
//   * narrow phone portrait: only ship scenes that actually FIT the layout.
//     Skip a scene (drop its number from the list) rather than forcing a
//     cramped shot. Decide this by eye after the first phone run.
//   * landscape iPad: defaults to the SAME scenes as portrait iPad — re-pick by
//     eye (a landscape composition may want a different subset).
const List<_Target> _targets = [
  // Mac, iOS and Google Play. Microsoft Store is absent until `windows/` is
  // scaffolded; adding it is one row plus a re-run — the harness renders
  // every size from the same macOS process.
  //
  // store             device               dir             prefix   w     h     ratio  layout                        controls                        scenes
  _Target('mac-app-store', 'mac', 'mac', '', 1440, 900, 2.0,
      ScreenshotLayout.desktop, ScreenshotWindowControls.none, [1, 2, 3, 4, 5]),
  _Target(
      'ios-app-store',
      'iphone-6.9',
      'ios/iphone69',
      '',
      430,
      932,
      3.0,
      ScreenshotLayout.mobilePhone,
      ScreenshotWindowControls.none,
      [1, 2, 3, 4, 5]),
  _Target(
      'ios-app-store',
      'iphone-6.5',
      'ios/iphone65',
      '',
      428,
      926,
      3.0,
      ScreenshotLayout.mobilePhone,
      ScreenshotWindowControls.none,
      [1, 2, 3, 4, 5]),
  _Target('ios-app-store', 'ipad-13', 'ios/ipad13', '', 1024, 1366, 2.0,
      ScreenshotLayout.tablet, ScreenshotWindowControls.none, [1, 2, 3, 4, 5]),
  _Target(
      'ios-app-store',
      'ipad-13-landscape',
      'ios/ipad13',
      'land-',
      1366,
      1024,
      2.0,
      ScreenshotLayout.tablet,
      ScreenshotWindowControls.none,
      [1, 2, 3, 4, 5]),
  _Target('google-play', 'phone', 'play/phone', '', 360, 800, 3.0,
      ScreenshotLayout.mobilePhone, ScreenshotWindowControls.none,
      [1, 2, 3, 4, 5]),
  _Target('google-play', 'tablet', 'play/tablet', '', 800, 1280, 2.0,
      ScreenshotLayout.tablet, ScreenshotWindowControls.none, [1, 2, 3, 4, 5]),
  _Target(
      'google-play',
      'tablet-landscape',
      'play/tablet',
      'land-',
      1280,
      800,
      2.0,
      ScreenshotLayout.tablet,
      ScreenshotWindowControls.none,
      [1, 2, 3, 4, 5]),
];

// FILL: human-readable, zero-padded, ordered filenames per scene number. These
// become the PNG basenames (store galleries sort alphabetically, so number them).
// Five scenes are scaffolded below — the common case (both reference apps ship
// 5+) — and the default _targets rows below already request scenes 1-5, so the
// two maps and the target rows agree out of the box. For a 6th+ scene, add
// `6: '06-{{SCENE_6_SLUG}}'` etc. on the {{MORE_SCENES}} line (delete the line
// entirely for exactly 5 scenes). For FEWER than 5, delete the extra entries
// here AND from _expectedWidget below, and drop the matching scene numbers
// from every _Target row's scene list — leaving a mismatch is what makes
// `_sceneNames[scene]` return null and collides output onto `<dir>/null.png`.
const Map<int, String> _sceneNames = {
  1: '01-now-playing',
  2: '02-library',
  3: '03-discover',
  4: '04-book-detail',
  5: '05-settings',
};

// FILL: scene number -> the NAME of the widget that must be MOUNTED inside the
// capture boundary for that scene. This is the scene-mount guard's oracle.
//
// HOW TO FILL THIS IN: for each scene in _sceneNames, look at what
// _buildScene() returns for it and take the runtimeType name of the screen
// widget a human would recognise in the finished PNG — usually the class from
// {{APP_ROOT_WIDGET}} or the per-scene screen it swaps in. Plain string, exactly
// as written in the source, no <T> and no 'const':
//   1: 'DashboardScreen',
//   2: 'EditorScreen',
// A scene left as an unreplaced {{TOKEN}} (or given an empty string) simply
// DISABLES the guard for that scene — the run still succeeds but prints
// SCENE_GUARD_UNSET, so a half-filled map is loud rather than silent. Every
// scene should end up with a real entry.
//
// WARNING — the guard is a TAUTOLOGY for a state-driven single-screen app: if
// every scene renders the SAME root widget (e.g. one EditorScreen/HomeScreen
// whose look changes only via provider/notifier state, with panels translated
// off-screen via AnimatedPositioned rather than conditionally built), then
// naming that one widget for two different scenes can NEVER fail — it is
// trivially always mounted, so it catches nothing for those scenes. (Seen in a
// reference app that renders EditorScreen for all 5 scenes and keeps both
// sidebars permanently mounted, just moved off-screen: its scene-2/scene-3
// entries could not have caught a wrong-screen mistake between those two.) If
// the same widget name would legitimately apply to more than one scene here,
// the guard is NOT discriminating for those scenes — instead either:
//   * pick a widget unique to that scene's state (a sidebar that only builds
//     when open, a dialog, a status-bar sub-widget), or
//   * leave the entry empty/unfilled and accept SCENE_GUARD_UNSET for that
//     scene, relying on visual inspection instead of a guard that can't tell
//     the difference.
// (This is a documentation-only fix. A negative-assertion / "forbidden
// widget" oracle that could catch this case is a separate feature decision —
// see HARNESS_BACKLOG.md — not implemented here.)
//
// WHY (the guard itself): a capture can silently rasterize the PREVIOUS scene's screen — correct
// dimensions, no overflow, no layout error, so every other gate passes it. Seen
// twice in the reference app (a results shot that showed the mode-select screen).
// _mountAndVerify() therefore walks the LIVE ELEMENT TREE under the capture
// boundary after settling and confirms this widget is mounted.
//
// Do NOT swap this for an app-maintained "current screen id" provider. That was
// tried first in the reference app and is unusable: it stuck at the previous
// screen while the correct one demonstrably mounted and painted, false-positiving
// 39 of 48 shots. The element tree is ground truth — if the widget is mounted
// under the boundary, it is what gets rasterized.
//
// Matching on a type NAME would break under release obfuscation; this entry
// point only ever runs in debug, so it is safe here.
const Map<int, String> _expectedWidget = {
  1: 'NowPlayingScreen', // e.g. 'DashboardScreen'
  2: 'LibraryScreen',
  3: 'DiscoverScreen',
  4: 'BookDetailPane',
  5: 'SettingsScreen',
};

// ---------------------------------------------------------------------------
// SELECTIVE CAPTURE — optional filters. BOTH EMPTY (the default) means capture
// EVERYTHING, i.e. the historical behaviour, byte-for-byte identical manifest.
//
//   flutter run -t lib/screenshot_main.dart -d macos \
//     --dart-define=CAPTURE_TARGETS=ios,mac \
//     --dart-define=CAPTURE_SCENES=game,results
//
// These are COMPILE-TIME constants: `flutter run` must be restarted to change
// them — a hot reload/restart will NOT pick up a changed --dart-define.
//
// CAPTURE_TARGETS — comma-separated. A token selects a [_Target] row when it
// equals, case-insensitively, any of:
//   * the store id       'mac-app-store', 'google-play', 'microsoft-store'
//   * the device id      'ipad-13-landscape', 'phone'
//   * the output dir     'ios/ipad13', 'mac'
//   * a dir PATH PREFIX  'ios' -> BOTH ios/iphone69 and ios/ipad13
// So `mac` picks the Mac target (by dir), `ios` picks every iOS target (by dir
// prefix), and `google-play` picks both Play targets (by store id).
// NOTE: a dir prefix must be a whole path SEGMENT — 'io' does not match
// 'ios/ipad13'. Two targets that share a dir but differ by filename prefix
// (portrait + landscape iPad) are ALWAYS selected together by dir; use the
// device id to pick just one of them.
//
// CAPTURE_SCENES — comma-separated, matched against the scene NUMBER or its
// SLUG. (The scene map is keyed by int while the human-readable identity is the
// [_sceneNames] slug, so BOTH are accepted and may be mixed in one list.) A
// token selects scene n when, case-insensitively:
//   * it parses as an int equal to n                 '4'
//   * it equals the full scene name                  '04-writing-sprint'
//   * it equals the slug (name minus the 'NN-')      'writing-sprint'
//   * it is a SUBSTRING of the slug                  'sprint'
//
// LOUD FAILURE, never a silent no-op. A token matching NOTHING, or a filter
// combination selecting ZERO shots, prints CAPTURE_FILTER_ERROR and exits
// WITHOUT capturing anything and WITHOUT touching capture_manifest.json. A
// selected target whose own scene list contains none of the requested scenes
// (a phone that deliberately skips scene 4, say) is NOT an error — the token
// did match a real scene — but the target is reported as skipped so it can
// never look captured.
// ---------------------------------------------------------------------------
const String _captureTargetsFilter = String.fromEnvironment('CAPTURE_TARGETS');
const String _captureScenesFilter = String.fromEnvironment('CAPTURE_SCENES');

/// Splits a comma-separated dart-define into trimmed, lower-cased tokens.
List<String> _filterTokens(String raw) => raw
    .toLowerCase()
    .split(',')
    .map((s) => s.trim())
    .where((s) => s.isNotEmpty)
    .toList(growable: false);

bool _targetMatchesToken(_Target t, String token) {
  final dir = t.dir.toLowerCase();
  return t.store.toLowerCase() == token ||
      t.device.toLowerCase() == token ||
      dir == token ||
      dir.startsWith('$token/');
}

/// A scene's slug: its [_sceneNames] value with the ordering prefix stripped
/// ('04-writing-sprint' -> 'writing-sprint').
String _sceneSlug(int scene) {
  final name = _sceneNames[scene] ?? '';
  final m = RegExp(r'^\d+[-_]').firstMatch(name);
  return (m == null ? name : name.substring(m.end)).toLowerCase();
}

bool _sceneMatchesToken(int scene, String token) {
  if (int.tryParse(token) == scene) return true;
  final name = (_sceneNames[scene] ?? '').toLowerCase();
  final slug = _sceneSlug(scene);
  return name == token ||
      slug == token ||
      (slug.isNotEmpty && slug.contains(token));
}

/// One target plus the subset of its scenes this run will capture.
class _Planned {
  final _Target t;
  final List<int> scenes;
  const _Planned(this.t, this.scenes);
}

/// What this run will capture, what it will NOT, and why.
class _CapturePlan {
  final List<_Planned> selected;
  final List<String> skipped; // human-readable, printed at the end of the run
  final List<String> errors; // non-empty => abort before touching anything
  final bool partial; // true iff either filter was supplied
  const _CapturePlan(this.selected, this.skipped, this.errors, this.partial);
  int get shotCount => selected.fold<int>(0, (a, p) => a + p.scenes.length);
}

/// Total shots a FULL run would produce — the size of the shipped set.
int _canonicalShotCount() =>
    _targets.fold<int>(0, (a, t) => a + t.scenes.length);

_CapturePlan _buildCapturePlan() {
  final targetTokens = _filterTokens(_captureTargetsFilter);
  final sceneTokens = _filterTokens(_captureScenesFilter);
  final partial = targetTokens.isNotEmpty || sceneTokens.isNotEmpty;
  final errors = <String>[];

  // Report EVERY bad token, not just the first — a typo in a long list should
  // not need one round trip per typo.
  for (final tok in targetTokens) {
    if (!_targets.any((t) => _targetMatchesToken(t, tok))) {
      errors.add("CAPTURE_TARGETS token '$tok' matches no target. "
          'Known store ids: ${_targets.map((t) => t.store).toSet().join(', ')} | '
          'dirs: ${_targets.map((t) => t.dir).toSet().join(', ')} | '
          'devices: ${_targets.map((t) => t.device).toSet().join(', ')}');
    }
  }
  for (final tok in sceneTokens) {
    if (!_sceneNames.keys.any((s) => _sceneMatchesToken(s, tok))) {
      errors.add("CAPTURE_SCENES token '$tok' matches no scene. Known scenes: "
          '${_sceneNames.entries.map((e) => '${e.key}=${e.value}').join(', ')}');
    }
  }

  final selected = <_Planned>[];
  final skipped = <String>[];
  for (final t in _targets) {
    final label = '${t.dir}/${t.prefix}* (${t.store}/${t.device})';
    if (targetTokens.isNotEmpty &&
        !targetTokens.any((tok) => _targetMatchesToken(t, tok))) {
      skipped.add('$label — not selected by CAPTURE_TARGETS');
      continue;
    }
    final scenes = sceneTokens.isEmpty
        ? t.scenes
        : t.scenes
            .where((s) => sceneTokens.any((tok) => _sceneMatchesToken(s, tok)))
            .toList(growable: false);
    if (scenes.isEmpty) {
      skipped.add("$label — CAPTURE_SCENES selected none of this target's "
          'scenes ${t.scenes} (it deliberately renders only those)');
      continue;
    }
    if (scenes.length < t.scenes.length) {
      final dropped =
          t.scenes.where((s) => !scenes.contains(s)).toList(growable: false);
      skipped.add('$label scenes $dropped — not selected by CAPTURE_SCENES '
          '(scenes $scenes WERE captured for this target)');
    }
    selected.add(_Planned(t, scenes));
  }

  if (errors.isEmpty && selected.isEmpty) {
    errors.add('the CAPTURE_TARGETS/CAPTURE_SCENES combination selects ZERO '
        'shots (every token matched something, but no target renders any of '
        'the requested scenes)');
  }
  return _CapturePlan(selected, skipped, errors, partial);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kDemoMode) {
    // Every scene is entered through DemoDeepLink, which AppShell ignores
    // outside demo mode: the run would "pass" with the wrong screens.
    // ignore: avoid_print
    print('CAPTURE_SETUP_ERROR: run with --dart-define=DEMO_MODE=true');
    exit(2);
  }
  // On before seeding: the demo catalogue reads it to make every book
  // playable, so the gallery shows the full app rather than the web demo.
  kScreenshotCaptureMode = true;
  // Layout hook: attribute any layout error to the shot being rendered now
  // (_currentShotId), then still present it normally so it shows in the console.
  // DEBUG-ONLY — Flutter only routes these here when assertions are on. See the
  // note on _overflowByShot / _layoutErrorsByShot above; never run capture with
  // --release/--profile.
  FlutterError.onError = (FlutterErrorDetails details) {
    final msg = details.exceptionAsString();
    final first = msg.split('\n').first.trim();
    if (msg.contains('overflowed')) {
      (_overflowByShot[_currentShotId] ??= <String>[]).add(first);
    } else if (_layoutErrorNeedles.any(msg.contains)) {
      // Cap the list: one broken subtree can throw the same assertion on every
      // pumped frame, and an unbounded list would bloat the manifest.
      final bucket = _layoutErrorsByShot[_currentShotId] ??= <String>[];
      if (bucket.length < 10 && !bucket.contains(first)) bucket.add(first);
    }
    FlutterError.presentError(details);
  };
  // The template sizes and un-chromes the host window with window_manager
  // here. Diegema has no such dependency and does not need one: the capture
  // is an off-screen raster that never includes host chrome, and OverflowBox
  // gives each scene its full logical size whatever the window is doing.
  //
  // Seed the shared library before the first frame, so no scene races its
  // own initState load against the seed.
  _screenshotDb = await buildScreenshotDatabase();
  runApp(const _CaptureApp());
}

class _CaptureApp extends StatefulWidget {
  const _CaptureApp();
  @override
  State<_CaptureApp> createState() => _CaptureAppState();
}

class _CaptureAppState extends State<_CaptureApp> {
  final GlobalKey _boundaryKey = GlobalKey();
  final List<String> _written = [];
  final List<String> _skipped = [];

  /// Shots whose tree never reached visual rest within [_settleTimeout] — each
  /// one may have been rasterized mid-animation, so it needs a human look.
  /// Surfaced by validate_screenshots.py check 8 [SETTLE].
  final List<String> _settleTimeouts = [];

  /// Shots that landed on the wrong screen and recovered on the retry.
  /// Informational: the written PNG is correct, but the flake is real.
  /// Surfaced by validate_screenshots.py as a non-fatal [scene-retry].
  final List<String> _sceneRetries = [];

  /// Shots still on the wrong screen AFTER the retry — the PNG shows a different
  /// screen than its filename claims. A validator failure (check 9 [SCENE]).
  final List<String> _sceneMismatches = [];

  /// Scenes whose [_expectedWidget] entry was never filled in, so the mount
  /// guard did not run for them. Reported, non-fatal.
  final Set<int> _guardUnset = <int>{};
  final List<Map<String, dynamic>> _manifestShots =
      []; // one entry per written PNG
  bool _started = false;
  Widget? _shot;
  String _shotId = '';
  _Target _target = _targets.first;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _run());
    }
  }

  /// Builds one fully-seeded scene, wired with whatever state the screen reads.
  Widget _buildScene(int scene, _Target t) {
    // FILL: per-scene widget construction. Vary state by scene number to show
    // different surfaces (e.g. open a sidebar, start a timer, overlay a dialog).
    // Build the target screen and wrap it with the app's state. Example
    // (reference app): a manuscript editor whose scenes toggle sidebars and
    // swap in an active-sprint controller; scene 5 stacks a modal dialog.
    // Every scene is entered through `DemoDeepLink` — the app's own, already
    // tested state entry point (see core/demo_deeplink.dart, which exists
    // precisely because two earlier attempts at this screenshot matrix
    // foundered trying to drive Flutter's canvas from outside). Nothing here
    // reaches into private state.
    //
    // `play` is set on EVERY scene, not just the player one: it makes AppShell
    // load the hero book, which is what populates the mini player above the
    // nav bar on scenes 2-5. Without it those four shots show an empty
    // transport strip.
    final deepLink = switch (scene) {
      1 => const DemoDeepLink(screen: 0, play: kHeroBookId),
      2 => const DemoDeepLink(screen: 1, play: kHeroBookId),
      3 => const DemoDeepLink(screen: 2, play: kHeroBookId),
      4 => const DemoDeepLink(screen: 2, play: kHeroBookId, book: kHeroBookId),
      _ => const DemoDeepLink(screen: 3, play: kHeroBookId),
    };

    // The template leaves this mutable so a scene MAY swap the root widget
    // (stacking a modal dialog, say). Every Diegema scene is the same
    // AudiobookApp with a different deep link, so it can be final here.
    final Widget child = AudiobookApp(
      // Load-bearing. Without a per-shot key, Flutter UPDATES the existing
      // AudiobookApp element instead of remounting it, because consecutive
      // scenes differ only in constructor arguments. `AppShell` reads the deep
      // link exactly once — `late int _index = widget.deepLink.screen` runs in
      // initState and never again — so an updated shell keeps the PREVIOUS
      // scene's screen and every shot lags one behind. That is precisely what
      // the first two capture runs did, and the scene guard is what caught it.
      key: ValueKey(_currentShotId),
      database: _screenshotDb,
      // The same three demo services main.dart wires under DEMO_MODE, passed
      // explicitly so the harness never depends on a live librivox.org or
      // archive.org call. A capture run must be reproducible offline.
      libriVoxService: DemoLibriVoxService(),
      downloader: DemoDownloader(),
      artworkService: DemoArtworkService(),
      audioService: ScreenshotPlaybackService(),
      // An empty override map: reads return defaults without touching the
      // `shared_preferences` platform channel, so no shot can inherit the
      // developer's own saved skip interval.
      preferences: const UiPreferences(overrides: {}),
      libraryScanner: _noLibraryScan,
      // Forced rather than persisted. `AppSettings` honours this over anything
      // stored, so the whole gallery is one coherent theme. Re-run with
      // ThemeMode.light for a light set.
      initialThemeMode: ThemeMode.dark,
      deepLink: deepLink,
    );

    // ------------------------------------------------------------------------
    // FILL: seed the state the screen reads. Pick the pattern for the target
    // app's state management (detect from pubspec.yaml / main.dart), then seed
    // with the subclasses/overrides defined in screenshot_seed.dart. Realistic
    // domain content only — see GOTCHA 6 in the reference doc.
    //
    // The three blocks below are PROSE EXAMPLES to copy the SHAPE of by hand —
    // they are not substitution sites and nothing in them is a real {{TOKEN}}.
    // Add one provider/override line per notifier the screen reads, then write
    // the actual wrapped-child expression into the {{SEED_WRAPPED_CHILD}} token
    // below (there is exactly one live substitution site for this decision).
    //
    // --- OPTION A: `provider` package (MultiProvider + ChangeNotifier seeds) ---
    //   MultiProvider(
    //     providers: [
    //       ChangeNotifierProvider<FooProvider>.value(value: ScreenshotFooProvider(seedFoo())),
    //       ChangeNotifierProvider<BarProvider>(create: (_) => BarProvider()),
    //       // ...one more provider line per notifier the screen reads...
    //     ],
    //     child: child,
    //   )
    //
    // --- OPTION B: Riverpod (ProviderScope with overrides) ---
    //   ProviderScope(
    //     overrides: [
    //       fooProvider.overrideWith((ref) => ScreenshotFooNotifier(seedFoo())),
    //       barProvider.overrideWithValue(seedBar()),
    //       // ...one more override line per notifier the screen reads...
    //     ],
    //     child: child,
    //   )
    //
    // --- OPTION C: no DI framework — construct the screen with seeded args ---
    //   child // where {{APP_ROOT_WIDGET}} above already took seeded constructor args
    // ------------------------------------------------------------------------
    return child;
  }

  Future<void> _run() async {
    // Resolve the selective-capture filters FIRST: a bad filter must abort
    // before a single PNG is written and before capture_manifest.json is
    // touched, so a typo cannot leave the shipped set half-rewritten.
    final plan = _buildCapturePlan();
    if (plan.errors.isNotEmpty) {
      for (final e in plan.errors) {
        // ignore: avoid_print
        print('CAPTURE_FILTER_ERROR: $e');
      }
      // ignore: avoid_print
      print('CAPTURE_ABORTED: nothing was captured and '
          '$_outRoot/capture_manifest.json was NOT modified.');
      exit(2);
    }
    // ignore: avoid_print
    print(plan.partial
        ? 'CAPTURE_PLAN: PARTIAL run — ${plan.shotCount} of '
            '${_canonicalShotCount()} shot(s), '
            '${plan.selected.length} of ${_targets.length} target(s)  '
            '[CAPTURE_TARGETS=$_captureTargetsFilter '
            'CAPTURE_SCENES=$_captureScenesFilter]'
        : 'CAPTURE_PLAN: FULL run — ${plan.shotCount} shot(s), '
            '${_targets.length} target(s), no filters');
    for (final p in plan.selected) {
      final t = p.t;
      Directory('$_outRoot/${t.dir}').createSync(recursive: true);
      for (final scene in p.scenes) {
        // Flip the gated flags for THIS shot before building the scene. Every
        // additive/gated edit in the app tree reads these synchronously.
        kScreenshotCaptureMode = true;
        kScreenshotLayout = t.layout;
        kScreenshotWindowControls = t.controls;
        final shotId = '${t.dir}/${t.prefix}${_sceneNames[scene]}';
        // Set the CURRENT shot id BEFORE setState so any overflow/layout error
        // thrown during the build / _settle() layout+paint pass attributes to
        // this shot. It stays at the BASE id across the retry below, so the
        // manifest entry still finds its errors.
        _currentShotId = shotId;
        _screenshotDb = await buildScreenshotDatabase();
        // Build the scene ONCE. _buildScene() may MUTATE shared app state
        // (seeding a controller, starting a round, pushing a route), so the
        // retry below must remount THIS SAME widget rather than call the builder
        // again — see _mountAndVerify().
        final sceneWidget = _buildScene(scene, t);
        // Mount the scene and CHECK we actually landed on it. One retry with a
        // forced fresh mount clears the transient case; a second failure is
        // recorded and fails the validator rather than silently shipping a
        // screenshot of the wrong screen.
        var landed = await _mountAndVerify(sceneWidget, scene, t, shotId);
        if (!landed) {
          // Blank the tree first so the retry is a genuine remount and not a
          // no-op rebuild of an identical widget.
          setState(() {
            _shot = null;
            _shotId = '$shotId#blank';
          });
          await _awaitFrame();
          landed =
              await _mountAndVerify(sceneWidget, scene, t, '$shotId#retry');
          // Land in EXACTLY ONE bucket: recorded only once we know whether the
          // retry recovered it or not. Recording into _sceneRetries BEFORE
          // attempting the retry (as an earlier version of this did) meant a
          // hard mismatch landed in BOTH buckets — contradictory validator
          // output claiming the shot both "recovered" and "shows the WRONG
          // screen". A recovered shot stays non-fatal; only a shot still wrong
          // after the retry fails the validator.
          if (landed) {
            _sceneRetries.add('$shotId: ${_expectedWidget[scene]} not mounted '
                'on first try — recovered on retry');
          } else {
            _sceneMismatches.add('$shotId: ${_expectedWidget[scene]} still not '
                'mounted after retry');
          }
        }
        await _capture(t, scene);
      }
    }
    _writeManifest(plan);
    // ignore: avoid_print
    print('SCREENSHOTS_WRITTEN_TO: $_outRoot');
    for (final p in _written) {
      // ignore: avoid_print
      print(p);
    }
    if (_skipped.isNotEmpty) {
      // ignore: avoid_print
      print('SKIPPED: ${_skipped.join(' | ')}');
    }
    if (_settleTimeouts.isNotEmpty) {
      // ignore: avoid_print
      print('SETTLE_TIMEOUT (may be mid-animation, inspect these): '
          '${_settleTimeouts.join(' | ')}');
    }
    if (_sceneRetries.isNotEmpty) {
      // ignore: avoid_print
      print('SCENE_RETRY (landed on the wrong screen, recovered): '
          '${_sceneRetries.join(' | ')}');
    }
    if (_sceneMismatches.isNotEmpty) {
      // ignore: avoid_print
      print('SCENE_MISMATCH (PNG shows the WRONG screen): '
          '${_sceneMismatches.join(' | ')}');
    }
    if (_layoutErrorsByShot.isNotEmpty) {
      // ignore: avoid_print
      print('LAYOUT_ERRORS (subtree unpainted — these shots are BLANK): '
          '${_layoutErrorsByShot.keys.join(' | ')}');
    }
    if (_guardUnset.isNotEmpty) {
      // ignore: avoid_print
      print('SCENE_GUARD_UNSET (fill _expectedWidget for these scene numbers — '
          'the wrong-screen guard did NOT run): ${_guardUnset.join(', ')}');
    }
    // A partial run must NEVER be mistakable for a full one. Say so last, where
    // a human actually looks, and name everything that was not re-captured.
    if (plan.partial) {
      // ignore: avoid_print
      print('PARTIAL_RUN: captured ${plan.shotCount} of '
          '${_canonicalShotCount()} shot(s). The rest were NOT re-rendered — '
          'their manifest entries were carried over from the previous run.');
      // ignore: avoid_print
      print('CAPTURE_SKIPPED_TARGETS (not re-captured this run):');
      for (final s in plan.skipped) {
        // ignore: avoid_print
        print('  - $s');
      }
    }
    exit(0);
  }

  /// The widget name the scene-mount guard should look for, or null when the
  /// guard is not configured for [scene] — a missing entry, an empty string, or
  /// an unreplaced `{{TOKEN}}` left over from the scaffold. Unconfigured scenes
  /// are NOT failed; they are collected in [_guardUnset] and printed at the end
  /// so a half-filled [_expectedWidget] map is obvious rather than silent.
  String? _expectedWidgetFor(int scene) {
    final name = _expectedWidget[scene];
    if (name == null || name.isEmpty || name.contains('{{')) {
      _guardUnset.add(scene);
      return null;
    }
    return name;
  }

  /// Whether a widget whose runtimeType is named [typeName] is mounted anywhere
  /// under [ctx]. Debug-harness only — matching on a type NAME would break under
  /// release obfuscation, but this entry point never ships.
  /// Prints the app-owned widget types actually mounted under the capture
  /// boundary when the scene guard fails, so a mismatch names a suspect
  /// instead of only reporting an absence.
  void _dumpMountedScreens(String shotId, String expected) {
    final ctx = _boundaryKey.currentContext;
    if (ctx == null || !ctx.mounted) {
      // ignore: avoid_print
      print('MOUNT_DUMP $shotId: no boundary context');
      return;
    }
    final seen = <String>{};
    void walk(Element el) {
      final n = el.widget.runtimeType.toString();
      if (n.endsWith('Screen') ||
          n.endsWith('Pane') ||
          n.endsWith('Shell') ||
          n.endsWith('App') ||
          n.endsWith('Bar') ||
          n.endsWith('View')) {
        seen.add(n);
      }
      el.visitChildren(walk);
    }

    ctx.visitChildElements(walk);
    // ignore: avoid_print
    print('MOUNT_DUMP $shotId: wanted $expected, mounted: '
        '${(seen.toList()..sort()).join(", ")}');
  }

  bool _isMountedUnder(BuildContext ctx, String typeName) {
    var found = false;
    void walk(Element el) {
      if (found) return;
      if (el.widget.runtimeType.toString() == typeName) {
        found = true;
        return;
      }
      el.visitChildren(walk);
    }

    ctx.visitChildElements(walk);
    return found;
  }

  /// Mounts an ALREADY-BUILT [screen] for [t] under [shotId], settles, and
  /// returns whether the expected widget for [scene] is actually mounted inside
  /// the capture boundary (see [_expectedWidget]); true when no expectation is
  /// registered for the scene.
  ///
  /// Takes a PRE-BUILT widget rather than a scene number ON PURPOSE. Scene
  /// builders typically mutate shared app/provider state. An earlier version of
  /// this retry path re-invoked the builder, running those side effects a second
  /// time; that corrupted the seeded state and cascaded into the FOLLOWING
  /// target's shots (one failure at the end of one target was followed by five
  /// consecutive failures on the next). Build once per shot, mount as many times
  /// as needed.
  Future<bool> _mountAndVerify(
      Widget screen, int scene, _Target t, String shotId) async {
    setState(() {
      _target = t;
      _shotId = shotId;
      _shot = screen;
    });
    await _settle();
    final expected = _expectedWidgetFor(scene);
    if (expected == null) return true;
    // Poll rather than assume: see _mountTimeout. A screen that is still
    // fetching is not a wrong screen, it is a screen that has not arrived.
    final deadline = DateTime.now().add(_mountTimeout);
    var found = false;
    while (!found) {
      final ctx = _boundaryKey.currentContext;
      // No live boundary context means there is nothing to photograph; let
      // _capture()'s existing 'no boundary' skip path report that rather
      // than double-failing here.
      if (ctx == null || !ctx.mounted) return true;
      found = _isMountedUnder(ctx, expected);
      if (found || !DateTime.now().isBefore(deadline)) break;
      WidgetsBinding.instance.scheduleFrame();
      await _awaitFrame();
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    // Let the newly-arrived content finish laying out and painting before
    // the raster is taken, or the shot catches it mid-build.
    if (found) await _settle();
    if (!found) _dumpMountedScreens(shotId, expected);
    return found;
  }

  Future<void> _capture(_Target t, int scene) async {
    final rel = '${t.dir}/${t.prefix}${_sceneNames[scene]}.png';
    // Report against _currentShotId, NOT _shotId: _shotId carries the
    // '#blank'/'#retry' suffixes from the scene-mount guard, while
    // _currentShotId stays at the base id the error hook attributed to.
    try {
      final ro = _boundaryKey.currentContext?.findRenderObject();
      if (ro is! RenderRepaintBoundary) {
        _skipped.add('$_currentShotId: no boundary');
        return;
      }
      // pixelRatio turns the logical (w x h) into the store's exact pixel size.
      final image = await ro.toImage(pixelRatio: t.ratio);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (data == null) {
        _skipped.add('$_currentShotId: encode failed');
        return;
      }
      final path = '$_outRoot/$rel';
      await File(path).writeAsBytes(data.buffer.asUint8List());
      _written.add(path);
      // Record the authoritative manifest entry for this written shot.
      // `overflow` reflects whatever the FlutterError hook attributed to this
      // shot id during its layout/paint (empty => no overflow).
      final overflow = _overflowByShot[_currentShotId] ?? const <String>[];
      // `layout_errors` are assertion failures that leave a subtree UNPAINTED —
      // a shot can be pixel-perfect in size and still be blank.
      final layoutErrors =
          _layoutErrorsByShot[_currentShotId] ?? const <String>[];
      _manifestShots.add(<String, dynamic>{
        'file': rel,
        'store': t.store,
        'device': t.device,
        'dir': t.dir,
        'scene': scene,
        'expected_w': (t.w * t.ratio).round(),
        'expected_h': (t.h * t.ratio).round(),
        'overflow': overflow.isNotEmpty,
        'overflow_details': List<String>.from(overflow),
        'layout_error': layoutErrors.isNotEmpty,
        'layout_error_details': List<String>.from(layoutErrors),
      });
      // ignore: avoid_print
      print('CAPTURED $path');
    } catch (e, st) {
      _skipped.add('$_currentShotId: $e');
      stderr.writeln('SHOT_ERROR $_currentShotId: $e\n$st');
    }
  }

  /// Writes the AUTHORITATIVE capture manifest that scripts/validate_screenshots.py
  /// reads. `file` paths are relative to _outRoot; expected_w/h are the exact store
  /// pixel sizes (logical x ratio). skipped[] lists shots that never produced a PNG
  /// (the validator treats each as a MISSING screenshot / failure).
  ///
  /// A FULL run (no capture filters) writes exactly these keys and nothing more —
  /// unchanged from before selective capture existed. A PARTIAL run additionally
  /// MERGES the previous manifest in; see [_mergeIntoManifest].
  void _writeManifest(_CapturePlan plan) {
    final manifest = <String, dynamic>{
      'generated': DateTime.now().toUtc().toIso8601String(),
      'out_root': _outRoot,
      'shots': _manifestShots,
      'skipped': _skipped,
      'settle_timeouts': _settleTimeouts,
      'scene_retries': _sceneRetries,
      'scene_mismatches': _sceneMismatches,
    };
    const path = '$_outRoot/capture_manifest.json';
    if (plan.partial) _mergeIntoManifest(manifest, plan, path);
    File(path).writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(manifest));
    // ignore: avoid_print
    print('MANIFEST_WRITTEN: $path');
  }

  /// The shot id embedded at the start of a per-run report line. `settle_timeouts`
  /// entries are a bare shot id; `skipped` / `scene_retries` / `scene_mismatches`
  /// entries are `'<shotId>: <message>'`. Shot ids never contain ':'.
  String _shotIdOf(String entry) {
    final i = entry.indexOf(':');
    return (i < 0 ? entry : entry.substring(0, i)).trim();
  }

  Map<String, dynamic>? _readPreviousManifest(String path) {
    final f = File(path);
    if (!f.existsSync()) return null;
    try {
      final decoded = jsonDecode(f.readAsStringSync());
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (e) {
      // Do NOT swallow this. Merging on a corrupt manifest would silently drop
      // every previously-captured target, and the validator would then report
      // all of their PNGs as strays — the exact false failure this merge exists
      // to prevent.
      // ignore: avoid_print
      print('MANIFEST_MERGE_ERROR: cannot parse the existing manifest at '
          '$path ($e). Aborting rather than replacing the whole shipped set '
          "with this partial run's subset. Fix or delete it, or do a full run.");
      exit(2);
    }
  }

  /// MERGE a partial run into the existing manifest instead of replacing it.
  ///
  /// WHY: validate_screenshots.py enforces a BIJECTION between the manifest and
  /// the PNGs on disk. A partial run that simply rewrote the manifest with its
  /// own subset would turn every un-recaptured (and perfectly good) PNG into a
  /// [STRAY] failure. Merging keeps the invariant that a green validator means
  /// the WHOLE shipped set is good — the property that caught the blank-subtree
  /// and wrong-screen bugs.
  ///
  /// SEMANTICS (all four decisions are deliberate):
  ///  1. The merged shot set is exactly the CANONICAL set — every (target,scene)
  ///     the CURRENT [_targets] / [_sceneNames] tables can produce — sourced
  ///     from this run where captured and from the previous manifest otherwise,
  ///     in full-run order. So a partial manifest describes precisely what a
  ///     full run's would, and nothing else.
  ///  2. A carried-over entry whose PNG has since been DELETED from disk is
  ///     KEPT, so the validator reports [MISSING] and fails. Dropping it would
  ///     let a deleted shipped screenshot pass unnoticed. Also printed here.
  ///  3. A previous entry that is no longer canonical (a renamed/removed target,
  ///     a renamed scene) is DROPPED from the manifest and printed. Its PNG, if
  ///     still on disk, then shows up as a [STRAY] — exactly what a full run
  ///     would have done. No file is ever deleted by the harness.
  ///  4. `partial_run` reflects ONLY THE LATEST run, never an accumulation:
  ///     it answers "what was re-rendered just now", and the merged manifest
  ///     already asserts completeness of the whole set, so accumulating adds
  ///     nothing and would only decay into "some targets, some time". One step
  ///     of history is kept as `merged_from_generated`.
  /// A canonical shot with NEITHER a fresh capture NOR a previous entry is a
  /// HOLE: recorded in `merge_missing` and failed by the validator, because the
  /// shipped set really is incomplete.
  void _mergeIntoManifest(
      Map<String, dynamic> manifest, _CapturePlan plan, String path) {
    // The canonical set, in the order a full run writes it.
    final canonicalFiles = <String>[];
    final canonicalShotIds = <String>{};
    for (final t in _targets) {
      for (final scene in t.scenes) {
        canonicalFiles.add('${t.dir}/${t.prefix}${_sceneNames[scene]}.png');
        canonicalShotIds.add('${t.dir}/${t.prefix}${_sceneNames[scene]}');
      }
    }
    final canonicalSet = canonicalFiles.toSet();

    final freshFiles = <String>{
      for (final s in _manifestShots) s['file'] as String
    };
    final freshShotIds = <String>{
      for (final f in freshFiles)
        f.endsWith('.png') ? f.substring(0, f.length - 4) : f
    };

    final prev = _readPreviousManifest(path);
    final carried = <String, Map<String, dynamic>>{};
    final droppedStale = <String>[];
    final missingPng = <String>[];
    if (prev != null) {
      for (final raw in (prev['shots'] as List<dynamic>? ?? const [])) {
        if (raw is! Map) continue;
        final entry = Map<String, dynamic>.from(raw);
        final f = entry['file'];
        if (f is! String || carried.containsKey(f)) continue;
        if (freshFiles.contains(f)) continue; // this run supersedes it
        if (!canonicalSet.contains(f)) {
          droppedStale.add(f);
          continue;
        }
        carried[f] = entry;
        if (!File('$_outRoot/$f').existsSync()) missingPng.add(f);
      }
    } else {
      // ignore: avoid_print
      print('MANIFEST_MERGE: no existing manifest at $path — nothing to carry '
          'over, so this manifest describes ONLY this partial run and the '
          'validator will (correctly) report the rest of the set as missing.');
    }

    final byFile = <String, Map<String, dynamic>>{...carried};
    for (final s in _manifestShots) {
      byFile[s['file'] as String] = s;
    }
    final merged = <Map<String, dynamic>>[];
    final holes = <String>[];
    for (final f in canonicalFiles) {
      final e = byFile.remove(f);
      if (e != null) {
        merged.add(e);
      } else {
        holes.add(f);
      }
    }

    // The per-run report lists must survive a partial run too: a settle timeout
    // or a scene mismatch recorded against an un-recaptured target is still
    // true, and dropping it would let the validator go green on a shot that is
    // still bad on disk. This run's result SUPERSEDES the previous one for any
    // shot it re-captured.
    void mergeReportList(String key, List<String> mine) {
      final kept = <String>[];
      for (final e in (prev?[key] as List<dynamic>? ?? const [])) {
        if (e is! String) continue;
        final id = _shotIdOf(e);
        if (freshShotIds.contains(id)) continue; // re-captured: fresh wins
        if (!canonicalShotIds.contains(id)) continue; // stale target/scene
        if (mine.contains(e) || kept.contains(e)) continue;
        kept.add(e);
      }
      manifest[key] = <String>[...kept, ...mine];
    }

    mergeReportList('skipped', _skipped);
    mergeReportList('settle_timeouts', _settleTimeouts);
    mergeReportList('scene_retries', _sceneRetries);
    mergeReportList('scene_mismatches', _sceneMismatches);

    manifest['shots'] = merged;
    manifest['partial_run'] =
        plan.selected.map((p) => '${p.t.store}/${p.t.device}').toList();
    manifest['partial_run_filters'] = <String, String>{
      'CAPTURE_TARGETS': _captureTargetsFilter,
      'CAPTURE_SCENES': _captureScenesFilter,
    };
    manifest['partial_run_shots'] = freshFiles.toList()..sort();
    manifest['partial_run_skipped'] = plan.skipped;
    manifest['carried_over'] = carried.length;
    manifest['merged_from_generated'] = prev?['generated'];
    manifest['merge_missing'] = holes;

    if (droppedStale.isNotEmpty) {
      // ignore: avoid_print
      print('MANIFEST_MERGE_DROPPED_STALE (no current target/scene produces '
          'these, so their old manifest entries were NOT carried over; any PNG '
          'still on disk will be reported as [STRAY] — delete it or restore the '
          'target): ${droppedStale.join(' | ')}');
    }
    if (missingPng.isNotEmpty) {
      // ignore: avoid_print
      print('MANIFEST_MERGE_MISSING_PNG (carried-over entry but no PNG on disk '
          '— kept on purpose so the validator FAILS it): '
          '${missingPng.join(' | ')}');
    }
    if (holes.isNotEmpty) {
      // ignore: avoid_print
      print('MANIFEST_MERGE_HOLES (never captured and no previous entry — the '
          'shipped set is INCOMPLETE): ${holes.join(' | ')}');
    }
    // ignore: avoid_print
    print('MANIFEST_MERGED: ${_manifestShots.length} fresh + '
        '${carried.length} carried over = ${merged.length} of '
        '${canonicalFiles.length} canonical shot(s)');
  }

  /// Awaits the next frame, but never blocks longer than [_frameWaitTimeout] —
  /// see that constant for why a bare `endOfFrame` can hang an entire run.
  /// EVERY `endOfFrame` in this file must go through here.
  Future<void> _awaitFrame() => WidgetsBinding.instance.endOfFrame
      .timeout(_frameWaitTimeout, onTimeout: () {});

  /// Pumps frames until nothing is ANIMATING, so async-decoded content (SVGs,
  /// web/async fonts, images) and post-frame callbacks complete — and no shot is
  /// rasterized mid entrance-animation — before we rasterize.
  ///
  /// A running AnimationController drives a ticker, which registers a transient
  /// frame callback, so `transientCallbackCount == 0` means the tree is visually
  /// at rest. This replaced a FIXED ~770ms wait that *raced* entrance
  /// animations: big targets took long enough to rasterize that they landed
  /// after the animation, but small phone targets rendered fast enough to beat
  /// it and captured a faded-out, near-blank frame.
  ///
  /// A screen animating on a `repeat()` loop never reaches rest — [_settleTimeout]
  /// is the safety net, and each timeout is recorded so the validator flags the
  /// shot rather than silently shipping a mid-animation frame.
  Future<void> _settle() async {
    // Minimum pump: lets first-frame post-frame callbacks register their
    // tickers, so we never sample the count before any animation has started.
    for (var i = 0; i < 6; i++) {
      await _awaitFrame();
      await Future<void>.delayed(const Duration(milliseconds: 70));
    }

    final deadline = DateTime.now().add(_settleTimeout);
    var quietFrames = 0;
    while (quietFrames < _quietFramesRequired) {
      if (!DateTime.now().isBefore(deadline)) {
        _settleTimeouts.add(_currentShotId);
        break;
      }
      // An idle tree schedules no frames on its own, so ask for one; otherwise
      // `endOfFrame` would wait forever once everything has settled.
      WidgetsBinding.instance.scheduleFrame();
      await _awaitFrame();
      // Require CONSECUTIVE quiet frames so a controller that chains into
      // another is not mistaken for a fully settled tree.
      quietFrames = WidgetsBinding.instance.transientCallbackCount == 0
          ? quietFrames + 1
          : 0;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }

    // Final breather for async decode work already scheduled above. Tune upward
    // if the app streams content in.
    await Future<void>.delayed(const Duration(milliseconds: 350));
  }

  @override
  Widget build(BuildContext context) {
    final shot = _shot;
    // OverflowBox lets the child take the full
    // logical target size even though the host window may be smaller; the inner
    // MediaQuery makes the tree BELIEVE it is on a size==(w,h) device at the
    // target devicePixelRatio; the RepaintBoundary at a fixed SizedBox(w,h) is
    // exactly what _capture() rasterizes.
    return KeyedSubtree(
      // Fresh ValueKey(_shotId) => the whole scene subtree remounts for every
      // shot, so no state bleeds between scenes.
      key: ValueKey(_shotId),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: ColoredBox(
          color: const Color(0xFF000000),
          child: shot == null
              ? const SizedBox.shrink()
              : Center(
                  child: OverflowBox(
                    alignment: Alignment.topLeft,
                    minWidth: _target.w,
                    maxWidth: _target.w,
                    minHeight: _target.h,
                    maxHeight: _target.h,
                    child: MediaQuery(
                      data: MediaQueryData(
                        size: Size(_target.w, _target.h),
                        devicePixelRatio: _target.ratio,
                      ),
                      child: RepaintBoundary(
                        key: _boundaryKey,
                        child: SizedBox(
                            width: _target.w, height: _target.h, child: shot),
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
