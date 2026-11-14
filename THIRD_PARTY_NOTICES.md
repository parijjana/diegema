# Third-party notices: libmpv-2.dll (Windows)

On Windows Diegema plays audio through `libmpv-2.dll`, fetched at build time by
`media_kit_libs_windows_audio` 1.0.9 (`windows/CMakeLists.txt` of that package):

- Archive: `mpv-dev-x86_64-20230924-git-652a1dd.7z`, 5,392,413 bytes
- URL: https://github.com/media-kit/libmpv-win32-audio-build/releases/download/2023-09-24/mpv-dev-x86_64-20230924-git-652a1dd.7z
- MD5 pinned by the package: `cd738e16e2a19626d7cfa48801524f8c`
- Build recipe (tag `2023-09-24`, commit `f0f6ac7483396f345820660176cc84e2dd6ba220`):
  https://github.com/media-kit/libmpv-win32-audio-build (`packages/ffmpeg.cmake`, `packages/mpv.cmake`;
  the repository is archived but public)
- mpv 0.36.0-403-g652a1dd907 (https://github.com/mpv-player/mpv); FFmpeg commit
  `ea3d24bbe3c58b171e55fe2151fc7ffaca3ab3d2` (reports n6.0).

The DLL was not unpacked or scanned to write this page: the list below is derived from the upstream
build recipe's configure flags and dependency lists. Where the recipe names a library as a
dependency, the licence is the upstream project's; whether each one ended up statically linked in
this particular 2023 binary is stated as "recipe" (declared) or "enabled" (explicit configure flag).
To verify, unpack the archive in a scratch folder and inspect strings and imports of the DLL.

## Licence of the combination

mpv built with `-Dgpl=false`; FFmpeg configured `--disable-gpl --disable-nonfree --enable-version3`
(LGPL v3 or later). The DLL is a separate file in the app folder, so it can be replaced. LGPL v3 and
GPL v3 texts ship in `assets/licenses/` and on the in-app licences page (`lib/core/app_licenses.dart`).

## Components

| Component | Role in the build | Licence | Evidence |
|---|---|---|---|
| mpv / libmpv | player core | LGPL-2.1+ (gpl=false build) | enabled (`-Dgpl=false`) |
| FFmpeg: libavutil, libavcodec, libavformat, libavfilter, libavdevice, libswscale, libswresample | demux/decode (selected audio/image decoders, demuxers, protocols incl. http/https/hls/tcp/tls) | LGPL-3.0+ | enabled (`--enable-version3 --disable-gpl`) |
| Mbed TLS | HTTPS/TLS for FFmpeg | Apache-2.0 OR GPL-2.0+ (used under Apache-2.0) | enabled (`--enable-mbedtls`) |
| libass | subtitle rendering (mpv dependency) | ISC | recipe |
| FriBidi | bidi text (mpv) | LGPL-2.1+ | recipe |
| Little CMS 2 (lcms2) | colour management (mpv) | MIT | enabled (`-Dlcms2=enabled`) |
| libarchive | archive input (mpv) | BSD-2-Clause | enabled (`-Dlibarchive=enabled`) |
| libjpeg(-turbo) | JPEG cover/image decode (mpv) | BSD-3-Clause / IJG / zlib | recipe |
| libpng | PNG decode | libpng licence | recipe |
| uchardet | charset detection (mpv) | MPL-1.1 / GPL-2.0+ / LGPL-2.1+ (used under MPL-1.1) | recipe |
| OpenAL Soft | audio output option (mpv) | LGPL-2.0+ | enabled (`-Dopenal=enabled`) |
| MuJS | JavaScript for mpv scripts | ISC | enabled (`-Djavascript=enabled`) |
| libplacebo | video rendering (mpv dependency) | LGPL-2.1+ | recipe |
| FreeType, HarfBuzz, Fontconfig, Expat, zlib, Brotli | text/fonts stack under libass | FTL or GPL-2.0, MIT, MIT-style, MIT, zlib, MIT | recipe (transitive) |
| libsoxr, zimg, libmysofa, libwebp, Opus, Speex, Vorbis/Ogg, libxml2, libvpl, LAME, bzip2 | listed as FFmpeg build dependencies | LGPL-2.1+, WTFPL-2.0 (zimg), BSD-3-Clause, BSD-3-Clause, BSD-3-Clause, BSD-3-Clause, BSD-3-Clause, MIT, MIT, LGPL-2.0+, bzip2 licence | recipe only: the configure line has no `--enable-lib*` flag for them, so they are probably NOT linked into FFmpeg here |

Not used by this recipe's FFmpeg configure line and therefore not listed: x264/x265 (GPL), fdk-aac
(non-free), libsrt (protocol named but no `--enable-libsrt`).

## Notes for maintainers

- The package pins the archive by MD5 only (audit S-18). Record the SHA-256 of the DLL you ship in the
  release notes.
- Re-do this page whenever `media_kit_libs_windows_audio` changes its `LIBMPV` archive.
- Mozilla CA bundle (`windows/tls/cacert.pem`, MPL-2.0, from https://curl.se/docs/caextract.html) is
  credited separately on the licences page.
