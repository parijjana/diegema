import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// A single chapter marker read out of an M4B's embedded chapter data.
///
/// [startMs] is this chapter's start offset in milliseconds into the file's
/// audio track. Where it ends is not carried here — the caller derives it
/// from the *next* marker's [startMs] (or the file's total duration for the
/// last one); see `services/local_audiobook_import_io.dart`.
class Mp4Chapter {
  final String title;
  final int startMs;

  const Mp4Chapter({required this.title, required this.startMs});
}

/// The result of [readMp4Chapters]: the chapter markers plus the file's
/// total duration (from `moov/mvhd`), which the caller needs to compute the
/// last chapter's end offset.
class Mp4Chapters {
  final List<Mp4Chapter> chapters;
  final int durationMs;

  const Mp4Chapters({required this.chapters, required this.durationMs});
}

/// Reads embedded chapter markers out of an MP4/M4B file at [path], without
/// ever loading the whole file into memory — M4Bs run to hundreds of MB, and
/// this only ever touches the small `moov` metadata tree via seeks.
///
/// Two chapter formats are understood, and both are read straight off the
/// raw atom tree rather than via any codec/DRM library — this is metadata
/// parsing only, and never touches AAX/Audible activation or decryption:
/// - The QuickTime chapter track: a `trak` whose samples are chapter titles,
///   referenced from the audio `trak`'s `tref/chap`. Preferred when present,
///   since it carries exact per-chapter timing via `stts`.
/// - The Nero `chpl` atom at `moov/udta/chpl`, a flat list of
///   (start time, title) pairs. Used as a fallback.
///
/// Returns `null` — never throws — when the file has no chapters, is not an
/// MP4 at all, or is truncated/malformed enough that no chapter data could
/// be recovered.
Future<Mp4Chapters?> readMp4Chapters(String path) async {
  RandomAccessFile? raf;
  try {
    raf = await File(path).open();
    final length = await raf.length();
    final topAtoms = await _readAtoms(raf, 0, length);
    final moov = _firstOfType(topAtoms, 'moov');
    if (moov == null) return null;

    final moovChildren = await _readAtoms(raf, moov.dataStart, moov.end);
    final mvhd = _firstOfType(moovChildren, 'mvhd');
    if (mvhd == null) return null;
    final durationMs = await _readMvhdDurationMs(raf, mvhd);

    final quickTimeChapters =
        await _tryReadQuickTimeChapters(raf, moovChildren);
    if (quickTimeChapters != null && quickTimeChapters.isNotEmpty) {
      return Mp4Chapters(chapters: quickTimeChapters, durationMs: durationMs);
    }

    final udta = _firstOfType(moovChildren, 'udta');
    if (udta != null) {
      final udtaChildren = await _readAtoms(raf, udta.dataStart, udta.end);
      final chpl = _firstOfType(udtaChildren, 'chpl');
      if (chpl != null) {
        final chplChapters = await _readChpl(raf, chpl);
        if (chplChapters.isNotEmpty) {
          return Mp4Chapters(chapters: chplChapters, durationMs: durationMs);
        }
      }
    }

    return null;
  } catch (_) {
    return null;
  } finally {
    try {
      await raf?.close();
    } catch (_) {}
  }
}

// --- Atom tree ---------------------------------------------------------

/// One parsed atom ("box") header: its fourcc [type], the byte range of the
/// whole atom (including its header, `[start, end)`), and where its payload
/// begins ([dataStart]).
class _Atom {
  final String type;
  final int start;
  final int end;
  final int dataStart;

  const _Atom(this.type, this.start, this.end, this.dataStart);
}

