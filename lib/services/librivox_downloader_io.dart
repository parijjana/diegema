import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:dart_rss/dart_rss.dart';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import '../core/network/user_agent.dart';
import '../core/utils/book_identity.dart';
import '../domain/models/librivox_book.dart';
import '../domain/models/audiobook.dart';
import 'chapters_unavailable.dart';

class LibriVoxStreamAndDownloader {
  final http.Client _client;

  static const Map<String, String> _headers = {
    'User-Agent': kHttpUserAgent,
    'Accept': '*/*',
  };

  LibriVoxStreamAndDownloader({http.Client? client})
      : _client = client ?? http.Client();

  Future<UnifiedAudiobook> parseStreamableBook(LibriVoxBook book) async {
    // Canonical id: the archive.org identifier, not the LibriVox API id —
    // see core/utils/book_identity.dart. This is also what
    // `downloadAndExtractZip`'s caller (BookDetailPane) must reuse when
    // saving the downloaded copy, so streaming and downloading the same
    // book resolve to the same database row instead of two.
    final canonicalId = BookIdentity.archiveIdentifierFor(
      librivoxApiId: book.id,
      urlIarchive: book.urlIarchive,
    );
    final List<AudiobookChapter> chapters = [];

    if (book.urlRss.isNotEmpty) {
      try {
        final response = await _client
            .get(Uri.parse(book.urlRss), headers: _headers)
            // LibriVox's feeds routinely take 12-17 s to answer.
            .timeout(const Duration(seconds: 45));
        if (response.statusCode != 200) {
          throw ChaptersUnavailable('HTTP ${response.statusCode}');
        }
        final rss = RssFeed.parse(response.body);
        int index = 0;
        for (final item in rss.items) {
          final streamUrl = item.enclosure?.url;
          if (streamUrl == null) continue;

          final durationSecs = item.itunes?.duration?.inSeconds ?? 0;
          final trackTitle = item.title ?? 'Section ${index + 1}';

          chapters.add(
            AudiobookChapter(
              id: '${canonicalId}_stream_$index',
              title: trackTitle,
              audioPathOrUrl: streamUrl,
              durationSeconds: durationSecs,
              isStream: true,
            ),
          );
          index++;
        }
      } on ChaptersUnavailable {
        rethrow;
      } catch (e) {
        throw ChaptersUnavailable('$e');
      }
    }

    return UnifiedAudiobook(
      id: canonicalId,
      title: book.title,
      author: book.authorNames,
      description: book.description,
      source: 'LibriVox',
      origin: BookIdentity.originLibrivox,
      narrators: book.narrators,
      chapters: chapters,
      isDownloaded: false,
    );
  }

  /// No bytes for this long mid-download means the connection is dead.
  static const Duration _stallTimeout = Duration(seconds: 60);
  static const Duration _connectTimeout = Duration(seconds: 30);

  /// Downloads [book]'s ZIP to a temp folder and extracts its `.mp3`s into
  /// `<saveDirectoryPath>/<title> [<id>]/`, returning their paths in name
  /// order. Nothing else is extracted: Android's shared Audiobooks folder
  /// accepts only audio, and nothing but the audio is ever used.
  ///
  /// Built for books of hundreds of MB on a phone: the ZIP streams straight
  /// to disk and is extracted one entry at a time, so memory stays flat.
  /// An entry whose path would land outside the book folder (`../…`,
  /// absolute paths, symlinks) is skipped. On any failure — network drop,
  /// stall, disk full, corrupt ZIP — the partial ZIP and every file this
  /// call extracted are deleted before the error is rethrown.
  Future<List<String>> downloadAndExtractZip(
    LibriVoxBook book, {
    required String saveDirectoryPath,
    void Function(double progress)? onProgress,
  }) async {
    final identifier = BookIdentity.archiveIdentifierFor(
        librivoxApiId: book.id, urlIarchive: book.urlIarchive);
    final bookDir = Directory(
        p.join(saveDirectoryPath, bookFolderName(book.title, identifier)));

    final tempDir = await Directory.systemTemp.createTemp('diegema-zip');
    final zipFile = File(p.join(tempDir.path, 'package.zip'));
    try {
      await _downloadTo(zipFile, Uri.parse(book.urlZipFile), onProgress);
      return await extractAudioFromZip(zipFile, bookDir);
    } finally {
      try {
        await tempDir.delete(recursive: true);
      } on FileSystemException {
        // Best effort: the OS clears its temp folder eventually.
      }
    }
  }

