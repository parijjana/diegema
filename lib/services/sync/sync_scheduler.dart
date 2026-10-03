import 'dart:async';

import 'package:flutter/foundation.dart';

import '../audio_playback_service.dart';

/// When linked-device sync runs while the app is alive (SYNC_DESIGN §6,
/// owner 2026-10-03): every 15 minutes, and shortly after playback pauses,
/// stops or finishes. Opening and leaving the app are handled by the
/// lifecycle listener in main. No OS background tasks: a closed app could
/// only reach Windows PCs, since Macs never listen.
class SyncScheduler {
  static const every = Duration(minutes: 15);

  /// Lets the player save the position first, and lets a quick
  /// pause-and-resume pass without a sync.
  static const afterPlayback = Duration(seconds: 5);

  final Future<void> Function() sync;
  final ValueListenable<PlaybackState>? playback;

  Timer? _periodic;
  Timer? _settle;
  PlaybackState? _last;

  SyncScheduler({required this.sync, this.playback});

  void start() {
    _periodic ??= Timer.periodic(every, (_) => unawaited(sync()));
    final p = playback;
    if (p != null) {
      _last = p.value;
      p.addListener(_onPlayback);
    }
  }

  void _onPlayback() {
    final now = playback!.value;
    final was = _last;
    _last = now;
    if (now == PlaybackState.playing) {
      _settle?.cancel();
      return;
    }
    final stopped = now == PlaybackState.paused ||
        now == PlaybackState.completed ||
        now == PlaybackState.idle;
    if (was == PlaybackState.playing && stopped) {
      _settle?.cancel();
      _settle = Timer(afterPlayback, () => unawaited(sync()));
    }
  }

  void dispose() {
    _periodic?.cancel();
    _settle?.cancel();
    playback?.removeListener(_onPlayback);
  }
}
