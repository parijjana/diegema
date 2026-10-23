import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:diegema/domain/models/librivox_book.dart';
import 'package:diegema/services/librivox_downloader_io.dart';

LibriVoxBook _book() => LibriVoxBook(
      id: '1',
      title: 'Emma',
      description: '',
      totalTimeSecs: 0,
      authors: const [],
      urlRss: '',
      urlZipFile: 'https://archive.org/download/emma/emma.zip',
      language: 'English',
      narrators: const [],
    );

List<int> _zip(Map<String, List<int>> entries) {
  final archive = Archive();
  entries.forEach(
      (name, bytes) => archive.addFile(ArchiveFile.bytes(name, bytes)));
  return ZipEncoder().encode(archive);
}

/// Serves [body] in 1 KB chunks, optionally failing after [failAfter] bytes.
MockClient _serve(List<int> body, {int? failAfter, int? claimedLength}) =>
    MockClient.streaming((request, _) async {
      final controller = StreamController<List<int>>();
      unawaited(() async {
        for (var i = 0; i < body.length; i += 1024) {
          if (failAfter != null && i >= failAfter) {
            controller.addError(const SocketException('connection reset'));
            break;
          }
          controller.add(body.sublist(i, (i + 1024).clamp(0, body.length)));
          await Future<void>.delayed(Duration.zero);
        }
        await controller.close();
      }());
      return http.StreamedResponse(controller.stream, 200,
          contentLength: claimedLength ?? body.length);
    });

void main() {
  late Directory root;
  late String downloads;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('zip_download');
    downloads = p.join(root.path, 'downloads');
  });

  tearDown(() => root.delete(recursive: true));

  List<String> filesUnder(String dir) => Directory(dir).existsSync()
      ? Directory(dir)
          .listSync(recursive: true)
          .whereType<File>()
          .map((f) => p.relative(f.path, from: dir))
          .toList()
      : [];

  test('extracts only the mp3s, in name order, and leaves no zip', () async {
    final body = _zip({
      '02.mp3': List.filled(3000, 2),
      '01.mp3': List.filled(3000, 1),
      'notes.txt': [1],
    });
    final progress = <double>[];
    final paths = await LibriVoxStreamAndDownloader(client: _serve(body))
        .downloadAndExtractZip(_book(),
            saveDirectoryPath: downloads, onProgress: progress.add);

    expect(paths.map(p.basename), ['01.mp3', '02.mp3']);
    expect(File(paths.first).lengthSync(), 3000);
    expect(
        filesUnder(downloads)..sort(), ['Emma [1]/01.mp3', 'Emma [1]/02.mp3']);
    expect(progress.last, 1.0);
  });

  test('entries that escape the book folder are never written (zip-slip)',
      () async {
    final body = _zip({
      '01.mp3': [1],
      '../escaped.mp3': [6],
      '../../outside.txt': [6],
    });
    await LibriVoxStreamAndDownloader(client: _serve(body))
        .downloadAndExtractZip(_book(), saveDirectoryPath: downloads);

    expect(filesUnder(root.path), ['downloads/Emma [1]/01.mp3']);
  });

  test('a dropped connection leaves no partial zip behind', () async {
    final noise = Random(1);
    final body =
        _zip({'01.mp3': List.generate(20000, (_) => noise.nextInt(256))});
    final downloader =
        LibriVoxStreamAndDownloader(client: _serve(body, failAfter: 4096));

    await expectLater(
        downloader.downloadAndExtractZip(_book(), saveDirectoryPath: downloads),
        throwsA(isA<SocketException>()));
    expect(filesUnder(downloads), isEmpty);
  });

  test('a download shorter than announced fails and cleans up', () async {
    final body = _zip({'01.mp3': List.filled(5000, 1)});
    final downloader = LibriVoxStreamAndDownloader(
        client: _serve(body, claimedLength: body.length + 500));

    await expectLater(
        downloader.downloadAndExtractZip(_book(), saveDirectoryPath: downloads),
        throwsA(isA<HttpException>()));
    expect(filesUnder(downloads), isEmpty);
  });

  test('a corrupt zip fails without leaving files', () async {
    final downloader =
        LibriVoxStreamAndDownloader(client: _serve(List.filled(4000, 7)));

    await expectLater(
        downloader.downloadAndExtractZip(_book(), saveDirectoryPath: downloads),
        throwsA(isA<FormatException>()));
    expect(filesUnder(downloads), isEmpty);
  });

  test('two books with the same title download to separate folders', () async {
    final body = _zip({
      '01.mp3': [1]
    });
    final downloader = LibriVoxStreamAndDownloader(client: _serve(body));
    final other = LibriVoxBook(
      id: '2',
      title: 'Emma',
      description: '',
      totalTimeSecs: 0,
      authors: const [],
      urlRss: '',
      urlZipFile: 'https://archive.org/download/emma2/emma2.zip',
      urlIarchive: 'https://archive.org/details/emma_2_librivox',
      language: 'English',
      narrators: const [],
    );

    final a = await downloader.downloadAndExtractZip(_book(),
        saveDirectoryPath: downloads);
    final b = await downloader.downloadAndExtractZip(other,
        saveDirectoryPath: downloads);

    expect(p.dirname(a.single), isNot(p.dirname(b.single)));
  });

  test('a non-200 response throws', () async {
    final downloader = LibriVoxStreamAndDownloader(
        client: MockClient((_) async => http.Response('gone', 404)));

    await expectLater(
        downloader.downloadAndExtractZip(_book(), saveDirectoryPath: downloads),
        throwsA(isA<HttpException>()));
  });

  group('extractAudioFromZip (the download manager\'s half)', () {
    test('extracts only mp3s, in order, and leaves the zip to the caller',
        () async {
      final zip = File(p.join(root.path, 'book.zip'))
        ..writeAsBytesSync(_zip({
          '02.mp3': [2],
          '01.mp3': [1],
          'cover.jpg': [9],
          '../escape.mp3': [6],
        }));
      final files = await extractAudioFromZip(
          zip, Directory(p.join(downloads, bookFolderName('Emma', 'emma_x'))));

      expect(files.map(p.basename), ['01.mp3', '02.mp3']);
      expect(
          filesUnder(downloads)..sort(),
          [
            p.join('Emma [emma_x]', '01.mp3'),
            p.join('Emma [emma_x]', '02.mp3'),
          ]..sort());
      expect(zip.existsSync(), isTrue);
      expect(File(p.join(root.path, 'escape.mp3')).existsSync(), isFalse);
    });

    test('a zip with no audio fails and writes nothing', () async {
      final zip = File(p.join(root.path, 'book.zip'))
        ..writeAsBytesSync(_zip({
          'notes.txt': [1]
        }));
      await expectLater(
          extractAudioFromZip(zip, Directory(p.join(downloads, 'x'))),
          throwsA(isA<FormatException>()));
      expect(filesUnder(downloads), isEmpty);
    });

    test('folder names keep the title readable and the id safe', () {
      expect(bookFolderName('A/B: "C"', 'id with space'),
          'A_B_ _C_ [id_with_space]');
    });
  });
}
