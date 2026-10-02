import 'dart:typed_data';

/// Metadata pulled from an audio file's embedded tags — MP4 `ilst` atoms
/// (see `mp4_metadata.dart`) or ID3v2 frames (see `id3_metadata.dart`) —
/// used to give a locally imported book real cover art and title/author
/// instead of the filename/foldername-derived defaults
/// (`services/local_audiobook_import_io.dart`).
///
/// Title precedence is "album, else name" and author precedence is "album
/// artist, else artist" — the same rule for both tag formats, since a
/// LibriVox M4B/MP3 typically carries the book's title in the *album* tag
/// (each chapter file's own "track title" is the chapter name) and the
/// reader/narrator in the *artist* tag.
class LocalMediaMetadata {
  final String? title;
  final String? author;
  final String? description;
  final Uint8List? coverBytes;

  /// `'image/jpeg'` or `'image/png'`, set whenever [coverBytes] is.
  final String? coverMime;

  const LocalMediaMetadata({
    this.title,
    this.author,
    this.description,
    this.coverBytes,
    this.coverMime,
  });

  bool get hasCover => coverBytes != null && coverBytes!.isNotEmpty;

  bool get isEmpty =>
      (title == null || title!.trim().isEmpty) &&
      (author == null || author!.trim().isEmpty) &&
      (description == null || description!.trim().isEmpty) &&
      !hasCover;
}
