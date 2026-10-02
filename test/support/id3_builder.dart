import 'dart:convert';
import 'dart:typed_data';

/// Byte-level builders for synthetic ID3v2 fixtures, used by
/// `test/core/utils/id3_metadata_test.dart`. No real MP3/image data — just
/// enough of the tag structure to exercise `readId3Metadata`.

List<int> _syncsafe(int value) {
  return [
    (value >> 21) & 0x7f,
    (value >> 14) & 0x7f,
    (value >> 7) & 0x7f,
    value & 0x7f,
  ];
}

List<int> _u32(int value) {
  final b = ByteData(4)..setUint32(0, value, Endian.big);
  return b.buffer.asUint8List();
}

List<int> _u24(int value) {
  return [(value >> 16) & 0xFF, (value >> 8) & 0xFF, value & 0xFF];
}

/// A synthetic JPEG: magic bytes + filler.
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

/// A v2.3/v2.4 text frame (`TIT2`/`TALB`/`TPE1`/`TPE2`), UTF-8 encoded
/// (encoding byte 3, v2.4-only, but the reader accepts it in either).
List<int> textFrameV3(String id, String text, {int majorVersion = 3}) {
  final body = [3, ...utf8.encode(text)]; // encoding 3 = UTF-8
  final size = majorVersion == 4 ? _syncsafe(body.length) : _u32(body.length);
  return [...ascii.encode(id), ...size, 0, 0, ...body];
}

/// A v2.2 text frame (`TT2`/`TAL`/`TP1`/`TP2`), Latin-1 encoded.
List<int> textFrameV2(String id, String text) {
  final body = [0, ...latin1.encode(text)]; // encoding 0 = Latin-1
  return [...ascii.encode(id), ..._u24(body.length), ...body];
}

/// A v2.3/v2.4 `APIC` frame: encoding(0) + mime(null-terminated) +
/// pictureType(3=cover front) + description(null-terminated) + image.
List<int> apicFrame(List<int> imageBytes,
    {String mime = 'image/jpeg', int majorVersion = 3}) {
  final body = [
    0, // encoding: latin1
    ...latin1.encode(mime), 0, // mime, null-terminated
    3, // picture type: cover (front)
    0, // description, empty + null terminator
    ...imageBytes,
  ];
  final size = majorVersion == 4 ? _syncsafe(body.length) : _u32(body.length);
  return [...ascii.encode('APIC'), ...size, 0, 0, ...body];
}

/// A v2.2 `PIC` frame: encoding(0) + format(3, ascii) + pictureType(3) +
/// description(null-terminated) + image.
List<int> picFrameV2(List<int> imageBytes, {String format = 'JPG'}) {
  final body = [
    0,
    ...ascii.encode(format),
    3,
    0,
    ...imageBytes,
  ];
  return [...ascii.encode('PIC'), ..._u24(body.length), ...body];
}

/// Assembles a full ID3v2 tag (header + frames) prefixed onto a few bytes
/// of fake "audio" payload, matching how a real MP3 lays out its tag
/// before the audio frames.
Uint8List buildMp3WithId3(List<List<int>> frames,
    {int majorVersion = 3, List<int>? audioPayload}) {
  final frameBytes = <int>[for (final f in frames) ...f];
  final header = [
    ...ascii.encode('ID3'),
    majorVersion, 0, // version
    0, // flags
    ..._syncsafe(frameBytes.length),
  ];
  return Uint8List.fromList([
    ...header,
    ...frameBytes,
    ...(audioPayload ?? const [0xFF, 0xFB, 0, 0])
  ]);
}
