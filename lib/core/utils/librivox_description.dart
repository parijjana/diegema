/// Parses a LibriVox/archive.org book `description` (already run through
/// [TextSanitizer]) into labelled segments so a widget can render it as a
/// structured list instead of a wall of text.
///
/// LibriVox descriptions are templated free text, not structured data, and
/// the template is followed loosely: some fields are missing, punctuation
/// is sometimes wrong (a semicolon where a period belongs, or vice versa),
/// and a few descriptions are written in a completely different language
/// with no template at all. This parser is therefore deliberately
/// conservative: when it cannot confidently identify a segment it leaves
/// the text in [LibriVoxDescription.summary] rather than guessing, and it
/// never throws — a malformed or empty input always produces some result.
library;

/// The parsed, segmented form of a LibriVox description.
class LibriVoxDescription {
  const LibriVoxDescription({
    this.readBy,
    this.language,
    this.summary = const [],
    this.contents = const [],
    this.summaryBy,
    this.formats,
  });

  /// Narrator name(s), e.g. `"Alan Mapstone; Bruce Kachuk and Stacey
  /// Malcolm"`, extracted from a `"Read [in LANGUAGE] by NAMES"` clause.
  /// `null` when no such clause was found.
  final String? readBy;

  /// The language named in `"Read in <language> by ..."`, e.g. `"English"`,
  /// `"Spanish"`, `"Multilingual"`. `null` when the description used the
  /// plain `"Read by ..."` form (English implied) or no such clause was
  /// found at all.
  final String? language;

  /// The book's summary, as readable paragraphs. Anything the parser could
  /// not confidently classify into another field ends up here, so this is
  /// never lossy even when the rest of the parse is thin.
  final List<String> summary;

  /// Bulleted contents — a collection's individual stories/poems/chapters —
  /// when the description contains a recognisable enumerated or
  /// semicolon-separated list.
  final List<String> contents;

  /// Who wrote the summary, from `"(Summary by X)"` / `"(summary from
  /// Wikipedia)"` or a trailing `"- Summary by X"` / `"Summary by X"`.
  final String? summaryBy;

  /// A short formats/size caption, e.g. `"M4B audiobook · 111 MB"`, parsed
  /// from a trailing `"M4B Audiobook (111MB)"`-style line. Only the first
  /// such line is kept even when the description lists several (one per
  /// multi-part download).
  final String? formats;

  /// True once the parser has classified something beyond a single
  /// undifferentiated summary block — i.e. there is real structure for a
  /// widget to render as sections rather than falling back to plain text.
  bool get hasStructure =>
      readBy != null ||
      contents.isNotEmpty ||
      summaryBy != null ||
      formats != null;

  static const empty = LibriVoxDescription();
}

// Single-letter initials ("F.") and these common abbreviations never end a
// sentence/name-list on their own, so a period after one of them is not
// treated as a stop/sentence boundary.
const Set<String> _abbreviations = {
  'mr', 'mrs', 'ms', 'dr', 'st', 'jr', 'sr', 'prof', 'rev', 'messrs', 'mt',
  'vs', 'etc', 'inc', 'ltd', 'co', 'gen', 'col', 'capt', 'sgt', 'no',
};

// Common function words that signal we have run past the end of a narrator
// name list and into ordinary prose (e.g. "...and Joseph Finkberg This is
// our 35th collection..." — no punctuation separates the list from the
// next sentence at all in some real descriptions).
const Set<String> _proseStopwords = {
  'is', 'was', 'were', 'are', 'this', 'these', 'the', 'a', 'an', 'which',
  'who', 'that', 'has', 'have', 'his', 'her', 'their', 'one', 'recounts',
  'describes', 'tells', 'says', 'so',
};

bool _isAbbreviation(String word) {
  if (word.isEmpty) return false;
  if (word.length == 1) return true;
  return _abbreviations.contains(word.toLowerCase());
}

/// Parses [raw] into a [LibriVoxDescription]. Never throws: any unexpected
/// shape of input falls back to returning the trimmed text as a single
/// summary paragraph.
LibriVoxDescription parseLibriVoxDescription(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return LibriVoxDescription.empty;

  try {
    return _parse(trimmed);
  } catch (_) {
    return LibriVoxDescription(summary: [trimmed]);
  }
}

