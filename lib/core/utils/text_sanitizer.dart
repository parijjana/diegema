class TextSanitizer {
  /// Sanitizes string fetched from external APIs (LibriVox, archive.org) by:
  /// 1. Replacing `<br>` or `<br/>` tags with newlines (`\n`).
  /// 2. Removing any other HTML/XML tags.
  /// 3. Decoding common HTML/XML entities.
  /// 4. Normalizing consecutive spaces and newlines, and trimming each line.
  static String sanitize(String input) {
    if (input.isEmpty) return '';

    var clean = input.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
    clean = clean.replaceAll(RegExp(r'<[^>]*>'), '');
    clean = clean
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&nbsp;', ' ');

    final lines = clean.split('\n');
    final processedLines = lines.map((line) {
      return line.replaceAll(RegExp(r'[ \t]+'), ' ').trim();
    }).toList();

    var result = processedLines.join('\n');
    result = result.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    return result.trim();
  }
}