/// Walks the sibling atoms in the byte range `[start, end)`, handling both
/// the normal 32-bit size and the 64-bit extended size (`size == 1`, an
/// extra 8-byte size field right after the header) and `size == 0` ("runs to
/// the end of its parent"). Any header that would push an atom past [end],
/// or that doesn't advance [start], stops the walk rather than throwing —
/// callers see whatever atoms were parsed before the corruption.
Future<List<_Atom>> _readAtoms(RandomAccessFile raf, int start, int end) async {
  final atoms = <_Atom>[];
  int pos = start;
  while (pos + 8 <= end) {
    await raf.setPosition(pos);
    final header = await raf.read(8);
    if (header.length < 8) break;
    final size32 = _readU32(header, 0);
    final type = _fourcc(header, 4);

    int dataStart = pos + 8;
    int atomEnd;
    if (size32 == 1) {
      final ext = await raf.read(8);
      if (ext.length < 8) break;
      dataStart = pos + 16;
      atomEnd = pos + _readU64(ext, 0);
    } else if (size32 == 0) {
      atomEnd = end;
    } else {
      atomEnd = pos + size32;
    }

    if (atomEnd <= pos || atomEnd > end || dataStart > atomEnd) break;
    atoms.add(_Atom(type, pos, atomEnd, dataStart));
    pos = atomEnd;
  }
  return atoms;
}

_Atom? _firstOfType(List<_Atom> atoms, String type) {
  for (final atom in atoms) {
    if (atom.type == type) return atom;
  }
  return null;
}

Future<Uint8List> _readAt(RandomAccessFile raf, int pos, int len) async {
  if (len <= 0) return Uint8List(0);
  await raf.setPosition(pos);
  return raf.read(len);
}

int _readU32(Uint8List data, int offset) =>
    ByteData.sublistView(data, offset, offset + 4).getUint32(0, Endian.big);

int _readU64(Uint8List data, int offset) =>
    ByteData.sublistView(data, offset, offset + 8).getUint64(0, Endian.big);

String _fourcc(Uint8List data, int offset) =>
    String.fromCharCodes(data.sublist(offset, offset + 4));

// --- mvhd / mdhd / tkhd / hdlr (fixed-layout fullboxes) -----------------

/// `moov/mvhd`: `timescale`/`duration` live at different offsets depending
/// on the box's version (0 uses 32-bit times, 1 uses 64-bit).
Future<int> _readMvhdDurationMs(RandomAccessFile raf, _Atom mvhd) async {
  final versionByte = await _readAt(raf, mvhd.dataStart, 1);
  if (versionByte.isEmpty) return 0;
  if (versionByte[0] == 1) {
    final body = await _readAt(raf, mvhd.dataStart + 4, 28);
    if (body.length < 28) return 0;
    final timescale = _readU32(body, 16);
    final duration = _readU64(body, 20);
    if (timescale == 0) return 0;
    return (duration * 1000) ~/ timescale;
  } else {
    final body = await _readAt(raf, mvhd.dataStart + 4, 16);
    if (body.length < 16) return 0;
    final timescale = _readU32(body, 8);
    final duration = _readU32(body, 12);
    if (timescale == 0) return 0;
    return (duration * 1000) ~/ timescale;
  }
}

/// `trak/mdia/mdhd`: just the timescale, for converting that track's
/// `stts` deltas into milliseconds.
Future<int> _readMdhdTimescale(RandomAccessFile raf, _Atom mdhd) async {
  final versionByte = await _readAt(raf, mdhd.dataStart, 1);
  if (versionByte.isEmpty) return 0;
  if (versionByte[0] == 1) {
    final body = await _readAt(raf, mdhd.dataStart + 4, 20);
    if (body.length < 20) return 0;
    return _readU32(body, 16);
  } else {
    final body = await _readAt(raf, mdhd.dataStart + 4, 12);
    if (body.length < 12) return 0;
    return _readU32(body, 8);
  }
}

/// `trak/tkhd`: just the track ID, so a `tref/chap` reference (also a track
/// ID) can be matched back to the `trak` that owns it.
Future<int> _readTkhdTrackId(RandomAccessFile raf, _Atom tkhd) async {
  final versionByte = await _readAt(raf, tkhd.dataStart, 1);
  if (versionByte.isEmpty) return -1;
  if (versionByte[0] == 1) {
    final body = await _readAt(raf, tkhd.dataStart + 4, 20);
    if (body.length < 20) return -1;
    return _readU32(body, 16);
  } else {
    final body = await _readAt(raf, tkhd.dataStart + 4, 12);
    if (body.length < 12) return -1;
    return _readU32(body, 8);
  }
}

