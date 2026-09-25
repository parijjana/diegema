import 'dart:convert';
import 'dart:typed_data';

/// Byte-level builders for synthetic MP4/M4B fixtures, used by
/// `test/core/utils/mp4_chapters_test.dart`. There is no ffmpeg in this
/// environment, so these hand-assemble just enough of the atom tree —
/// `ftyp`/`moov`/`mvhd`/`udta`/`chpl` and, for the QuickTime-track cases,
/// `trak`/`tkhd`/`tref`/`mdia`/`hdlr`/`mdhd`/`minf`/`stbl`/`stts`/`stsz`/
/// `stsc`/`stco`/`mdat` — to exercise `readMp4Chapters` without any real
/// audio data.

List<int> u8(int v) => [v & 0xFF];

List<int> u16(int v) {
  final b = ByteData(2)..setUint16(0, v, Endian.big);
  return b.buffer.asUint8List();
}

List<int> u32(int v) {
  final b = ByteData(4)..setUint32(0, v, Endian.big);
  return b.buffer.asUint8List();
}

List<int> u64(int v) {
  final b = ByteData(8)..setUint64(0, v, Endian.big);
  return b.buffer.asUint8List();
}

List<int> fourcc(String type) => ascii.encode(type);

/// A normal atom: 32-bit size + 4-byte type + payload.
List<int> atom(String type, List<int> payload) {
  return [...u32(8 + payload.length), ...fourcc(type), ...payload];
}

/// An atom written with the 64-bit extended-size form (`size == 1`,
/// followed by an 8-byte real size) — exercises that path in `_readAtoms`.
List<int> atom64(String type, List<int> payload) {
  final size = 16 + payload.length;
  return [...u32(1), ...fourcc(type), ...u64(size), ...payload];
}

List<int> container(String type, List<List<int>> children) {
  final payload = <int>[];
  for (final c in children) {
    payload.addAll(c);
  }
  return atom(type, payload);
}

List<int> fullBoxHeader({int version = 0, int flags = 0}) =>
    [version, (flags >> 16) & 0xFF, (flags >> 8) & 0xFF, flags & 0xFF];

List<int> ftyp() =>
    atom('ftyp', [...fourcc('M4B '), ...u32(0), ...fourcc('M4B '), ...fourcc('isom')]);

/// `moov/mvhd`. [durationTicks] is in [timescale] units.
List<int> mvhd({
  int version = 0,
  required int timescale,
  required int durationTicks,
}) {
  if (version == 1) {
    return atom('mvhd', [
      ...fullBoxHeader(version: 1),
      ...u64(0), // creation_time
      ...u64(0), // modification_time
      ...u32(timescale),
      ...u64(durationTicks),
    ]);
  }
  return atom('mvhd', [
    ...fullBoxHeader(),
    ...u32(0), // creation_time
    ...u32(0), // modification_time
    ...u32(timescale),
    ...u32(durationTicks),
  ]);
}

/// A chapter marker used to build a `chpl` atom or a QuickTime chapter
/// track's samples.
class ChapterFixture {
  final String title;
  final int startMs;
  const ChapterFixture(this.title, this.startMs);
}

/// `moov/udta/chpl` (Nero format): version(1) + reserved(4) + count(1),
/// then per entry a u64 start in 100ns units, a u8 title length, and the
/// title bytes.
List<int> chpl(List<ChapterFixture> chapters) {
  final payload = <int>[
    ...u8(1), // version
    0, 0, 0, 0, // reserved
    ...u8(chapters.length),
  ];
  for (final c in chapters) {
    final titleBytes = utf8.encode(c.title);
    payload
      ..addAll(u64(c.startMs * 10000)) // ms -> 100ns units
      ..addAll(u8(titleBytes.length))
      ..addAll(titleBytes);
  }
  return atom('chpl', payload);
}

