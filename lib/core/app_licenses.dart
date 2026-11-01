import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Registers licence texts that Flutter's automatic package scan cannot
/// find, so they appear on the app's licences page (Settings, About).
/// Store-compliance audit S-04. Call once in `main()` after the binding is
/// initialised.
void registerAppLicenses() {
  LicenseRegistry.addLicense(_interLicense);
  if (!kIsWeb && Platform.isWindows) {
    LicenseRegistry.addLicense(_windowsNativeLicenses);
  }
}

/// Inter (SIL OFL 1.1). The licence text must be distributed with the font.
Stream<LicenseEntry> _interLicense() async* {
  final text = await rootBundle.loadString('assets/fonts/OFL.txt');
  yield LicenseEntryWithLineBreaks(['Inter typeface'], text);
}

/// mpv and FFmpeg ship inside libmpv-2.dll on Windows (via the
/// media_kit_libs_windows_audio package). Licence read from the DLL itself:
/// mpv-configuration has -Dgpl=false; FFmpeg was configured with
/// --disable-gpl --disable-nonfree --enable-version3 and reports "LGPL version
/// 3 or later". Re-check if the media_kit_libs_windows_audio version changes.
Stream<LicenseEntry> _windowsNativeLicenses() async* {
  final lgpl = await rootBundle.loadString('assets/licenses/lgpl-3.0.txt');
  final gpl = await rootBundle.loadString('assets/licenses/gpl-3.0.txt');
  yield LicenseEntryWithLineBreaks(['mpv', 'FFmpeg (Windows build)'], '''
On Windows, Diegema plays audio with libmpv (mpv 0.36.0-403-g652a1dd907,
https://mpv.io) and FFmpeg (n6.0, https://ffmpeg.org), supplied as libmpv-2.dll
by the media_kit libs for Windows, build mpv-dev-x86_64-20230924-git-652a1dd.

This build of FFmpeg is licensed under the GNU Lesser General Public License
version 3 or later. This build of mpv was made without GPL parts and is licensed
under the GNU Lesser General Public License version 2.1 or later. Both are
provided here under LGPL version 3, whose text and the GNU General Public License
version 3 it builds on follow below. libmpv-2.dll is a separate file in the app
folder. The DLL also includes third-party libraries under their own licences;
the build recipe lists them.

Source code and build recipe:
  https://github.com/media-kit/libmpv-win32-audio-build
  https://github.com/mpv-player/mpv/tree/652a1dd907
  https://ffmpeg.org/download.html
Diegema's own source code: https://github.com/parijjana/diegema

$lgpl

$gpl''');
  yield const LicenseEntryWithLineBreaks(['Mozilla CA root certificates'], '''
On Windows, Diegema checks HTTPS connections for audio streaming against the
Mozilla root certificate list, as published at https://curl.se/docs/caextract.html
(data/cacert.pem in the app folder). It is licensed under the Mozilla Public
License 2.0, https://www.mozilla.org/MPL/2.0/.
''');
}