/// `trak/mdia/hdlr`: the 4-byte handler type fourcc (`'text'`/`'sbtl'` for
/// a QuickTime chapter track, `'soun'` for audio, etc).
Future<String> _readHdlrHandlerType(RandomAccessFile raf, _Atom hdlr) async {
  final body = await _readAt(raf, hdlr.dataStart + 8, 4);
  if (body.length < 4) return '';
  return _fourcc(body, 0);
}

// --- Nero chpl ------------------------------------------------------------

/// `moov/udta/chpl`: version(1) + reserved(4) + count(1), then per entry a
/// u64 start time in 100ns units, a u8 title length, and the title bytes.
Future<List<Mp4Chapter>> _readChpl(RandomAccessFile raf, _Atom chpl) async {
  final data = await _readAt(raf, chpl.dataStart, chpl.end - chpl.dataStart);
  if (data.length < 6) return const [];

  final count = data[5];
  final chapters = <Mp4Chapter>[];
  int offset = 6;
  for (int i = 0; i < count; i++) {
    if (offset + 9 > data.length) break;
    final start100ns = _readU64(data, offset);
    final titleLen = data[offset + 8];
    final titleStart = offset + 9;
    if (titleStart + titleLen > data.length) break;

    String title;
    try {
      title = utf8.decode(data.sublist(titleStart, titleStart + titleLen));
    } catch (_) {
      title = '';
    }

    chapters.add(Mp4Chapter(title: title, startMs: start100ns ~/ 10000));
    offset = titleStart + titleLen;
  }
  return chapters;
}

// --- QuickTime chapter track -----------------------------------------------

/// Looks across every `trak` in [moovChildren] for one with a `tref/chap`
/// reference, resolves the referenced track, and reads it as a chapter
/// track if its handler type qualifies. Returns `null` if no track
/// qualifies (not "no chapters found" specifically — the caller falls back
/// to `chpl` either way).
Future<List<Mp4Chapter>?> _tryReadQuickTimeChapters(
  RandomAccessFile raf,
  List<_Atom> moovChildren,
) async {
  final traks = moovChildren.where((a) => a.type == 'trak').toList();

  for (final trak in traks) {
    final trakChildren = await _readAtoms(raf, trak.dataStart, trak.end);
    final tref = _firstOfType(trakChildren, 'tref');
    if (tref == null) continue;

    final trefChildren = await _readAtoms(raf, tref.dataStart, tref.end);
    final chap = _firstOfType(trefChildren, 'chap');
    if (chap == null) continue;

    final refData =
        await _readAt(raf, chap.dataStart, chap.end - chap.dataStart);
    if (refData.length < 4) continue;
    final referencedTrackId = _readU32(refData, 0);

    for (final candidate in traks) {
      final candidateChildren =
          await _readAtoms(raf, candidate.dataStart, candidate.end);
      final tkhd = _firstOfType(candidateChildren, 'tkhd');
      if (tkhd == null) continue;
      final trackId = await _readTkhdTrackId(raf, tkhd);
      if (trackId != referencedTrackId) continue;

      final chapters =
          await _readQuickTimeChapterTrack(raf, candidateChildren);
      if (chapters != null) return chapters;
    }
  }
  return null;
}