/// `trak/tkhd`, just enough to carry the track ID.
List<int> tkhd({int version = 0, required int trackId}) {
  if (version == 1) {
    return atom('tkhd', [
      ...fullBoxHeader(version: 1),
      ...u64(0), ...u64(0),
      ...u32(trackId),
    ]);
  }
  return atom('tkhd', [
    ...fullBoxHeader(),
    ...u32(0), ...u32(0),
    ...u32(trackId),
  ]);
}

/// `trak/tref/chap`, referencing [chapterTrackId].
List<int> tref({required int chapterTrackId}) {
  final chap = atom('chap', u32(chapterTrackId));
  return container('tref', [chap]);
}

/// `trak/mdia/hdlr`, carrying [handlerType] (`'text'`, `'sbtl'`, `'soun'`).
List<int> hdlr(String handlerType) {
  return atom('hdlr', [
    ...fullBoxHeader(),
    ...u32(0), // pre_defined
    ...fourcc(handlerType),
    ...List.filled(12, 0), // reserved
    0, // empty name (single null terminator)
  ]);
}

/// `trak/mdia/mdhd`.
List<int> mdhd({int version = 0, required int timescale}) {
  if (version == 1) {
    return atom('mdhd', [
      ...fullBoxHeader(version: 1),
      ...u64(0), ...u64(0),
      ...u32(timescale),
      ...u64(0), // duration, unused by the reader
    ]);
  }
  return atom('mdhd', [
    ...fullBoxHeader(),
    ...u32(0), ...u32(0),
    ...u32(timescale),
    ...u32(0),
  ]);
}

/// `stbl/stts`: a single (sampleCount, sampleDelta) run for every marker,
/// so each chapter sample lands at its own exact tick offset.
List<int> stts(List<int> sampleDeltasTicks) {
  final payload = <int>[...fullBoxHeader(), ...u32(sampleDeltasTicks.length)];
  for (final delta in sampleDeltasTicks) {
    payload
      ..addAll(u32(1)) // sample_count
      ..addAll(u32(delta)); // sample_delta
  }
  return atom('stts', payload);
}

/// `stbl/stsz`, one entry per sample (never the fixed-size form, since
/// title samples vary in length).
List<int> stsz(List<int> sampleSizes) {
  final payload = <int>[
    ...fullBoxHeader(),
    ...u32(0), // sample_size == 0 -> per-sample array follows
    ...u32(sampleSizes.length),
  ];
  for (final size in sampleSizes) {
    payload.addAll(u32(size));
  }
  return atom('stsz', payload);
}

/// `stbl/stsc`: one sample per chunk, for every chunk (the common case for
/// a small text track) — a single entry covering chunk 1 onward is enough
/// to say that.
List<int> stscOneSamplePerChunk() {
  final payload = <int>[...fullBoxHeader(), ...u32(1)];
  payload
    ..addAll(u32(1)) // first_chunk
    ..addAll(u32(1)) // samples_per_chunk
    ..addAll(u32(1)); // sample_description_index
  return atom('stsc', payload);
}

/// `stbl/stco` (32-bit chunk offsets).
List<int> stco(List<int> chunkOffsets) {
  final payload = <int>[...fullBoxHeader(), ...u32(chunkOffsets.length)];
  for (final offset in chunkOffsets) {
    payload.addAll(u32(offset));
  }
  return atom('stco', payload);
}

/// A chapter-track sample: a big-endian u16 length, then the title bytes.
/// [utf16] writes a BOM-prefixed UTF-16BE title instead of UTF-8.
List<int> chapterTextSample(String title, {bool utf16 = false}) {
  final List<int> titleBytes;
  if (utf16) {
    titleBytes = [0xFE, 0xFF]; // BOM, big-endian
    for (final unit in title.codeUnits) {
      titleBytes.addAll(u16(unit));
    }
  } else {
    titleBytes = utf8.encode(title);
  }
  return [...u16(titleBytes.length), ...titleBytes];
}

