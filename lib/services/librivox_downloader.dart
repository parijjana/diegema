/// Platform seam for [LibriVoxStreamAndDownloader].
///
/// The native implementation (`librivox_downloader_io.dart`) streams a
/// LibriVox ZIP to disk and extracts it with `dart:io` `File`/`Directory`.
/// That does not compile for web at all. The web implementation
/// (`librivox_downloader_web.dart`) keeps the same public API — chapter
/// list parsing works identically since it is plain `http` + XML — but its
/// `downloadAndExtractZip` throws, since the canned web demo never offers a
/// full-book ZIP download (rework_plan.md: "the demo is explicitly
/// streaming-only").
library;

export 'librivox_downloader_io.dart'
    if (dart.library.html) 'librivox_downloader_web.dart';