  Future<void> _downloadTo(
      File target, Uri url, void Function(double progress)? onProgress) async {
    final request = http.Request('GET', url)..headers.addAll(_headers);
    final response = await _client.send(request).timeout(_connectTimeout);
    if (response.statusCode != 200) {
      throw HttpException(
          'ZIP download failed with status ${response.statusCode}',
          uri: url);
    }

    final totalBytes = response.contentLength ?? 0;
    var receivedBytes = 0;
    final sink = target.openWrite();
    try {
      await for (final chunk in response.stream.timeout(_stallTimeout)) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0 && onProgress != null) {
          onProgress(receivedBytes / totalBytes);
        }
      }
      await sink.flush();
    } finally {
      await sink.close();
    }
    if (totalBytes > 0 && receivedBytes != totalBytes) {
      throw HttpException(
          'ZIP download ended early ($receivedBytes of $totalBytes bytes)',
          uri: url);
    }
  }
}

/// The folder a downloaded book's files go in, under the downloads root:
/// its title for people browsing the folder, and its archive.org id so two
/// editions with the same title never share (and overwrite, or on removal
/// delete) one folder.
String bookFolderName(String title, String identifier) {
  final name = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
  final id = identifier.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  return '$name [$id]';
}

/// Extracts [zip]'s `.mp3`s into [bookDir], returning their paths in name
/// order. Nothing else is extracted: Android's shared Audiobooks folder
/// accepts only audio, and nothing but the audio is ever used.
///
/// Extracts one entry at a time, so memory stays flat for books of
/// hundreds of MB. An entry whose path would land outside the book folder
/// (`../…`, absolute paths, symlinks) is skipped. On any failure — disk
/// full, corrupt ZIP, a ZIP with no audio — every file this call extracted
/// is deleted before the error is rethrown. The ZIP itself is the caller's.
Future<List<String>> extractAudioFromZip(File zip, Directory bookDir) async {
  await bookDir.create(recursive: true);
  final written = <File>[];
  try {
    final mp3s = await _extractInto(zip, bookDir, written);
    // A corrupt or truncated ZIP decodes as an empty archive, not an
    // error; a "download" with no audio must not become a book.
    if (mp3s.isEmpty) {
      throw const FormatException('The download held no audio files');
    }
    mp3s.sort();
    return mp3s;
  } catch (_) {
    for (final file in written) {
      await _deleteQuietly(file);
    }
    rethrow;
  }
}

/// Extracts [zip] into [dir] entry by entry. Every file written is added
/// to [written] as it is created, so the caller can clean up a failure.
Future<List<String>> _extractInto(
    File zip, Directory dir, List<File> written) async {
  final root = p.canonicalize(dir.path);
  final input = InputFileStream(zip.path);
  try {
    final archive = ZipDecoder().decodeStream(input);
    final mp3s = <String>[];
    for (final entry in archive) {
      if (!entry.isFile || entry.isSymbolicLink) continue;
      if (!entry.name.toLowerCase().endsWith('.mp3')) continue;
      final target = p.normalize(p.join(dir.path, entry.name));
      // canonicalize lowercases on Windows, so it is for the check only:
      // the stored chapter path keeps the folder's real case.
      if (!p.isWithin(root, p.canonicalize(target))) continue; // zip-slip
      await Directory(p.dirname(target)).create(recursive: true);
      final out = OutputFileStream(target);
      written.add(File(target));
      try {
        entry.writeContent(out);
      } finally {
        await out.close();
      }
      mp3s.add(target);
    }
    return mp3s;
  } finally {
    await input.close();
  }
}

Future<void> _deleteQuietly(File file) async {
  try {
    if (await file.exists()) await file.delete();
  } on FileSystemException {
    // Best effort: a leftover file is better than masking the real error.
  }
}