/// Reads a `trak`'s chapter samples once it has been identified as the
/// chapter track: checks the handler type, then walks `stts`/`stsz`/`stsc`/
/// `stco`(`co64`) to find each sample's time and file location.
Future<List<Mp4Chapter>?> _readQuickTimeChapterTrack(
  RandomAccessFile raf,
  List<_Atom> trakChildren,
) async {
  final mdia = _firstOfType(trakChildren, 'mdia');
  if (mdia == null) return null;
  final mdiaChildren = await _readAtoms(raf, mdia.dataStart, mdia.end);

  final hdlr = _firstOfType(mdiaChildren, 'hdlr');
  if (hdlr == null) return null;
  final handlerType = await _readHdlrHandlerType(raf, hdlr);
  if (handlerType != 'text' && handlerType != 'sbtl') return null;

  final mdhd = _firstOfType(mdiaChildren, 'mdhd');
  if (mdhd == null) return null;
  final timescale = await _readMdhdTimescale(raf, mdhd);
  if (timescale == 0) return null;

  final minf = _firstOfType(mdiaChildren, 'minf');
  if (minf == null) return null;
  final minfChildren = await _readAtoms(raf, minf.dataStart, minf.end);
  final stbl = _firstOfType(minfChildren, 'stbl');
  if (stbl == null) return null;
  final stblChildren = await _readAtoms(raf, stbl.dataStart, stbl.end);

  final stts = _firstOfType(stblChildren, 'stts');
  final stsz = _firstOfType(stblChildren, 'stsz');
  final stsc = _firstOfType(stblChildren, 'stsc');
  final stco = _firstOfType(stblChildren, 'stco');
  final co64 = _firstOfType(stblChildren, 'co64');
  if (stts == null || stsz == null || stsc == null) return null;
  if (stco == null && co64 == null) return null;

  final sampleStartTicks = await _readStts(raf, stts);
  final sampleSizes = await _readStsz(raf, stsz);
  final stscEntries = await _readStsc(raf, stsc);
  final chunkOffsets =
      stco != null ? await _readStco(raf, stco) : await _readCo64(raf, co64!);

  final samplesPerChunk = _samplesPerChunkByChunk(stscEntries, chunkOffsets.length);
  final sampleOffsets =
      _computeSampleOffsets(chunkOffsets, samplesPerChunk, sampleSizes);

  final count = [
    sampleStartTicks.length,
    sampleSizes.length,
    sampleOffsets.length,
  ].reduce((a, b) => a < b ? a : b);
  if (count == 0) return null;

  final chapters = <Mp4Chapter>[];
  for (int i = 0; i < count; i++) {
    final title =
        await _readTextSample(raf, sampleOffsets[i], sampleSizes[i]);
    final startMs = (sampleStartTicks[i] * 1000) ~/ timescale;
    chapters.add(Mp4Chapter(title: title, startMs: startMs));
  }
  return chapters;
}

/// `stts`: entry_count, then (sample_count, sample_delta) pairs. Expanded
/// into one cumulative start tick per sample (in the track's own timescale).
Future<List<int>> _readStts(RandomAccessFile raf, _Atom stts) async {
  final header = await _readAt(raf, stts.dataStart, 8);
  if (header.length < 8) return const [];
  final entryCount = _readU32(header, 4);
  final entries = await _readAt(raf, stts.dataStart + 8, entryCount * 8);

  final starts = <int>[];
  int t = 0;
  for (int i = 0; i < entryCount; i++) {
    final base = i * 8;
    if (base + 8 > entries.length) break;
    final sampleCount = _readU32(entries, base);
    final sampleDelta = _readU32(entries, base + 4);
    for (int s = 0; s < sampleCount; s++) {
      starts.add(t);
      t += sampleDelta;
    }
  }
  return starts;
}

/// `stsz`: a fixed sample size for every sample, or (when `sample_size ==
/// 0`) a per-sample size array.
Future<List<int>> _readStsz(RandomAccessFile raf, _Atom stsz) async {
  final header = await _readAt(raf, stsz.dataStart, 12);
  if (header.length < 12) return const [];
  final sampleSize = _readU32(header, 4);
  final sampleCount = _readU32(header, 8);

  if (sampleSize != 0) {
    return List<int>.filled(sampleCount, sampleSize);
  }

  final data = await _readAt(raf, stsz.dataStart + 12, sampleCount * 4);
  final sizes = <int>[];
  for (int i = 0; i < sampleCount; i++) {
    final base = i * 4;
    if (base + 4 > data.length) break;
    sizes.add(_readU32(data, base));
  }
  return sizes;
}

class _StscEntry {
  final int firstChunk; // 1-based
  final int samplesPerChunk;
  const _StscEntry(this.firstChunk, this.samplesPerChunk);
}

/// `stsc`: (first_chunk, samples_per_chunk, sample_description_index)
/// triples — only the first two fields matter here.
Future<List<_StscEntry>> _readStsc(RandomAccessFile raf, _Atom stsc) async {
  final header = await _readAt(raf, stsc.dataStart, 8);
  if (header.length < 8) return const [];
  final entryCount = _readU32(header, 4);
  final data = await _readAt(raf, stsc.dataStart + 8, entryCount * 12);

  final entries = <_StscEntry>[];
  for (int i = 0; i < entryCount; i++) {
    final base = i * 12;
    if (base + 12 > data.length) break;
    entries.add(_StscEntry(_readU32(data, base), _readU32(data, base + 4)));
  }
  return entries;
}

