import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'local_media_metadata.dart';

/// Reads embedded cover art and title/author tags out of an MP3's ID3v2 tag
/// (v2.2's `PIC`/`TT2`/`TAL`/`TP1`/`TP2`, and v2.3/v2.4's `APIC`/`TIT2`/
/// `TALB`/`TPE1`/`TPE2`), without loading the whole file into memory — only
/// the tag itself (usually a few KB to a few hundred KB for a large cover)
/// is ever read off disk.
///
/// Pure Dart, `RandomAccessFile`-based, never throws — returns `null` on
/// any failure (no `ID3` header, truncated tag, unsupported version, etc).
Future<LocalMediaMetadata?> readId3Metadata(String path) async {
  RandomAccessFile? raf;
  try {
    raf = await File(path).open();
    final length = await raf.length();
    if (length < 10) return null;

    await raf.setPosition(0);
    final header = await raf.read(10);
    if (header.length < 10 ||
            header[0] != 0x49 || // 'I'
            header[1] != 0x44 || // 'D'
            header[2] != 0x33 // '3'
        ) {
      return null;
    }

    final majorVersion = header[3];
    if (majorVersion < 2 || majorVersion > 4) return null;
    final flags = header[5];
    final tagSize = _syncsafe(header, 6);
    final tagEnd = 10 + tagSize;
    if (tagEnd > length) return null;

    int pos = 10;

    // Extended header (v2.3+ only), flagged by bit 6. Its own size field
    // tells us how far to skip; best-effort — if it looks malformed, just
    // give up on the whole tag rather than guessing.
    if (majorVersion >= 3 && (flags & 0x40) != 0) {
      if (pos + 4 > tagEnd) return null;
      await raf.setPosition(pos);
      final extHeader = await raf.read(4);
      if (extHeader.length < 4) return null;
      final extSize =
          majorVersion == 4 ? _syncsafe(extHeader, 0) : _readU32(extHeader, 0);
      // v2.3's extended header size does not include the 4 size bytes
      // themselves; v2.4's does.
      pos += majorVersion == 4 ? extSize : 4 + extSize;
      if (pos > tagEnd) return null;
    }

    Uint8List? coverBytes;
    String? coverMime;
    String? title;
    String? album;
    String? artist;
    String? albumArtist;

    final isV2 = majorVersion == 2;
    final frameHeaderLen = isV2 ? 6 : 10;

    while (pos + frameHeaderLen <= tagEnd) {
      await raf.setPosition(pos);
      final fh = await raf.read(frameHeaderLen);
      if (fh.length < frameHeaderLen) break;

      final String frameId;
      final int frameSize;
      if (isV2) {
        frameId = _ascii(fh, 0, 3);
        frameSize = _readU24(fh, 3);
      } else {
        frameId = _ascii(fh, 0, 4);
        frameSize = majorVersion == 4 ? _syncsafe(fh, 4) : _readU32(fh, 4);
      }

      if (frameId.isEmpty || frameId.codeUnits.any((c) => c == 0)) {
        break; // padding
      }
      final frameDataStart = pos + frameHeaderLen;
      if (frameSize <= 0 || frameDataStart + frameSize > tagEnd) break;

      final isTextFrame = isV2
          ? const {'TT2', 'TAL', 'TP1', 'TP2'}.contains(frameId)
          : const {'TIT2', 'TALB', 'TPE1', 'TPE2'}.contains(frameId);
      final isPictureFrame = isV2 ? frameId == 'PIC' : frameId == 'APIC';

      if (isTextFrame || isPictureFrame) {
        await raf.setPosition(frameDataStart);
        final data = await raf.read(frameSize);
        if (data.length == frameSize) {
          if (isTextFrame) {
            final text = _decodeText(data);
            if (text != null && text.trim().isNotEmpty) {
              final trimmed = text.trim();
              switch (frameId) {
                case 'TT2':
                case 'TIT2':
                  title = trimmed;
                  break;
                case 'TAL':
                case 'TALB':
                  album = trimmed;
                  break;
                case 'TP1':
                case 'TPE1':
                  artist = trimmed;
                  break;
                case 'TP2':
                case 'TPE2':
                  albumArtist = trimmed;
                  break;
              }
            }
          } else {
            final pic = isV2 ? _decodeV22Picture(data) : _decodeApic(data);
            if (pic != null) {
              coverBytes = pic.$1;
              coverMime = pic.$2;
            }
          }
        }
      }

      pos = frameDataStart + frameSize;
    }

    final resolvedTitle = (album?.isNotEmpty ?? false) ? album : title;
    final resolvedAuthor =
        (albumArtist?.isNotEmpty ?? false) ? albumArtist : artist;

    final result = LocalMediaMetadata(
      title: resolvedTitle,
      author: resolvedAuthor,
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

/// `encoding(1) + mimeType(null-terminated latin1) + pictureType(1) +
/// description(null-terminated, per-encoding) + image bytes`.
(Uint8List, String)? _decodeApic(Uint8List data) {
  if (data.isEmpty) return null;
  final encoding = data[0];
  int i = 1;
  final mimeEnd = _findTerminator(data, i, wide: false);
  if (mimeEnd >= data.length) return null;
  final mime = _tryLatin1(data, i, mimeEnd);
  i = mimeEnd + 1;
  if (i >= data.length) return null;
  i += 1; // picture type byte
  final descEnd =
      _findTerminator(data, i, wide: encoding == 1 || encoding == 2);
  if (descEnd > data.length) return null;
  i = descEnd + (encoding == 1 || encoding == 2 ? 2 : 1);
  if (i > data.length) return null;
  final imageBytes = data.sublist(i);
  if (imageBytes.isEmpty) return null;
  final resolvedMime = (mime != null && mime.startsWith('image/'))
      ? mime
      : _sniffImageMime(imageBytes);
  if (resolvedMime == null) return null;
  return (imageBytes, resolvedMime);
}

/// v2.2 `PIC`: `encoding(1) + imageFormat(3, ascii "JPG"/"PNG") +
/// pictureType(1) + description(null-terminated, per-encoding) + image
/// bytes`.
(Uint8List, String)? _decodeV22Picture(Uint8List data) {
  if (data.length < 5) return null;
  final encoding = data[0];
  final format = _ascii(data, 1, 3).toUpperCase();
  int i = 4; // picture type byte
  i += 1;
  final descEnd =
      _findTerminator(data, i, wide: encoding == 1 || encoding == 2);
  if (descEnd > data.length) return null;
  i = descEnd + (encoding == 1 || encoding == 2 ? 2 : 1);
  if (i > data.length) return null;
  final imageBytes = data.sublist(i);
  if (imageBytes.isEmpty) return null;
  String? mime;
  if (format == 'JPG' || format == 'JPEG') mime = 'image/jpeg';
  if (format == 'PNG') mime = 'image/png';
  mime ??= _sniffImageMime(imageBytes);
  if (mime == null) return null;
  return (imageBytes, mime);
}

int _findTerminator(Uint8List data, int start, {required bool wide}) {
  if (wide) {
    int i = start;
    while (i + 1 < data.length) {
      if (data[i] == 0 && data[i + 1] == 0) return i;
      i += 2;
    }
    return data.length;
  }
  for (int i = start; i < data.length; i++) {
    if (data[i] == 0) return i;
  }
  return data.length;
}

String? _tryLatin1(Uint8List data, int start, int end) {
  if (start > end || end > data.length) return null;
  try {
    return latin1.decode(data.sublist(start, end));
  } catch (_) {
    return null;
  }
}

/// Decodes a text frame's body: encoding byte 0-3, then the string.
String? _decodeText(Uint8List data) {
  if (data.isEmpty) return null;
  final encoding = data[0];
  final body = data.sublist(1);
  try {
    switch (encoding) {
      case 0: // ISO-8859-1
        return _stripTrailingNulls(latin1.decode(body));
      case 1: // UTF-16 with BOM
        return _decodeUtf16(body, hasBom: true);
      case 2: // UTF-16BE, no BOM (v2.4 only)
        return _decodeUtf16(body, hasBom: false, bigEndianDefault: true);
      case 3: // UTF-8 (v2.4 only)
        return _stripTrailingNulls(utf8.decode(body));
      default:
        return _stripTrailingNulls(latin1.decode(body));
    }
  } catch (_) {
    return null;
  }
}

String _stripTrailingNulls(String s) {
  var end = s.length;
  while (end > 0 && s.codeUnitAt(end - 1) == 0) {
    end--;
  }
  return s.substring(0, end);
}

String? _decodeUtf16(Uint8List body,
    {required bool hasBom, bool bigEndianDefault = false}) {
  if (body.isEmpty) return '';
  int start = 0;
  bool bigEndian = bigEndianDefault;
  if (hasBom && body.length >= 2) {
    if (body[0] == 0xFE && body[1] == 0xFF) {
      bigEndian = true;
      start = 2;
    } else if (body[0] == 0xFF && body[1] == 0xFE) {
      bigEndian = false;
      start = 2;
    }
  }
  final units = <int>[];
  for (int i = start; i + 1 < body.length; i += 2) {
    final unit =
        bigEndian ? (body[i] << 8) | body[i + 1] : (body[i + 1] << 8) | body[i];
    if (unit == 0) break; // null terminator
    units.add(unit);
  }
  try {
    return String.fromCharCodes(units);
  } catch (_) {
    return null;
  }
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

String _ascii(Uint8List data, int offset, int len) {
  if (offset + len > data.length) return '';
  return String.fromCharCodes(data.sublist(offset, offset + len));
}

int _syncsafe(Uint8List data, int offset) {
  return ((data[offset] & 0x7f) << 21) |
      ((data[offset + 1] & 0x7f) << 14) |
      ((data[offset + 2] & 0x7f) << 7) |
      (data[offset + 3] & 0x7f);
}

int _readU24(Uint8List data, int offset) {
  return (data[offset] << 16) | (data[offset + 1] << 8) | data[offset + 2];
}

int _readU32(Uint8List data, int offset) {
  return ByteData.sublistView(data, offset, offset + 4)
      .getUint32(0, Endian.big);
}
