import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:diegema/sync/secure/frame_channel.dart';
import 'package:diegema/sync/secure/secure_session.dart';
import 'package:flutter_test/flutter_test.dart';

/// Repeatable "randomness": byte i of call k is a fixed function of a label.
List<int> Function(int) fixedRandom(int label) {
  var call = 0;
  return (n) {
    call++;
    return List<int>.generate(n, (i) => (label * 31 + call * 7 + i) & 0xff);
  };
}

Future<DeviceIdentity> device(int b) =>
    DeviceIdentity.fromSeed(List<int>.filled(32, b));

Future<bool> anyone(Uint8List _) async => true;

PeerPolicy only(Uint8List key) =>
    (k) async => base64.encode(k) == base64.encode(key);

final groupKey = List<int>.generate(32, (i) => i);

Future<(SecureSession, SecureSession)> pair(
    SessionConfig i, SessionConfig r) async {
  final (a, b) = memoryChannelPair();
  final results = await Future.wait([
    SecureSession.initiate(a, i),
    SecureSession.respond(b, r),
  ]);
  return (results[0], results[1]);
}

/// Runs both sides and returns each side's failure (null when it succeeded).
Future<(HandshakeFailure?, HandshakeFailure?)> failures(
    SessionConfig i, SessionConfig r,
    {(FrameChannel, FrameChannel)? channels}) async {
  final (a, b) = channels ?? memoryChannelPair();
  Future<HandshakeFailure?> run(Future<SecureSession> f) async {
    try {
      await f;
      return null;
    } on HandshakeException catch (e) {
      return e.failure;
    }
  }

  final out = await Future.wait([
    run(SecureSession.initiate(a, i)),
    run(SecureSession.respond(b, r)),
  ]);
  return (out[0], out[1]);
}