LibriVoxDescription _parse(String text) {
  var body = text;

  // 1. Split off the trailing LibriVox boilerplate ("For further
  //    information... please go to the LibriVox catalog page... For more
  //    free audio books... visit LibriVox.org .") and whatever follows it
  //    (format/size lines).
  String tail = '';
  final tailMatch =
      RegExp(r'for further information', caseSensitive: false).firstMatch(body);
  if (tailMatch != null) {
    tail = body.substring(tailMatch.start);
    body = body.substring(0, tailMatch.start).trim();
  }
  final formats = _extractFormats(tail);

  // 2. Summary credit: "(Summary by X)" / "(summary from X)" anywhere, or a
  //    trailing "- Summary by X" / "Summary by X" right before the tail.
  String? summaryBy;
  final parenSummary =
      RegExp(r'\(\s*summary (?:by|from)\s+([^)]+?)\s*\)', caseSensitive: false)
          .firstMatch(body);
  if (parenSummary != null) {
    summaryBy = parenSummary.group(1)!.trim();
    body = (body.substring(0, parenSummary.start) +
            body.substring(parenSummary.end))
        .trim();
  } else {
    final trailingSummary = RegExp(
      r'-?\s*summary (?:by|from)\s+([A-Za-z][\w .,’' "'" r'&-]*)\s*$',
      caseSensitive: false,
    ).firstMatch(body);
    if (trailingSummary != null) {
      summaryBy = trailingSummary.group(1)!.trim();
      body = body.substring(0, trailingSummary.start).trim();
    }
  }

  // 3. Canonical opener: "LibriVox recording of <title> by <author>." Only
  //    the exact templated form is stripped — free text that merely starts
  //    with the word "LibriVox" (e.g. "LibriVox volunteers bring you...")
  //    is left alone, since it can carry real information.
  final openerMatch =
      RegExp(r'^librivox\s+recording of\s+.+?\.\s*', caseSensitive: false)
          .firstMatch(body);
  if (openerMatch != null) {
    body = body.substring(openerMatch.end).trim();
  }

  // 4. "Read [in <language>] by <names>" — narrator(s) and language. Only
  //    the matched clause itself is removed, wherever it falls, so any
  //    real prose before or after it survives into the summary.
  String? readBy;
  String? language;
  final readMatch =
      RegExp(r'\bRead\s+(?:in\s+([A-Za-z]+)\s+)?by\s+').firstMatch(body);
  if (readMatch != null) {
    language = readMatch.group(1);
    final namesEnd = _namesEnd(body, readMatch.end);
    var names = body.substring(readMatch.end, namesEnd).trim();
    names = names.replaceAll(RegExp(r'[;,.\-\s]+$'), '');
    if (names.isNotEmpty) {
      readBy = names;
      body = (body.substring(0, readMatch.start) + body.substring(namesEnd))
          .trim();
    }
  }

  // 5. Contents: a numbered list ("1. ... 2. ... 3. ...") or a
  //    colon-introduced, semicolon-separated list ("...includes: A; B; C").
  List<String> contents = const [];
  final numbered = _extractNumberedList(body);
  if (numbered != null) {
    contents = numbered.items;
    body = numbered.intro;
  } else {
    final colonList = _extractColonList(body);
    if (colonList != null) {
      contents = colonList.items;
      body = colonList.intro;
    }
  }

  body = body.replaceAll(RegExp(r'[ \t]{2,}'), ' ').trim();

  final summary = _paragraphs(body);

  return LibriVoxDescription(
    readBy: readBy,
    language: language,
    summary: summary,
    contents: contents,
    summaryBy: summaryBy,
    formats: formats,
  );
}