/// Assembles a full synthetic M4B: `ftyp`, an `mdat` holding the chapter
/// track's text samples back-to-back, then `moov` with an audio `trak`
/// (referencing the chapter track via `tref/chap`) and a chapter `trak`
/// (`hdlr` type `text`, timed via `stts`, located via `stsz`/`stsc`/`stco`
/// pointing into `mdat`).
///
/// [audioTrackId]/[chapterTrackId] just need to be distinct positive
/// integers; [use64BitAtom] wraps the `moov` atom in the 64-bit extended
/// size form instead of the normal 32-bit one.
Uint8List buildQuickTimeChapterM4b({
  required List<ChapterFixture> chapters,
  int timescale = 1000,
  int audioDurationMs = 60000,
  int audioTrackId = 1,
  int chapterTrackId = 2,
  bool use64BitAtom = false,
  bool utf16Titles = false,
  String chapterHandlerType = 'text',
  List<ChapterFixture>? alsoChpl,
}) {
  final head = ftyp();

  // Chapter track samples, laid out back-to-back in mdat.
  final samples = [
    for (final c in chapters) chapterTextSample(c.title, utf16: utf16Titles)
  ];
  final sampleSizes = [for (final s in samples) s.length];
  final mdatPayload = <int>[for (final s in samples) ...s];
  final mdat = atom('mdat', mdatPayload);

  final mdatDataStart = head.length + 8; // past ftyp + mdat's own header
  final chunkOffsets = <int>[];
  var running = mdatDataStart;
  for (final size in sampleSizes) {
    chunkOffsets.add(running);
    running += size;
  }

  // Sample deltas in the chapter track's own timescale: each marker's tick
  // is derived from the *next* marker's startMs (or the audio duration for
  // the last one), so stts's cumulative sum reproduces the fixture's
  // startMs values exactly.
  final deltas = <int>[];
  for (int i = 0; i < chapters.length; i++) {
    final nextMs =
        i + 1 < chapters.length ? chapters[i + 1].startMs : audioDurationMs;
    final deltaMs = nextMs - chapters[i].startMs;
    deltas.add((deltaMs * timescale) ~/ 1000);
  }

  final chapterTrak = container('trak', [
    tkhd(trackId: chapterTrackId),
    container('mdia', [
      mdhd(timescale: timescale),
      hdlr(chapterHandlerType),
      container('minf', [
        container('stbl', [
          stts(deltas),
          stsz(sampleSizes),
          stscOneSamplePerChunk(),
          stco(chunkOffsets),
        ]),
      ]),
    ]),
  ]);

  final audioTrak = container('trak', [
    tkhd(trackId: audioTrackId),
    tref(chapterTrackId: chapterTrackId),
  ]);

  final moovChildren = [
    mvhd(timescale: timescale, durationTicks: (audioDurationMs * timescale) ~/ 1000),
    audioTrak,
    chapterTrak,
    if (alsoChpl != null) container('udta', [chpl(alsoChpl)]),
  ];
  final moov = use64BitAtom
      ? atom64('moov', [for (final c in moovChildren) ...c])
      : container('moov', moovChildren);

  return Uint8List.fromList([...head, ...mdat, ...moov]);
}

/// A file with only a Nero `chpl` chapter list — no QuickTime chapter
/// track at all.
Uint8List buildChplOnlyM4b({
  required List<ChapterFixture> chapters,
  int timescale = 1000,
  int audioDurationMs = 60000,
  bool use64BitMoov = false,
}) {
  final head = ftyp();
  final moovChildren = [
    mvhd(timescale: timescale, durationTicks: (audioDurationMs * timescale) ~/ 1000),
    container('udta', [chpl(chapters)]),
  ];
  final moov = use64BitMoov
      ? atom64('moov', [for (final c in moovChildren) ...c])
      : container('moov', moovChildren);
  return Uint8List.fromList([...head, ...moov]);
}

/// A well-formed audio-only M4B with no chapter data of either kind.
Uint8List buildNoChaptersM4b({
  int timescale = 1000,
  int audioDurationMs = 60000,
}) {
  final head = ftyp();
  final moov = container('moov', [
    mvhd(timescale: timescale, durationTicks: (audioDurationMs * timescale) ~/ 1000),
  ]);
  return Uint8List.fromList([...head, ...moov]);
}

