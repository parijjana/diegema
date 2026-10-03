import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:diegema/sync/secure/auth_session.dart';
import 'package:diegema/sync/secure/frame_channel.dart';
import 'package:flutter_test/flutter_test.dart';

/// Repeatable "randomness": byte i of call k is a fixed function of a label.
List<int> Function(int) fixedRandom(int label) {
  var call = 0;
  return (n) {
    call++;
    return List<int>.generate(n, (i) => (label * 31 + call * 7 + i) & 0xff);
  };
}

final groupKey = List<int>.generate(32, (i) => i);
final otherKey = List<int>.filled(32, 9);

SessionConfig cfg(List<int> key, [int? label]) => SessionConfig(
    groupKey: key,
    randomBytes: label == null ? secureRandomBytes : fixedRandom(label));

/// Runs both sides and returns each side's failure (null when it succeeded).
Future<(HandshakeFailure?, HandshakeFailure?)> failures(
    SessionConfig i, SessionConfig r,
    {(FrameChannel, FrameChannel)? channels}) async {
  final (a, b) = channels ?? memoryChannelPair();
  Future<HandshakeFailure?> run(Future<AuthSession> f) async {
    try {
      await f;
      return null;
    } on HandshakeException catch (e) {
      return e.failure;
    }
  }

  final out = await Future.wait([
    run(AuthSession.initiate(a, i)),
    run(AuthSession.respond(b, r)),
  ]);
  return (out[0], out[1]);
}

Future<(AuthSession, AuthSession, _Tap)> tapped(
    {List<int>? iKey, int? iLabel, int? rLabel}) async {
  final (a, b) = memoryChannelPair();
  final tap = _Tap(a);
  final res = await Future.wait([
    AuthSession.initiate(tap, cfg(iKey ?? groupKey, iLabel)),
    AuthSession.respond(b, cfg(groupKey, rLabel)),
  ]);
  return (res[0], res[1], tap);
}

