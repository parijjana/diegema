import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'local_media_metadata.dart';

/// Reads embedded cover art and title/author tags out of an MP4/M4B/M4A
/// file's `moov/udta/meta/ilst` atom tree, without ever loading the whole
/// file into memory.
///
/// This is a separate, self-contained atom walker rather than a reuse of
/// `mp4_chapters.dart`'s — that one only ever descends into `moov`/`trak`,
/// never into `udta/meta`, and its atom-walking helpers are private. The
/// walking logic below is deliberately the same shape (same size/type
/// header handling, same "never throws" contract) so the two stay easy to
/// compare, but each file owns its own copy.
///
/// Pure Dart, `RandomAccessFile`-based, never throws — returns `null` on
/// any failure (not an MP4, truncated, no `ilst`, etc).
Future<LocalMediaMetadata?> readMp4Metadata(String path) async {
  RandomAccessFile? raf;
  try {
    raf = await File(path).open();
    final length = await raf.length();
    final topAtoms = await _readAtoms(raf, 0, length);
    final moov = _firstOfType(topAtoms, 'moov');
    if (moov == null) return null;

    final moovChildren = await _readAtoms(raf, moov.dataStart, moov.end);

    // `meta` normally lives under `udta`, but some encoders place it
    // directly under `moov` — check both.
    _Atom? meta;
    final udta = _firstOfType(moovChildren, 'udta');
    if (udta != null) {
      final udtaChildren = await _readAtoms(raf, udta.dataStart, udta.end);
      meta = _firstOfType(udtaChildren, 'meta');
    }
    meta ??= _firstOfType(moovChildren, 'meta');
    if (meta == null) return null;

    // `meta` is a full box: 4 bytes of version+flags before its children.
    final metaChildStart = meta.dataStart + 4;
    if (metaChildStart > meta.end) return null;
    final metaChildren = await _readAtoms(raf, metaChildStart, meta.end);
    final ilst = _firstOfType(metaChildren, 'ilst');
    if (ilst == null) return null;

    final ilstChildren = await _readAtoms(raf, ilst.dataStart, ilst.end);

    Uint8List? coverBytes;
    String? coverMime;
    String? name;
    String? album;
    String? artist;
    String? albumArtist;
    String? description;

    for (final child in ilstChildren) {
      final childChildren = await _readAtoms(raf, child.dataStart, child.end);
      final data = _firstOfType(childChildren, 'data');
      if (data == null) continue;

      // `data`'s payload: 4-byte well-known type, 4-byte locale, then the
      // content — image bytes for `covr`, UTF-8 text for everything else.
      final contentStart = data.dataStart + 8;
      if (contentStart > data.end) continue;
      final contentLen = data.end - contentStart;

      if (child.type == 'covr') {
        final typeHeader = await _readAt(raf, data.dataStart, 4);
        final typeCode = typeHeader.length == 4 ? _readU32(typeHeader, 0) : 0;
        final bytes = await _readAt(raf, contentStart, contentLen);
        if (bytes.isEmpty) continue;
        final mime = _coverMime(typeCode, bytes);
        if (mime != null) {
          coverBytes = bytes;
          coverMime = mime;
        }
      } else if (_textAtomTypes.contains(child.type)) {
        final bytes = await _readAt(raf, contentStart, contentLen);
        String text;
        try {
          text = utf8.decode(bytes);
        } catch (_) {
          continue;
        }
        text = text.trim();
        if (text.isEmpty) continue;
        switch (child.type) {
          case '©nam':
            name = text;
            break;
          case '©alb':
            album = text;
            break;
          case '©ART':
            artist = text;
            break;
          case 'aART':
            albumArtist = text;
            break;
          case '©cmt':
          case 'desc':
            description ??= text;
            break;
        }
      }
    }

    final title = (album?.isNotEmpty ?? false) ? album : name;
    final author = (albumArtist?.isNotEmpty ?? false) ? albumArtist : artist;

    final result = LocalMediaMetadata(
      title: title,
      author: author,
      description: description,
      coverBytes: coverBytes,
      coverMime: coverMime,
    );
    return result.isEmpty ? null : result;
  } catch (_) {
    return null;
  } finally {
    try {
      await raf?.close();
    } catch (_) {}
  }
}

const _textAtomTypes = {'©nam', '©alb', '©ART', 'aART', '©cmt', 'desc'};

/// Maps a `covr` `data` atom's well-known type code to a MIME type: 13 =
/// JPEG, 14 = PNG, 0 (or anything else) = sniff the magic bytes.
String? _coverMime(int typeCode, Uint8List bytes) {
  if (typeCode == 13) return 'image/jpeg';
  if (typeCode == 14) return 'image/png';
  return _sniffImageMime(bytes);
}

String? _sniffImageMime(Uint8List bytes) {
  if (bytes.length >= 3 &&
      bytes[0] == 0xFF &&
      bytes[1] == 0xD8 &&
      bytes[2] == 0xFF) {
    return 'image/jpeg';
  }
  if (bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47) {
    return 'image/png';
  }
  return null;
}

// --- Atom tree (self-contained copy — see file doc comment) ---------------

class _Atom {
  final String type;
  final int start;
  final int end;
  final int dataStart;

  const _Atom(this.type, this.start, this.end, this.dataStart);
}

Future<List<_Atom>> _readAtoms(
    RandomAccessFile raf, int start, int end) async {
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
