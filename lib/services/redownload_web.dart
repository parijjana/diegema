import '../domain/models/audiobook.dart';

/// Web mirror of `redownload_io.dart`: the web demo never downloads.
Future<bool> downloadedChapterReadable(
        UnifiedAudiobook book, int index) async =>
    true;

bool canRedownload(UnifiedAudiobook book) => false;
