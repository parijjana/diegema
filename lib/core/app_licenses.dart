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
/// media_kit_libs_windows_audio package). Their licence is LGPL-2.1+ or
/// GPL-2+/3 depending on how the DLL was built.
///
/// TODO(S-04, owner, on the Windows PC): determine the licence variant of
/// the bundled libmpv-2.dll (look for --enable-gpl / --enable-version3 /
/// -Dgpl in `strings libmpv-2.dll`; see project_docs/diegema/WINDOWS_BUILD.md)
/// and replace the generic wording below with the exact licence, its full
/// text, and the exact source version. Do not assume LGPL.
Stream<LicenseEntry> _windowsNativeLicenses() async* {
  yield const LicenseEntryWithLineBreaks(
      ['mpv', 'FFmpeg (Windows build)'], '''
On Windows, Diegema plays audio with libmpv (mpv, https://mpv.io) and FFmpeg
(https://ffmpeg.org), supplied as libmpv-2.dll by the media_kit libs for
Windows (https://github.com/media-kit/libmpv-win32-audio-build, build
mpv-dev-x86_64-20230924-git-652a1dd).

mpv and FFmpeg are free software licensed under the GNU Lesser General Public
License (LGPL) version 2.1 or later, or, when built with GPL components, the
GNU General Public License (GPL). The exact licence of the bundled build has
not yet been confirmed.

Licence texts:
  https://www.gnu.org/licenses/old-licenses/lgpl-2.1.html
  https://www.gnu.org/licenses/gpl-2.0.html
  https://www.gnu.org/licenses/gpl-3.0.html

Source code for mpv and FFmpeg is available at
https://github.com/mpv-player/mpv and https://ffmpeg.org/download.html.
Diegema's own source code is public at https://github.com/parijjana/diegema.
''');
}
