import 'package:http/http.dart' as http;
import 'package:dart_rss/dart_rss.dart';
import '../core/network/user_agent.dart';
import '../domain/models/librivox_book.dart';
import '../domain/models/audiobook.dart';

/// Web counterpart of `librivox_downloader_io.dart`. Chapter-list parsing
/// is identical (plain `http` + RSS XML parsing, no `dart:io` involved);
/// only ZIP download/extraction differs, since that requires writing to a
/// local filesystem the browser sandbox does not expose. In the web demo,
/// this method is never reached — `BookDetailPane` hides the download
/// button in demo mode — but it throws rather than silently no-oping so a
/// stray call fails loudly instead of pretending to succeed.
class LibriVoxStreamAndDownloader {
  final http.Client _client;

  static const Map<String, String> _headers = {
    'User-Agent': kHttpUserAgent,
    'Accept': '*/*',
  };

  LibriVoxStreamAndDownloader({http.Client? client})
      : _client = client ?? http.Client();

  Future<UnifiedAudiobook> parseStreamableBook(LibriVoxBook book) async {
    final List<AudiobookChapter> chapters = [];

    if (book.urlRss.isNotEmpty) {
      try {
        final response =
            await _client.get(Uri.parse(book.urlRss), headers: _headers);
        if (response.statusCode == 200) {
          final rss = RssFeed.parse(response.body);
          int index = 0;
          for (final item in rss.items) {
            final streamUrl = item.enclosure?.url;
            if (streamUrl == null) continue;

            final durationSecs = item.itunes?.duration?.inSeconds ?? 0;
            final trackTitle = item.title ?? 'Section ${index + 1}';

            chapters.add(
              AudiobookChapter(
                id: '${book.id}_stream_$index',
                title: trackTitle,
                audioPathOrUrl: streamUrl,
                durationSeconds: durationSecs,
                isStream: true,
              ),
            );
            index++;
          }
        }
      } catch (_) {}
    }

    return UnifiedAudiobook(
      id: book.id,
      title: book.title,
      author: book.authorNames,
      description: book.description,
      source: 'LibriVox',
      narrators: book.narrators,
      chapters: chapters,
      isDownloaded: false,
    );
  }

  Future<List<String>> downloadAndExtractZip(
    LibriVoxBook book, {
    required String saveDirectoryPath,
    void Function(double progress)? onProgress,
  }) async {
    throw UnsupportedError(
      'Full-book ZIP download is not available in the web demo — it is '
      'streaming-only. Use the desktop app to download books.',
    );
  }
}
