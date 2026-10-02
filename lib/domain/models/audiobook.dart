class AudiobookChapter {
  final String id;
  final String title;
  final String audioPathOrUrl;
  final int durationSeconds;
  final bool isStream;

  /// Offsets, in milliseconds, into [audioPathOrUrl] for a chapter that is
  /// a *marker* inside a single shared file (an M4B's embedded chapter
  /// table — see `core/utils/mp4_chapters.dart`) rather than its own file.
  /// `null` means "the whole file", which is every chapter before M4B
  /// import existed and every non-M4B chapter today. [endMs] is `null`
  /// only when [startMs] is also `null`, or for the final marker of a file
  /// whose total duration could not be determined.
  final int? startMs;
  final int? endMs;

  AudiobookChapter({
    required this.id,
    required this.title,
    required this.audioPathOrUrl,
    required this.durationSeconds,
    this.isStream = false,
    this.startMs,
    this.endMs,
  });
}

class UnifiedAudiobook {
  final String id;
  final String title;
  final String author;
  final String description;
  final String? coverArtUrlOrPath;
  final String? source; // e.g. 'Local', 'LibriVox', 'OpenFeed'

  /// Where this book *came from*, as opposed to [source] (a free-text
  /// display label). Only two values are meaningful today:
  /// `BookIdentity.originLibrivox` and `BookIdentity.originLocal` — see
  /// `core/utils/book_identity.dart`. The UI redesign uses this to render
  /// an origin badge ("LibriVox" vs "Manually added").
  final String origin;
  final List<String> narrators;
  final List<AudiobookChapter> chapters;
  final bool isDownloaded;

  UnifiedAudiobook({
    required this.id,
    required this.title,
    required this.author,
    required this.description,
    this.coverArtUrlOrPath,
    this.source = 'Local',
    this.origin = 'local',
    this.narrators = const [],
    this.chapters = const [],
    this.isDownloaded = true,
  });
}
