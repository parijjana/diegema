/// Turns a filename-style chapter title into something readable.
///
/// Downloaded and imported books fall back to the audio file's name when
/// the feed gave no section title, which leaves rows such as
/// `3sfstoriesbywilliamtenn_01_tenn_64kb`. Real titles ("Null-P",
/// "Chapter 1 - Letter 1") are returned untouched.
///
/// A title counts as filename-style when it has no whitespace and either
/// contains an underscore, ends in a bitrate tag (`64kb`, `128kbps`) or
/// carries an audio file extension. Such a title loses its extension and
/// bitrate, and its track number (the last all-digit token) becomes
/// "Part N" - or "Chapter N" when the name itself says chapter. With no
/// number to find, [index] (zero-based position in the book) stands in;
/// without that either, the underscores simply become spaces.
String prettifyChapterTitle(String title, {int? index}) {
  final trimmed = title.trim();
  if (!_looksLikeFilename(trimmed)) return title;

  var name = trimmed.replaceAll(_extension, '').replaceAll(_bitrate, '');
  final tokens = name.split(RegExp(r'[_\s]+')).where((t) => t.isNotEmpty);
  final list = tokens.toList();

  for (var i = list.length - 1; i >= 0; i--) {
    final n = int.tryParse(list[i]);
    if (n == null || n <= 0) continue;
    final isChapter = list.any((t) {
      final l = t.toLowerCase();
      return l == 'chapter' || l == 'chap' || l == 'ch';
    });
    return '${isChapter ? 'Chapter' : 'Part'} $n';
  }
  if (index != null) return 'Part ${index + 1}';
  name = list.join(' ');
  return name.isEmpty ? title : name;
}

final RegExp _extension =
    RegExp(r'\.(mp3|m4a|m4b|aac|ogg|opus|flac|wav)$', caseSensitive: false);
final RegExp _bitrate =
    RegExp(r'[_\-\s]?\d{2,3}\s?kb(?:ps)?$', caseSensitive: false);

bool _looksLikeFilename(String s) {
  if (s.isEmpty || RegExp(r'\s').hasMatch(s)) return false;
  return s.contains('_') || _extension.hasMatch(s) || _bitrate.hasMatch(s);
}
