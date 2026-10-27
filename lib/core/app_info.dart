import 'package:package_info_plus/package_info_plus.dart';

/// Identity shown in the About section of the settings panel.
///
/// **Diegema is the app's name** on every platform and store (settled for
/// v1; it was a working title from 2026-08-14 until the store listings).
/// The native display names (Android label, iOS/macOS bundle name, Windows
/// Runner.rc and window title, web manifest, MSIX `display_name`) are set
/// separately and must stay in step with this.
///
/// Greek *διήγημα*, "a narrative" — the root of *diegesis*. Chosen partly
/// because it was clear across the App Store, Play, GitHub, npm and the
/// obvious domains on 2026-08-14, which the previous candidate (Fabulae)
/// was not: *Fabula* and *Fabuly* are both existing audiobook apps.
const String kAppName = 'Diegema';

/// Shown until (or if) the real version cannot be read — in widget tests,
/// where there is no platform channel, and on any platform where the lookup
/// fails. Keep in step with `version:` in `pubspec.yaml`.
const String kFallbackAppVersion = '1.0.0';

Future<String>? _appVersion;

/// The `version:` from `pubspec.yaml` as built into the app, read once via
/// `package_info_plus`. Never throws: a failed lookup (no platform channel
/// under `flutter test`) yields [kFallbackAppVersion].
Future<String> loadAppVersion() => _appVersion ??= () async {
      try {
        return (await PackageInfo.fromPlatform()).version;
      } catch (_) {
        return kFallbackAppVersion;
      }
    }();