/// Scans forward from [start] (just after "...by ") collecting narrator
/// names, stopping at the first sign we have run into ordinary prose:
/// a non-abbreviation period, a stray sentence-starting stopword, or a
/// generous length cap as a last resort.
int _namesEnd(String body, int start) {
  const cap = 400;
  final limit = (start + cap < body.length) ? start + cap : body.length;
  final tokenPattern = RegExp(r'\S+');
  // Unicode-aware so accented names (Heródoto, Sep Szarzyński, ...) are not
  // mis-truncated to an ASCII-only prefix that might collide with a
  // stopword (e.g. "Heródoto" -> "Her", which matches the stopword "her").
  final coreWordPattern =
      RegExp(r"^[^\p{L}\p{N}]*([\p{L}\p{N}']+)", unicode: true);
  final wordBeforePeriodPattern = RegExp(r'(\p{L}+)\.$', unicode: true);
  var end = start;
  // A name list is punctuated (semicolons/commas between entries). When a
  // run of several tokens goes by with none of that punctuation and no
  // sentence-ending period either, we have almost certainly run off the end
  // of a single un-terminated name (e.g. "Read in Spanish by Tux <prose in
  // Spanish with no further English cues>") into ordinary prose — fall back
  // to whatever was captured at the last separator, or just the first
  // token when there was never a separator at all.
  const maxTokensWithoutSeparator = 5;
  var tokensSinceSeparator = 0;
  var lastSeparatorEnd = -1;
  int? firstTokenEnd;
  for (final match in tokenPattern.allMatches(body, start)) {
    if (match.start >= limit) break;
    final token = match.group(0)!;
    if (token.contains('\n')) break;
    firstTokenEnd ??= match.end;
    final core = coreWordPattern.firstMatch(token);
    final word = core?.group(1) ?? '';
    // A single-letter "word" here is almost always an initial ("A." in
    // "A.M."), not the article "a" — never treat it as a stopword.
    if (word.length > 1 && _proseStopwords.contains(word.toLowerCase())) {
      break;
    }
    final endsWithPeriod = token.endsWith('.');
    final endsWithSemiOrComma = token.endsWith(';') || token.endsWith(',');
    if (endsWithPeriod) {
      final wordBeforePeriod =
          wordBeforePeriodPattern.firstMatch(token)?.group(1) ?? '';
      if (_isAbbreviation(wordBeforePeriod)) {
        end = match.end;
        continue;
      }
      end = match.end;
      break;
    }
    end = match.end;
    if (endsWithSemiOrComma) {
      tokensSinceSeparator = 0;
      lastSeparatorEnd = match.end;
      continue;
    }
    tokensSinceSeparator++;
    if (tokensSinceSeparator > maxTokensWithoutSeparator) {
      end = lastSeparatorEnd != -1 ? lastSeparatorEnd : firstTokenEnd;
      break;
    }
  }
  return end.clamp(start, body.length);
}

class _ListResult {
  _ListResult(this.intro, this.items);
  final String intro;
  final List<String> items;
}

/// Detects a numbered list ("1. Foo 2. Bar 3. Baz...") with at least three
/// sequential, increasing markers starting at 1 or 2 (so a stray "1800."
/// or a chapter number mid-sentence never trips this).
_ListResult? _extractNumberedList(String body) {
  final markers = RegExp(r'(?:^|\s)(\d{1,3})\.\s+').allMatches(body).toList();
  if (markers.length < 3) return null;
  final nums = markers.map((m) => int.parse(m.group(1)!)).toList();
  if (nums.first > 2) return null;
  for (var i = 1; i < nums.length; i++) {
    if (nums[i] <= nums[i - 1]) return null;
  }
  // RegExpMatch has no per-group start offset, so recover the digit run's
  // start (excluding the optional leading whitespace in the full match)
  // by locating the captured number text within the full match text.
  int digitStart(RegExpMatch m) =>
      m.start + m.group(0)!.indexOf(m.group(1)!);

  final intro = body.substring(0, digitStart(markers.first)).trim();
  final items = <String>[];
  for (var i = 0; i < markers.length; i++) {
    final itemStart = markers[i].end;
    final itemEnd =
        i + 1 < markers.length ? digitStart(markers[i + 1]) : body.length;
    if (itemStart >= itemEnd) continue;
    final item = body.substring(itemStart, itemEnd).trim();
    if (item.isNotEmpty) items.add(item);
  }
  if (items.length < 3) return null;
  return _ListResult(intro, items);
}

