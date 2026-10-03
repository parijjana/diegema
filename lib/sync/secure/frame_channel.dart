import 'dart:async';
import 'dart:typed_data';

/// A message-oriented pipe between two devices. TCP is a byte stream, so
/// [LengthPrefixedChannel] cuts it into frames; tests use [memoryChannelPair].
abstract class FrameChannel {
  /// The next whole frame. Throws [ChannelClosed] when the other side has
  /// gone and nothing is left.
  Future<Uint8List> read();

  void write(List<int> frame);

  Future<void> close();
}

class ChannelClosed implements Exception {
  const ChannelClosed();
  @override
  String toString() => 'ChannelClosed';
}

class FrameTooLarge implements Exception {
  final int length;
  const FrameTooLarge(this.length);
  @override
  String toString() => 'FrameTooLarge($length)';
}

/// Frames as a 4-byte big-endian length followed by that many bytes.
class LengthPrefixedChannel implements FrameChannel {
  /// Far above any sync message; stops a stranger making us allocate
  /// gigabytes with one forged length.
  static const defaultMaxFrame = 16 * 1024 * 1024;

  final StreamSink<List<int>> _out;
  final int maxFrame;
  late final StreamSubscription<List<int>> _sub;

  // Unread bytes are _buf[_start, _end); appends grow it by doubling and
  // compact first, so a big frame in small chunks is copied O(n) times.
  Uint8List _buf = Uint8List(4096);
  int _start = 0;
  int _end = 0;
  final _frames = <Uint8List>[];
  final _waiting = <Completer<Uint8List>>[];
  Object? _error;
  bool _done = false;

  LengthPrefixedChannel(Stream<List<int>> input, this._out,
      {this.maxFrame = defaultMaxFrame}) {
    _sub = input.listen(_onData, onError: _fail, onDone: () {
      _done = true;
      _flushWaiters();
    });
  }

  void _append(List<int> chunk) {
    if (_end + chunk.length > _buf.length) {
      final live = _end - _start;
      var size = _buf.length;
      while (size < live + chunk.length) {
        size *= 2;
      }
      final grown = size == _buf.length ? _buf : Uint8List(size);
      grown.setRange(0, live, _buf, _start);
      _buf = grown;
      _start = 0;
      _end = live;
    }
    _buf.setRange(_end, _end + chunk.length, chunk);
    _end += chunk.length;
  }

  void _onData(List<int> chunk) {
    if (_error != null) return;
    _append(chunk);
    while (_end - _start >= 4) {
      final length = ByteData.sublistView(_buf, _start, _start + 4)
          .getUint32(0, Endian.big);
      if (length > maxFrame) {
        _fail(FrameTooLarge(length));
        return;
      }
      if (_end - _start - 4 < length) break;
      _frames.add(Uint8List.fromList(
          Uint8List.sublistView(_buf, _start + 4, _start + 4 + length)));
      _start += 4 + length;
    }
    if (_start == _end) _start = _end = 0;
    _flushWaiters();
  }

  void _fail(Object error) {
    _error ??= error;
    _sub.cancel();
    _flushWaiters();
  }

  void _flushWaiters() {
    while (_waiting.isNotEmpty && _frames.isNotEmpty) {
      _waiting.removeAt(0).complete(_frames.removeAt(0));
    }
    if (_frames.isEmpty && (_error != null || _done)) {
      for (final w in _waiting) {
        w.completeError(_error ?? const ChannelClosed());
      }
      _waiting.clear();
    }
  }

  @override
  Future<Uint8List> read() {
    if (_frames.isNotEmpty) return Future.value(_frames.removeAt(0));
    if (_error != null) return Future.error(_error!);
    if (_done) return Future.error(const ChannelClosed());
    final c = Completer<Uint8List>();
    _waiting.add(c);
    return c.future;
  }

  @override
  void write(List<int> frame) {
    final header = ByteData(4)..setUint32(0, frame.length, Endian.big);
    _out.add([...header.buffer.asUint8List(), ...frame]);
  }

  @override
  Future<void> close() async {
    await _sub.cancel();
    _done = true;
    _flushWaiters();
    try {
      await _out.close();
    } catch (_) {
      // Already closed by the other side.
    }
  }
}

/// Two channels wired to each other through the real framing code.
(FrameChannel, FrameChannel) memoryChannelPair() {
  // Closed through each channel's close().
  // ignore: close_sinks
  final aToB = StreamController<List<int>>();
  // ignore: close_sinks
  final bToA = StreamController<List<int>>();
  return (
    LengthPrefixedChannel(bToA.stream, aToB.sink),
    LengthPrefixedChannel(aToB.stream, bToA.sink),
  );
}