void main() {
  test('same group key: talk both ways, in order', () async {
    final (i, r, _) = await tapped();
    for (var n = 0; n < 3; n++) {
      await i.send(utf8.encode('to mac $n'));
      await r.send(utf8.encode('to phone $n'));
    }
    for (var n = 0; n < 3; n++) {
      expect(utf8.decode(await r.receive()), 'to mac $n');
      expect(utf8.decode(await i.receive()), 'to phone $n');
    }
    final big = Uint8List(1 << 20)..fillRange(0, 1 << 20, 7);
    await i.send(big);
    expect(await r.receive(), big);
  });

  test('a different group key fails on both sides', () async {
    // The responder proves itself first, so the initiator catches it.
    expect(await failures(cfg(otherKey), cfg(groupKey)),
        (HandshakeFailure.wrongKey, HandshakeFailure.closed));
  });

  test('an initiator without the key never gets a session', () async {
    // It can't produce M3, whatever it sends.
    final (a, b) = memoryChannelPair();
    final tap = _Tap(a);
    var frame = 0;
    tap.mutate = (f) {
      frame++;
      if (frame != 2) return f; // M3
      final m = jsonDecode(utf8.decode(f)) as Map<String, Object?>;
      m['a'] = base64Url.encode(List<int>.filled(32, 0));
      return Uint8List.fromList(utf8.encode(jsonEncode(m)));
    };
    final (_, fr) =
        await failures(cfg(groupKey), cfg(groupKey), channels: (tap, b));
    expect(fr, HandshakeFailure.wrongKey);
  });

  test('a recorded handshake replayed later is refused', () async {
    // Fresh responder nonce: the old M3 doesn't prove anything now.
    final (a, b) = memoryChannelPair();
    final rec = _Tap(a);
    final recorded = <Uint8List>[];
    rec.mutate = (f) {
      recorded.add(f);
      return f;
    };
    await Future.wait([
      AuthSession.initiate(rec, cfg(groupKey)),
      AuthSession.respond(b, cfg(groupKey)),
    ]);
    final (x, y) = memoryChannelPair();
    final victim = AuthSession.respond(y, cfg(groupKey));
    x.write(recorded[0]);
    await x.read(); // the victim's fresh M2
    x.write(recorded[1]);
    await expectLater(
        victim,
        throwsA(isA<HandshakeException>()
            .having((e) => e.failure, 'failure', HandshakeFailure.wrongKey)));
  });

  test('different protocol version', () async {
    final (a, b) = memoryChannelPair();
    final r = AuthSession.respond(b, cfg(groupKey));
    a.write(utf8.encode(jsonEncode({'p': 'diegema-session/1', 'n': 'x'})));
    await expectLater(
        r,
        throwsA(isA<HandshakeException>()
            .having((e) => e.failure, 'failure', HandshakeFailure.protocol)));
  });

  test('garbage instead of a handshake is a protocol failure', () async {
    final (a, b) = memoryChannelPair();
    final r = AuthSession.respond(b, cfg(groupKey));
    a.write([0xff, 0x00, 0x13]);
    await expectLater(
        r,
        throwsA(isA<HandshakeException>()
            .having((e) => e.failure, 'failure', HandshakeFailure.protocol)));
  });

  group('after the handshake', () {
    test('an altered frame does not verify', () async {
      final (i, r, tap) = await tapped();
      tap.mutate = (f) => f..[0] ^= 1;
      await i.send([1, 2, 3]);
      expect(r.receive(), throwsA(isA<SessionBroken>()));
    });

    test('a replayed frame does not verify', () async {
      final (i, r, tap) = await tapped();
      await i.send([1, 2, 3]);
      expect(await r.receive(), [1, 2, 3]);
      tap.replayLast();
      expect(r.receive(), throwsA(isA<SessionBroken>()));
    });

    test('a frame reflected back to its sender does not verify', () async {
      // Separate keys per direction: i's own frame is no use against i.
      final (i, _, tap) = await tapped();
      await i.send([1, 2, 3]);
      tap.inject(tap._last!);
      expect(i.receive(), throwsA(isA<SessionBroken>()));
    });

    test('un-awaited sends arrive in order', () async {
      final (i, r, _) = await tapped();
      final sends = [
        for (var n = 0; n < 20; n++) i.send([n])
      ];
      await Future.wait(sends);
      for (var n = 0; n < 20; n++) {
        expect(await r.receive(), [n]);
      }
    });

    test('traffic is readable: authentication only, nothing encrypted',
        () async {
      final (i, r, tap) = await tapped();
      await i.send(utf8.encode('position lv:emma 3:12:40'));
      expect(utf8.decode(tap._last!.sublist(0, tap._last!.length - 32)),
          'position lv:emma 3:12:40');
      await r.receive();
    });
  });

  group('framing', () {
    Uint8List framed(List<int> body) => Uint8List.fromList([
          ...(ByteData(4)..setUint32(0, body.length)).buffer.asUint8List(),
          ...body,
        ]);

    test('split across chunks, several per chunk, and big', () async {
      final input = StreamController<List<int>>();
      final ch = LengthPrefixedChannel(
          input.stream, StreamController<List<int>>().sink);
      final big = List<int>.generate(300000, (n) => n & 0xff);
      final bytes = [
        ...framed([1]),
        ...framed([2, 2]),
        ...framed(big),
        ...framed([])
      ];
      // One byte, then a few, then 7 KB chunks.
      input.add(bytes.sublist(0, 1));
      input.add(bytes.sublist(1, 9));
      for (var o = 9; o < bytes.length; o += 7000) {
        input.add(bytes.sublist(
            o, o + 7000 > bytes.length ? bytes.length : o + 7000));
      }
      expect(await ch.read(), [1]);
      expect(await ch.read(), [2, 2]);
      expect(await ch.read(), big);
      expect(await ch.read(), isEmpty);
      await input.close();
      expect(ch.read(), throwsA(isA<ChannelClosed>()));
    });

    test('an oversize length fails without waiting for the bytes', () async {
      // ignore: close_sinks
      final input = StreamController<List<int>>();
      final ch = LengthPrefixedChannel(
          input.stream, StreamController<List<int>>().sink,
          maxFrame: 1000);
      input.add((ByteData(4)..setUint32(0, 1001)).buffer.asUint8List());
      expect(ch.read(), throwsA(isA<FrameTooLarge>()));
    });
  });

  test('over real TCP on loopback', () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final accepted = server.first.then(
        (s) => AuthSession.respond(LengthPrefixedChannel(s, s), cfg(groupKey)));
    // Closed by i.close().
    // ignore: close_sinks
    final socket = await Socket.connect(server.address, server.port);
    final i = await AuthSession.initiate(
        LengthPrefixedChannel(socket, socket), cfg(groupKey));
    final r = await accepted;
    final payload = Uint8List.fromList(List<int>.generate(200000, (n) => n));
    await i.send(payload);
    expect(await r.receive(), payload);
    await r.send([42]);
    expect(await i.receive(), [42]);
    await i.close();
    await r.close();
    await server.close();
  });

  group('test vectors', () {
    test('HMAC-SHA256, RFC 4231 test case 2', () async {
      final mac = await Hmac.sha256().calculateMac(
          utf8.encode('what do ya want for nothing?'),
          secretKey: SecretKey(utf8.encode('Jefe')));
      expect(_toHex(mac.bytes),
          '5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843');
    });

    test('our handshake is pinned', () async {
      // Any change to the wire format or key derivation breaks this; a
      // deliberate change bumps the protocol version and the vector.
      final (i, r, tap) = await tapped(iLabel: 1, rLabel: 2);
      await i.send(utf8.encode('diegema'));
      expect(utf8.decode(await r.receive()), 'diegema');
      expect(_toHex(tap._last!), _pinnedFrame);
    });
  });
}

const _pinnedFrame =
    '64696567656d6136842d5850bf19991e9744d9b263f12b158ebbd8ef125f16c5aa9651b0a28838';

String _toHex(List<int> b) =>
    b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

/// Sits between the initiator and the wire so tests can alter, record or
/// replay what it writes.
class _Tap implements FrameChannel {
  final FrameChannel inner;
  Uint8List Function(Uint8List)? mutate;
  Uint8List? _last;
  final _injected = <Uint8List>[];
  _Tap(this.inner);

  /// The next read returns [frame] instead of what the wire has.
  void inject(Uint8List frame) => _injected.add(frame);

  @override
  Future<Uint8List> read() =>
      _injected.isNotEmpty ? Future.value(_injected.removeAt(0)) : inner.read();

  @override
  void write(List<int> frame) {
    var f = Uint8List.fromList(frame);
    if (mutate != null) f = mutate!(f);
    _last = f;
    inner.write(f);
  }

  void replayLast() => inner.write(_last!);

  @override
  Future<void> close() => inner.close();
}