/// Detects a colon-introduced, semicolon-separated list, triggered by a
/// nearby word like "includes"/"contains"/"comprises"/"contents" in the
/// ~60 characters before the colon.
_ListResult? _extractColonList(String body) {
  final triggerWords = RegExp(
    r'\b(includes?|contain(?:s|ing)?|comprises?|contents|following)\b',
    caseSensitive: false,
  );
  var searchFrom = 0;
  while (true) {
    final colonIndex = body.indexOf(':', searchFrom);
    if (colonIndex == -1) return null;
    final contextStart = (colonIndex - 60).clamp(0, colonIndex);
    final context = body.substring(contextStart, colonIndex);
    if (triggerWords.hasMatch(context)) {
      final listText = body.substring(colonIndex + 1).trim();
      final items = listText
          .split(';')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      if (items.length >= 2) {
        final intro = body.substring(0, colonIndex).trim();
        return _ListResult(intro, items);
      }
      return null;
    }
    searchFrom = colonIndex + 1;
  }
}

String? _extractFormats(String tail) {
  final match = RegExp(
    r'(M4B|MP3|Ogg|Zip)\b[^(]{0,40}\(([\d.]+)\s*([kKmMgG][bB])\)',
  ).firstMatch(tail);
  if (match == null) return null;
  final type = match.group(1)!;
  final size = match.group(2)!;
  final unit = match.group(3)!.toUpperCase();
  return '$type audiobook · $size $unit';
}

/// Splits [body] into readable paragraphs: existing blank-line breaks are
/// honoured first; a single very long block with no breaks is then
/// re-chunked into groups of 2-3 sentences, splitting only at sentence
/// boundaries that are not abbreviations or initials.
List<String> _paragraphs(String body) {
  if (body.isEmpty) return const [];
  final blocks = body
      .split(RegExp(r'\n{2,}'))
      .map((b) => b.replaceAll(RegExp(r'\s*\n\s*'), ' ').trim())
      .where((b) => b.isNotEmpty)
      .toList();
  if (blocks.isEmpty) return const [];
  if (blocks.length > 1) return blocks;

  final only = blocks.first;
  if (only.length <= 320) return [only];

  final sentences = _splitSentences(only);
  if (sentences.length <= 3) return [only];
  return _chunkSentences(sentences);
}

List<String> _splitSentences(String text) {
  final sentences = <String>[];
  var start = 0;
  for (var i = 0; i < text.length; i++) {
    final ch = text[i];
    if (ch != '.' && ch != '!' && ch != '?') continue;
    if (ch == '.') {
      final wordBefore = RegExp(r'(\p{L}+)$', unicode: true)
              .firstMatch(text.substring(start, i))
              ?.group(1) ??
          '';
      if (_isAbbreviation(wordBefore)) continue;
    }
    final isEnd = i == text.length - 1;
    final nextIsSpace = !isEnd && text[i + 1] == ' ';
    final afterSpace = i + 2 < text.length ? text[i + 2] : '';
    final looksLikeNewSentence =
        afterSpace.isNotEmpty && RegExp(r'[A-Z0-9"“(]').hasMatch(afterSpace);
    if (isEnd || (nextIsSpace && looksLikeNewSentence)) {
      sentences.add(text.substring(start, i + 1).trim());
      start = i + 1;
    }
  }
  if (start < text.length) {
    final rest = text.substring(start).trim();
    if (rest.isNotEmpty) sentences.add(rest);
  }
  return sentences.where((s) => s.isNotEmpty).toList();
}

List<String> _chunkSentences(List<String> sentences) {
  final paragraphs = <String>[];
  var i = 0;
  while (i < sentences.length) {
    final remaining = sentences.length - i;
    final take = remaining == 4 ? 2 : (remaining >= 3 ? 3 : remaining);
    paragraphs.add(sentences.sublist(i, i + take).join(' '));
    i += take;
  }
  return paragraphs;
}