Future<List<int>> _readStco(RandomAccessFile raf, _Atom stco) async {
  final header = await _readAt(raf, stco.dataStart, 8);
  if (header.length < 8) return const [];
  final entryCount = _readU32(header, 4);
  final data = await _readAt(raf, stco.dataStart + 8, entryCount * 4);

  final offsets = <int>[];
  for (int i = 0; i < entryCount; i++) {
    final base = i * 4;
    if (base + 4 > data.length) break;
    offsets.add(_readU32(data, base));
  }
  return offsets;
}

Future<List<int>> _readCo64(RandomAccessFile raf, _Atom co64) async {
  final header = await _readAt(raf, co64.dataStart, 8);
  if (header.length < 8) return const [];
  final entryCount = _readU32(header, 4);
  final data = await _readAt(raf, co64.dataStart + 8, entryCount * 8);

  final offsets = <int>[];
  for (int i = 0; i < entryCount; i++) {
    final base = i * 8;
    if (base + 8 > data.length) break;
    offsets.add(_readU64(data, base));
  }
  return offsets;
}

/// Expands `stsc`'s ranged entries (each covering chunks `[firstChunk,
/// nextEntry.firstChunk)`) into one samples-per-chunk value per chunk
/// index (0-based).
List<int> _samplesPerChunkByChunk(List<_StscEntry> entries, int totalChunks) {
  final result = List<int>.filled(totalChunks, 0);
  for (int e = 0; e < entries.length; e++) {
    final firstChunk = entries[e].firstChunk;
    final lastChunk =
        e + 1 < entries.length ? entries[e + 1].firstChunk - 1 : totalChunks;
    for (int c = firstChunk; c <= lastChunk && c <= totalChunks; c++) {
      if (c >= 1) result[c - 1] = entries[e].samplesPerChunk;
    }
  }
  return result;
}

/// Walks chunks in order, laying consecutive samples out from each chunk's
/// file offset (samples within a chunk are contiguous, each occupying
/// [sampleSizes] bytes), to get every sample's absolute file offset.
List<int> _computeSampleOffsets(
  List<int> chunkOffsets,
  List<int> samplesPerChunkByChunk,
  List<int> sampleSizes,
) {
  final offsets = <int>[];
  int sampleIndex = 0;
  for (int c = 0; c < chunkOffsets.length; c++) {
    int running = chunkOffsets[c];
    final countInChunk =
        c < samplesPerChunkByChunk.length ? samplesPerChunkByChunk[c] : 0;
    for (int s = 0; s < countInChunk && sampleIndex < sampleSizes.length; s++) {
      offsets.add(running);
      running += sampleSizes[sampleIndex];
      sampleIndex++;
    }
  }
  return offsets;
}

/// A chapter-track sample: a big-endian u16 length, then the title —
/// UTF-8, or UTF-16 (either endianness) when it starts with a BOM.
Future<String> _readTextSample(
    RandomAccessFile raf, int offset, int size) async {
  if (size < 2) return '';
  final lenBytes = await _readAt(raf, offset, 2);
  if (lenBytes.length < 2) return '';
  final len = (lenBytes[0] << 8) | lenBytes[1];
  final available = size - 2;
  final readLen = len > available ? available : len;
  if (readLen <= 0) return '';

  final bytes = await _readAt(raf, offset + 2, readLen);
  if (bytes.length >= 2 &&
      ((bytes[0] == 0xFE && bytes[1] == 0xFF) ||
          (bytes[0] == 0xFF && bytes[1] == 0xFE))) {
    final bigEndian = bytes[0] == 0xFE;
    final codeUnits = <int>[];
    for (int i = 2; i + 1 < bytes.length; i += 2) {
      codeUnits.add(bigEndian
          ? (bytes[i] << 8) | bytes[i + 1]
          : (bytes[i + 1] << 8) | bytes[i]);
    }
    try {
      return String.fromCharCodes(codeUnits);
    } catch (_) {
      return '';
    }
  }

  try {
    return utf8.decode(bytes);
  } catch (_) {
    return '';
  }
}
