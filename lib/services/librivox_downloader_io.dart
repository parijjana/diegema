import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:dart_rss/dart_rss.dart';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import '../core/network/user_agent.dart';
import '../domain/models/librivox_book.dart';
import '../domain/models/audiobook.dart';

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
    final sanitizeName =
        book.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    final bookDir = Directory(p.join(saveDirectoryPath, sanitizeName));
    if (!await bookDir.exists()) {
      await bookDir.create(recursive: true);
    }

    final zipFilePath = p.join(bookDir.path, 'package.zip');
    final request = http.Request('GET', Uri.parse(book.urlZipFile));
    request.headers.addAll(_headers);
    final response = await _client.send(request);

    if (response.statusCode != 200) {
      throw Exception('ZIP download failed with status ${response.statusCode}');
    }

    final totalBytes = response.contentLength ?? 0;
    int receivedBytes = 0;
    final List<int> bytes = [];

    await for (final chunk in response.stream) {
      bytes.addAll(chunk);
      receivedBytes += chunk.length;
      if (totalBytes > 0 && onProgress != null) {
        onProgress(receivedBytes / totalBytes);
      }
    }

    final zipFile = File(zipFilePath);
    await zipFile.writeAsBytes(bytes);

    final zipBytes = zipFile.readAsBytesSync();
    final archive = ZipDecoder().decodeBytes(zipBytes);

    final List<String> extractedMp3s = [];
    for (final file in archive) {
      final filename = file.name;
      if (file.isFile) {
        final data = file.content as List<int>;
        final filePath = p.join(bookDir.path, filename);
        final outFile = File(filePath);
        await outFile.create(recursive: true);
        await outFile.writeAsBytes(data);
        if (filename.toLowerCase().endsWith('.mp3')) {
          extractedMp3s.add(filePath);
        }
      }
    }

    await zipFile.delete();
    extractedMp3s.sort();
    return extractedMp3s;
  }
}