// --- iTunes-style metadata (moov/udta/meta/ilst) --------------------------
// Used by `test/core/utils/mp4_metadata_test.dart`.

/// A synthetic (not-a-real-image) JPEG: just the magic bytes plus filler,
/// enough for the sniffer and for a round-trip byte-equality check.
Uint8List syntheticJpegBytes({int size = 64}) {
  final bytes = Uint8List(size);
  bytes[0] = 0xFF;
  bytes[1] = 0xD8;
  bytes[2] = 0xFF;
  for (int i = 3; i < size; i++) {
    bytes[i] = i % 256;
  }
  return bytes;
}

/// A synthetic (not-a-real-image) PNG: just the magic bytes plus filler.
Uint8List syntheticPngBytes({int size = 64}) {
  final bytes = Uint8List(size);
  bytes[0] = 0x89;
  bytes[1] = 0x50;
  bytes[2] = 0x4E;
  bytes[3] = 0x47;
  for (int i = 4; i < size; i++) {
    bytes[i] = i % 256;
  }
  return bytes;
}

/// An iTunes-style `data` atom: 4-byte well-known type + 4-byte locale +
/// content.
List<int> ilstData(int typeCode, List<int> content) {
  return atom('data', [...u32(typeCode), ...u32(0), ...content]);
}

/// An `ilst`-child atom whose fourcc may contain a copyright sign (`©nam`,
/// `©alb`, `©ART`) — `fourcc()`/`atom()` use `ascii.encode`, which rejects
/// that byte (0xA9), so this writes the type bytes directly via
/// `latin1.encode` instead.
List<int> _ilstAtom(String type, List<int> payload) {
  final typeBytes = latin1.encode(type);
  return [...u32(8 + payload.length), ...typeBytes, ...payload];
}

/// A text `ilst` child (e.g. `©nam`, `©alb`, `©ART`, `aART`), type code 1 =
/// UTF-8.
List<int> ilstText(String fourccType, String text) {
  return _ilstAtom(fourccType, [...ilstData(1, utf8.encode(text))]);
}

/// A `covr` `ilst` child. [typeCode] 13 = JPEG, 14 = PNG, 0 = sniff.
List<int> ilstCover(List<int> imageBytes, {int typeCode = 13}) {
  return _ilstAtom('covr', [...ilstData(typeCode, imageBytes)]);
}

/// `moov/udta/meta/ilst`, with `meta`'s 4-byte full-box header.
List<int> metaIlst(List<List<int>> ilstChildren) {
  final ilst = container('ilst', ilstChildren);
  return atom('meta', [...fullBoxHeader(), ...ilst]);
}

/// A full M4B with an embedded `moov/udta/meta/ilst` metadata block —
/// title/album/artist/album-artist tags and/or cover art — and no chapter
/// data.
Uint8List buildM4bWithMetadata({
  String? name,
  String? album,
  String? artist,
  String? albumArtist,
  List<int>? coverBytes,
  int coverTypeCode = 13,
  bool metaUnderMoovDirectly = false,
  int timescale = 1000,
  int audioDurationMs = 60000,
}) {
  final head = ftyp();
  final ilstChildren = <List<int>>[
    if (name != null) ilstText('©nam', name),
    if (album != null) ilstText('©alb', album),
    if (artist != null) ilstText('©ART', artist),
    if (albumArtist != null) ilstText('aART', albumArtist),
    if (coverBytes != null) ilstCover(coverBytes, typeCode: coverTypeCode),
  ];
  final meta = metaIlst(ilstChildren);
  final udta = container('udta', [meta]);

  final moovChildren = [
    mvhd(timescale: timescale, durationTicks: (audioDurationMs * timescale) ~/ 1000),
    if (metaUnderMoovDirectly) meta else udta,
  ];
  final moov = container('moov', moovChildren);
  return Uint8List.fromList([...head, ...moov]);
}
