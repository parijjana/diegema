import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../domain/models/librivox_book.dart';
import '../screenshot_mode.dart';

/// One chapter of a [DemoBookEntry]. For playable books, [filename] is
/// resolved against `kDemoAudioBase` (see `core/demo_mode.dart`) to build
/// the actual stream URL; for browse-only books it is display-only.
class DemoChapterEntry {
  final String title;
  final String filename;
  final int durationSeconds;

  const DemoChapterEntry({
    required this.title,
    required this.filename,
    required this.durationSeconds,
  });

  factory DemoChapterEntry.fromJson(Map<String, dynamic> json) {
    return DemoChapterEntry(
      title: json['title']?.toString() ?? '',
      filename: json['filename']?.toString() ?? '',
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
    );
  }
}

/// One entry of the bundled `assets/demo/catalog.json` curated catalog.
class DemoBookEntry {
  final String id;
  final String title;
  final String author;
  final String description;
  final String language;
  final List<String> narrators;
  final String category;
  final bool playable;
  final String coverUrl;
  final List<DemoChapterEntry> chapters;

  const DemoBookEntry({
    required this.id,
    required this.title,
    required this.author,
    required this.description,
    required this.language,
    required this.narrators,
    required this.category,
    required this.playable,
    required this.coverUrl,
    required this.chapters,
  });

  int get totalTimeSecs =>
      chapters.fold(0, (sum, c) => sum + c.durationSeconds);

  factory DemoBookEntry.fromJson(Map<String, dynamic> json) {
    final chaptersJson = json['chapters'] as List? ?? [];
    return DemoBookEntry(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Unknown Title',
      author: json['author']?.toString() ?? 'Unknown Author',
      description: json['description']?.toString() ?? '',
      language: json['language']?.toString() ?? 'English',
      narrators:
          (json['narrators'] as List? ?? []).map((n) => n.toString()).toList(),
      category: json['category']?.toString() ?? '',
      // Store screenshots show the full app, not the web demo's two
      // playable books (kScreenshotCaptureMode is false in every shipped build).
      playable: json['playable'] == true || kScreenshotCaptureMode,
      coverUrl: json['coverUrl']?.toString() ?? '',
      chapters: chaptersJson
          .map((c) => DemoChapterEntry.fromJson(c as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Converts to the domain model the real widgets already know how to
  /// render, so no UI fork is needed for the demo (rework_plan.md: "Do
  /// NOT fork the UI — reuse the real widgets").
  LibriVoxBook toLibriVoxBook() {
    return LibriVoxBook(
      id: id,
      title: title,
      description: description,
      totalTimeSecs: totalTimeSecs,
      authors: [LibriVoxAuthor(id: id, firstName: '', lastName: author)],
      urlRss: '',
      urlZipFile: '',
      urlIarchive: 'https://archive.org/details/$id',
      language: language,
      narrators: narrators,
      demoPlayable: playable,
    );
  }
}

/// Loads and caches the bundled demo catalog asset. Never touches the
/// network — the whole point of the canned demo is that browsing works
/// with zero API calls.
class DemoCatalog {
  static List<DemoBookEntry>? _cache;

  static Future<List<DemoBookEntry>> load() async {
    final cached = _cache;
    if (cached != null) return cached;

    final raw = await rootBundle.loadString('assets/demo/catalog.json');
    final decoded = json.decode(raw) as Map<String, dynamic>;
    final booksJson = decoded['books'] as List? ?? [];
    final entries = booksJson
        .map((b) => DemoBookEntry.fromJson(b as Map<String, dynamic>))
        .toList();
    _cache = entries;
    return entries;
  }
}