void main() {
  late DeviceIdentity phone, mac, stranger;
  setUpAll(() async {
    phone = await device(1);
    mac = await device(2);
    stranger = await device(3);
  });

  group('group mode', () {
    test('both sides agree, learn each other, and talk both ways', () async {
      final (i, r) = await pair(
        SessionConfig(
            mode: SessionMode.group,
            identity: phone,
            preSharedKey: groupKey,
            acceptPeer: only(mac.publicKey)),
        SessionConfig(
            mode: SessionMode.group,
            identity: mac,
            preSharedKey: groupKey,
            acceptPeer: only(phone.publicKey)),
      );
      expect(i.peerPublicKey, mac.publicKey);
      expect(r.peerPublicKey, phone.publicKey);
      expect(i.transcriptHash, r.transcriptHash);
      expect(i.code, isNull);

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
      final (fi, fr) = await failures(
        SessionConfig(
            mode: SessionMode.group,
            identity: stranger,
            preSharedKey: List<int>.filled(32, 9),
            acceptPeer: anyone),
        SessionConfig(
            mode: SessionMode.group,
            identity: mac,
            preSharedKey: groupKey,
            acceptPeer: anyone),
      );
      expect(fr, HandshakeFailure.wrongKey);
      expect(fi, HandshakeFailure.closed);
    });

    test('a key outside the member list is rejected', () async {
      final (fi, fr) = await failures(
        SessionConfig(
            mode: SessionMode.group,
            identity: stranger,
            preSharedKey: groupKey,
            acceptPeer: anyone),
        SessionConfig(
            mode: SessionMode.group,
            identity: mac,
            preSharedKey: groupKey,
            acceptPeer: only(phone.publicKey)),
      );
      expect(fr, HandshakeFailure.peerRejected);
      expect(fi, HandshakeFailure.closed);
    });

    test('initiator rejects a responder outside the member list', () async {
      final (fi, fr) = await failures(
        SessionConfig(
            mode: SessionMode.group,
            identity: phone,
            preSharedKey: groupKey,
            acceptPeer: only(mac.publicKey)),
        SessionConfig(
            mode: SessionMode.group,
            identity: stranger,
            preSharedKey: groupKey,
            acceptPeer: anyone),
      );
      expect(fi, HandshakeFailure.peerRejected);
      expect(fr, isNull, reason: 'responder finished before the check');
    });

    test('mode mismatch', () async {
      final (_, fr) = await failures(
        SessionConfig(
            mode: SessionMode.token,
            identity: phone,
            preSharedKey: groupKey,
            acceptPeer: anyone),
        SessionConfig(
            mode: SessionMode.group,
            identity: mac,
            preSharedKey: groupKey,
            acceptPeer: anyone),
      );
      expect(fr, HandshakeFailure.modeMismatch);
    });
  });

  group('after the handshake', () {
    Future<(SecureSession, SecureSession, _Tap)> tapped() async {
      final (a, b) = memoryChannelPair();
      final tap = _Tap(a);
      final res = await Future.wait([
        SecureSession.initiate(
            tap,
            SessionConfig(
                mode: SessionMode.group,
                identity: phone,
                preSharedKey: groupKey,
                acceptPeer: anyone)),
        SecureSession.respond(
            b,
            SessionConfig(
                mode: SessionMode.group,
                identity: mac,
                preSharedKey: groupKey,
                acceptPeer: anyone)),
      ]);
      return (res[0], res[1], tap);
    }

    test('an altered frame does not open', () async {
      final (i, r, tap) = await tapped();
      tap.mutate = (f) => f..[0] ^= 1;
      await i.send([1, 2, 3]);
      expect(r.receive(), throwsA(isA<HandshakeException>()));
    });

    test('a replayed frame does not open', () async {
      final (i, r, tap) = await tapped();
      await i.send([1, 2, 3]);
      expect(await r.receive(), [1, 2, 3]);
      tap.replayLast();
      expect(r.receive(), throwsA(isA<HandshakeException>()));
    });
  });

  group('token mode (link QR)', () {
    final token = List<int>.generate(16, (i) => 200 - i);

    test('scanner accepts the key from the QR, shower accepts anyone',
        () async {
      final (i, r) = await pair(
        SessionConfig(
            mode: SessionMode.token,
            identity: phone,
            preSharedKey: token,
            acceptPeer: only(mac.publicKey)),
        SessionConfig(
            mode: SessionMode.token,
            identity: mac,
            preSharedKey: token,
            acceptPeer: anyone),
      );
      expect(i.peerPublicKey, mac.publicKey);
      expect(r.peerPublicKey, phone.publicKey);
    });

    test('someone else answering at the QR address is refused', () async {
      final (fi, _) = await failures(
        SessionConfig(
            mode: SessionMode.token,
            identity: phone,
            preSharedKey: token,
            acceptPeer: only(mac.publicKey)),
        SessionConfig(
            mode: SessionMode.token,
            identity: stranger,
            preSharedKey: token,
            acceptPeer: anyone),
      );
      expect(fi, HandshakeFailure.peerRejected);
    });
  });

  group('numeric mode', () {
    SessionConfig numeric(DeviceIdentity id, ConfirmCode confirm) =>
        SessionConfig(
            mode: SessionMode.numeric,
            identity: id,
            acceptPeer: anyone,
            confirmCode: confirm);

    test('both screens show the same code', () async {
      final shown = <String>[];
      Future<bool> yes(String c) async {
        shown.add(c);
        return true;
      }

      final (i, r) = await pair(numeric(phone, yes), numeric(mac, yes));
      expect(shown, hasLength(2));
      expect(shown[0], shown[1]);
      expect(shown[0], matches(RegExp(r'^\d{6}$')));
      expect(i.code, r.code);
    });

    test('"numbers don\'t match" on either side ends it for both', () async {
      Future<bool> yes(String _) async => true;
      Future<bool> no(String _) async => false;
      expect(await failures(numeric(phone, no), numeric(mac, yes)),
          (HandshakeFailure.codeRejected, HandshakeFailure.closed));
      expect(await failures(numeric(phone, yes), numeric(mac, no)),
          (HandshakeFailure.closed, HandshakeFailure.codeRejected));
    });

    test('a revealed nonce that does not match the commitment', () async {
      final (a, b) = memoryChannelPair();
      final tap = _Tap(a);
      var frame = 0;
      tap.mutate = (f) {
        frame++;
        if (frame != 2) return f; // M3, the reveal
        final m = jsonDecode(utf8.decode(f)) as Map<String, Object?>;
        m['n'] = base64Url.encode(List<int>.filled(32, 0));
        return Uint8List.fromList(utf8.encode(jsonEncode(m)));
      };
      Future<bool> yes(String _) async => true;
      final (_, fr) = await failures(numeric(phone, yes), numeric(mac, yes),
          channels: (tap, b));
      expect(fr, HandshakeFailure.commitment);
    });

    test('a man in the middle makes the two codes differ', () async {
      // The attacker runs its own session with each side and relays nothing;
      // each real device sees a code computed over a different transcript.
      final codes = <String>[];
      Future<bool> note(String c) async {
        codes.add(c);
        return true;
      }

      final (p1, m1) = memoryChannelPair();
      final (m2, p2) = memoryChannelPair();
      final eve = await device(66);
      await Future.wait([
        SecureSession.initiate(p1, numeric(phone, note)),
        SecureSession.respond(m1, numeric(eve, (_) async => true)),
        SecureSession.initiate(m2, numeric(eve, (_) async => true)),
        SecureSession.respond(p2, numeric(mac, note)),
      ]);
      expect(codes, hasLength(2));
      expect(codes[0], isNot(codes[1]));
    });
  });

  test('over real TCP on loopback', () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final accepted = server.first.then((s) => SecureSession.respond(
        LengthPrefixedChannel(s, s),
        SessionConfig(
            mode: SessionMode.group,
            identity: mac,
            preSharedKey: groupKey,
            acceptPeer: anyone)));
    // Closed by i.close().
    // ignore: close_sinks
    final socket = await Socket.connect(server.address, server.port);
    final i = await SecureSession.initiate(
        LengthPrefixedChannel(socket, socket),
        SessionConfig(
            mode: SessionMode.group,
            identity: phone,
            preSharedKey: groupKey,
            acceptPeer: anyone));
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
    test('Ed25519 RFC 8032 test 1 and X25519 RFC 7748 §6.1', () async {
      final ed = await Ed25519().newKeyPairFromSeed(_hex(
          '9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60'));
      expect(_toHex((await ed.extractPublicKey()).bytes),
          'd75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a');
      expect(
          _toHex((await Ed25519().sign(const [], keyPair: ed)).bytes),
          'e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e06522490155'
          '5fb8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b');

      final x = X25519();
      final alice = await x.newKeyPairFromSeed(_hex(
          '77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a'));
      final bobPub = _hex(
          'de9edb7d7b7dc1b4d35b61c2ece435373f8343c85b78674dadfc7e146f882b4f');
      final shared = await x.sharedSecretKey(
          keyPair: alice,
          remotePublicKey: SimplePublicKey(bobPub, type: KeyPairType.x25519));
      expect(_toHex(await shared.extractBytes()), _rfc7748Shared);
    });

    test('our handshake is pinned', () async {
      // Any change to the wire format, key derivation or code breaks this;
      // a deliberate change bumps the protocol version and the vector.
      final (a, b) = memoryChannelPair();
      final tap = _Tap(a);
      final res = await Future.wait([
        SecureSession.initiate(
            tap,
            SessionConfig(
                mode: SessionMode.numeric,
                identity: phone,
                acceptPeer: anyone,
                confirmCode: (_) async => true,
                randomBytes: fixedRandom(1))),
        SecureSession.respond(
            b,
            SessionConfig(
                mode: SessionMode.numeric,
                identity: mac,
                acceptPeer: anyone,
                confirmCode: (_) async => true,
                randomBytes: fixedRandom(2))),
      ]);
      final (i, r) = (res[0], res[1]);
      await i.send(utf8.encode('diegema'));
      expect(utf8.decode(await r.receive()), 'diegema');
      expect(_toHex(i.transcriptHash), _pinnedTranscript);
      expect(i.code, _pinnedCode);
      expect(r.code, _pinnedCode);
      expect(_toHex(tap._last!), _pinnedFrame);
    });
  });
}

const _rfc7748Shared =
    '4a5d9d5ba4ce2de1728e3bf480350f25e07e21c947d19e3376f09b3c1e161742';
const _pinnedTranscript =
    '33e213463f552e5c77e2e37ce09a3eb91bf80d2b2629b32d6296ec845768c640';
const _pinnedCode = '600031';
const _pinnedFrame = '425d8f703296ee1fb7a04836a835585e4205c492a3661d';

Uint8List _hex(String s) => Uint8List.fromList([
      for (var i = 0; i < s.length; i += 2)
        int.parse(s.substring(i, i + 2), radix: 16)
    ]);
String _toHex(List<int> b) =>
    b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

/// Sits between the initiator and the wire so tests can alter or replay
/// what it writes.
class _Tap implements FrameChannel {
  final FrameChannel inner;
  Uint8List Function(Uint8List)? mutate;
  Uint8List? _last;
  _Tap(this.inner);

  @override
  Future<Uint8List> read() => inner.read();

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
