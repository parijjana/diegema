import '../../domain/models/audiobook.dart';

/// A title split into the part shared by every recording/volume of a work
/// and the part that tells them apart. [label] is null when nothing matched.
typedef TitleSplit = ({String base, String? label});

final _versionTail = RegExp(
  r'^(.*?)\s*(?:,\s*|\(\s*)?\b(version)\s+(\d+)\s*\)?\s*$',
  caseSensitive: false,
);
final _volumeTail = RegExp(
  r'^(.*?)\s*(?:,\s*|\(\s*)?\b(vol\.?|volume)\s*(\d+)\s*\)?\s*$',
  caseSensitive: false,
);
final _collectionTail = RegExp(
  r'^(.*\b(?:collection|series))\s+(\d+)\s*$',
  caseSensitive: false,
);

/// Splits ", Version 2", "(version 5)", "Vol. 001", "Volume 3" and a
/// trailing "Collection 032" off [title]. Titles that don't match (including
/// ones that are only a number, like "1984") come back whole, label null.
TitleSplit splitTitleVariant(String title) {
  final t = title.trim();
  var m = _versionTail.firstMatch(t);
  if (m != null && m.group(1)!.trim().isNotEmpty) {
    return (base: m.group(1)!.trim(), label: 'Version ${m.group(3)}');
  }
  m = _volumeTail.firstMatch(t);
  if (m != null && m.group(1)!.trim().isNotEmpty) {
    final word = m.group(2)!.toLowerCase().startsWith('vol.') ||
            m.group(2)!.toLowerCase() == 'vol'
        ? 'Vol.'
        : 'Volume';
    return (base: m.group(1)!.trim(), label: '$word ${m.group(3)}');
  }
  m = _collectionTail.firstMatch(t);
  if (m != null) {
    return (base: m.group(1)!.trim(), label: 'Vol. ${m.group(2)}');
  }
  return (base: t, label: null);
}

/// For every book whose base title is shared by two or more books in
/// [books], the label that tells it apart: "Version 2", "Vol. 032", or
/// "Original" for the unsuffixed one. Books with a unique base title (and
/// copies with nothing to tell them apart) are absent from the result, so
/// they render exactly as before.
///
/// The reader is deliberately not used: the Library database does not store
/// narrators, so a library book never carries them.
Map<String, String> libraryVariantLabels(List<UnifiedAudiobook> books) {
  final groups = <String, List<(String, TitleSplit)>>{};
  for (final b in books) {
    final s = splitTitleVariant(b.title);
    groups.putIfAbsent(s.base.toLowerCase(), () => []).add((b.id, s));
  }
  final out = <String, String>{};
  for (final g in groups.values) {
    if (g.length < 2 || !g.any((e) => e.$2.label != null)) continue;
    for (final (id, s) in g) {
      out[id] = s.label ?? 'Original';
    }
  }
  return out;
}
