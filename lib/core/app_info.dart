import 'package:package_info_plus/package_info_plus.dart';

/// Identity shown in the About section of the settings panel.
///
/// ⚠️ **Diegema is a WORKING title, not the settled name.** The intent
/// (owner, 2026-08-14) is to let the LibriVox community choose the real one
/// if they are receptive to the project — so this will very likely change,
/// and changing it should stay a one-line edit here plus `MaterialApp.title`
/// in `app.dart`.
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
