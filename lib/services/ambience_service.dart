import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:audio_session/audio_session.dart';
import 'package:flutter/widgets.dart';
import 'package:just_audio/just_audio.dart';

import '../core/ambience_catalog.dart';
import '../core/ui_preferences.dart';
import 'audio_playback_service.dart';

/// While the book is audible the whole ambience mix is scaled by this, so
/// it sits under the narration; alone, it plays at the chosen level. The
/// bundled loops are already levelled ~12 dB under typical narration (see
/// `tool/ambience/prepare_ambience.py`), so even at full slider an ambience
/// cannot drown the book.
const double kAmbienceNarrationDuck = 0.6;

/// A single looping sound. An interface so tests can run the mixer without
/// a platform audio player.
abstract class AmbienceChannel {
  Future<void> load(String asset);
  Future<void> setVolume(double volume);
  Future<void> play();
  Future<void> pause();
  Future<void> dispose();
}

typedef AmbienceChannelFactory = AmbienceChannel Function();

class JustAudioAmbienceChannel implements AmbienceChannel {
  // Interruptions are handled once, by [AmbienceService], for the whole mix.
  final AudioPlayer _player = AudioPlayer(handleInterruptions: false);

  @override
  Future<void> load(String asset) async {
    await _player.setAudioSource(AudioSource.asset(asset));
    await _player.setLoopMode(LoopMode.one);
    // Start somewhere random, so two sessions (or two sounds cut from the
    // same kind of recording) never line up the same way.
    final length = _player.duration;
    if (length != null && length.inMilliseconds > 1000) {
      await _player.seek(
          Duration(milliseconds: math.Random().nextInt(length.inMilliseconds)));
    }
  }

  @override
  Future<void> setVolume(double volume) => _player.setVolume(volume);

  @override
  Future<void> play() async {
    unawaited(_player.play());
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> dispose() => _player.dispose();
}

/// A mix the user named and saved.
@immutable
class SavedAmbienceMix {
  final String name;
  final Map<String, double> mix;
  const SavedAmbienceMix(this.name, this.mix);

  Map<String, Object> toJson() => {'name': name, 'mix': mix};

  static SavedAmbienceMix? fromJson(Object? json) {
    if (json is! Map || json['name'] is! String) return null;
    final mix = _mixFromJson(json['mix']);
    return mix.isEmpty ? null : SavedAmbienceMix(json['name'] as String, mix);
  }
}

Map<String, double> _mixFromJson(Object? raw) {
  final mix = <String, double>{};
  if (raw is Map) {
    raw.forEach((id, level) {
      if (id is String && AmbienceSound.byId(id) != null && level is num) {
        mix[id] = level.toDouble().clamp(0.0, 1.0);
      }
    });
  }
  return mix;
}

/// What the ambience mixer is set to, and whether it is audible right now.
@immutable
class AmbienceState {
  /// The sounds in the mix, each with its own level (0–1).
  final Map<String, double> mix;

  /// The level of the whole mix (0–1).
  final double master;

  /// The user's on/off switch.
  final bool on;

  /// Plays only while the book plays (the default). Off: ambience runs on
  /// its own, with or without a book.
  final bool followBook;

  /// Actually audible now.
  final bool playing;

  /// The user's named mixes, newest first.
  final List<SavedAmbienceMix> saved;

  /// Time left on the ambience's own sleep timer; null when none is set.
  final Duration? sleepRemaining;

  const AmbienceState({
    this.mix = const {},
    this.master = 0.7,
    this.on = false,
    this.followBook = true,
    this.playing = false,
    this.saved = const [],
    this.sleepRemaining,
  });

  List<AmbienceSound> get sounds => [
        for (final sound in AmbienceSound.all)
          if (mix.containsKey(sound.id)) sound,
      ];

  /// "Rain", "Rain + 2", or "Off".
  String get summary {
    final names = sounds;
    if (names.isEmpty || !on) return 'Off';
    return names.length == 1
        ? names.first.name
        : '${names.first.name} + ${names.length - 1}';
  }

  AmbienceState copyWith({
    Map<String, double>? mix,
    double? master,
    bool? on,
    bool? followBook,
    bool? playing,
    List<SavedAmbienceMix>? saved,
    Duration? Function()? sleepRemaining,
  }) =>
      AmbienceState(
        mix: mix ?? this.mix,
        master: master ?? this.master,
        on: on ?? this.on,
        followBook: followBook ?? this.followBook,
        playing: playing ?? this.playing,
        saved: saved ?? this.saved,
        sleepRemaining:
            sleepRemaining != null ? sleepRemaining() : this.sleepRemaining,
      );

  Map<String, Object> toJson() => {
        'mix': mix,
        'master': master,
        'on': on,
        'followBook': followBook,
        'saved': [for (final m in saved) m.toJson()],
      };

  static AmbienceState fromJson(Object? json) {
    if (json is! Map) return const AmbienceState();
    final master = json['master'];
    final rawSaved = json['saved'];
    return AmbienceState(
      mix: _mixFromJson(json['mix']),
      saved: [
        if (rawSaved is List)
          for (final m in rawSaved.map(SavedAmbienceMix.fromJson))
            if (m != null) m,
      ],
      master: master is num ? master.toDouble().clamp(0.0, 1.0) : 0.7,
      on: json['on'] == true,
      followBook: json['followBook'] != false,
    );
  }
}

/// The background-sound channel: a small mixer of looping sounds, entirely
/// separate from the book's player, with its own switch and volumes.
///
/// It follows the book (plays while the book plays, the default) or runs
/// on its own. It is always quieter under narration
/// ([kAmbienceNarrationDuck]); fades in and out rather than cutting; stops
/// with the sleep timer; and pauses for calls and unplugged headphones.
class AmbienceService {
  final AudioPlaybackService _book;
  final UiPreferences _preferences;
  final AmbienceChannelFactory _newChannel;
  final Duration _fade;

  /// False in tests: skips the platform audio session (call interruptions,
  /// headphone unplugs, audio focus), which has no host there.
  final bool _useSession;

  final ValueNotifier<AmbienceState> state =
      ValueNotifier(const AmbienceState());

  final Map<String, AmbienceChannel> _channels = {};
  final Map<String, double> _volumes = {};
  final List<StreamSubscription<Object?>> _subscriptions = [];
  Future<void> _queue = Future.value();
  bool _interrupted = false;
  bool _disposed = false;
  Timer? _sleepTicker;
  DateTime? _sleepEndsAt;

  AmbienceService({
    required AudioPlaybackService book,
    UiPreferences preferences = const UiPreferences(),
    AmbienceChannelFactory? channelFactory,
    Duration fade = const Duration(milliseconds: 900),
    bool useAudioSession = true,
  })  : _book = book,
        _useSession = useAudioSession,
        _preferences = preferences,
        _newChannel = channelFactory ?? JustAudioAmbienceChannel.new,
        _fade = fade {
    _book.stateNotifier.addListener(_onBookChanged);
    _book.sleepTimerFired.addListener(_onSleepTimerFired);
  }

  /// Restores the saved mix, and subscribes to call interruptions and
  /// headphone unplugs.
  Future<void> init() async {
    final saved = await _preferences.getAmbienceJson();
    var restored =
        AmbienceState.fromJson(saved == null ? null : _tryDecode(saved));
    // Never start ambience by itself on a cold start: only with the book.
    if (!restored.followBook) restored = restored.copyWith(on: false);
    state.value = restored;
    if (_useSession) {
      try {
        final session = await AudioSession.instance;
        _subscriptions.add(session.interruptionEventStream.listen((event) {
          _interrupted = event.begin;
          _schedule();
        }));
        _subscriptions.add(session.becomingNoisyEventStream.listen((_) {
          if (!state.value.followBook) setOn(false);
        }));
      } catch (e) {
        debugPrint('AmbienceService: audio session unavailable: $e');
      }
    }
    _schedule();
  }

  static Object? _tryDecode(String raw) {
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  bool get _bookPlaying => _book.stateNotifier.value == PlaybackState.playing;

  bool get _shouldPlay {
    final s = state.value;
    if (!s.on || s.mix.isEmpty || _interrupted) return false;
    return s.followBook ? _bookPlaying : true;
  }

  // ---- user actions -------------------------------------------------------

  Future<void> setOn(bool on) => _update(state.value.copyWith(on: on));

  Future<void> setFollowBook(bool follow) =>
      _update(state.value.copyWith(followBook: follow));

  Future<void> setMaster(double level) =>
      _update(state.value.copyWith(master: level.clamp(0.0, 1.0)));

  /// Adds [id] to the mix (and switches ambience on), or takes it out.
  Future<void> toggleSound(String id) {
    final mix = Map<String, double>.of(state.value.mix);
    if (mix.remove(id) == null) {
      mix[id] = 0.7;
      return _update(state.value.copyWith(mix: mix, on: true));
    }
    return _update(state.value.copyWith(mix: mix));
  }

  Future<void> setLevel(String id, double level) {
    if (!state.value.mix.containsKey(id)) return Future.value();
    final mix = Map<String, double>.of(state.value.mix)
      ..[id] = level.clamp(0.0, 1.0);
    return _update(state.value.copyWith(mix: mix));
  }

  /// Saves the current mix under [name] (replacing one with that name).
  Future<void> saveMix(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || state.value.mix.isEmpty) return Future.value();
    final saved = [
      SavedAmbienceMix(trimmed, Map.of(state.value.mix)),
      for (final m in state.value.saved)
        if (m.name.toLowerCase() != trimmed.toLowerCase()) m,
    ];
    return _update(state.value.copyWith(saved: saved));
  }

  /// Makes [mix] the current mix and switches ambience on.
  Future<void> applyMix(SavedAmbienceMix mix) =>
      _update(state.value.copyWith(mix: Map.of(mix.mix), on: true));

  /// Puts a deleted mix back where it was (the Undo on delete).
  Future<void> restoreMix(SavedAmbienceMix mix, int index) {
    final saved = List.of(state.value.saved)
      ..insert(index.clamp(0, state.value.saved.length), mix);
    return _update(state.value.copyWith(saved: saved));
  }

  Future<void> deleteMix(SavedAmbienceMix mix) =>
      _update(state.value.copyWith(saved: [
        for (final m in state.value.saved)
          if (m != mix) m
      ]));

  /// The ambience's own sleep timer, independent of the book's: when it
  /// runs out the mix fades out and switches off. The book's timer stops
  /// ambience too.
  void setSleepTimer(Duration duration) {
    cancelSleepTimer();
    _sleepEndsAt = DateTime.now().add(duration);
    state.value = state.value.copyWith(sleepRemaining: () => duration);
    _sleepTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      final left = _sleepEndsAt!.difference(DateTime.now());
      if (left <= Duration.zero) {
        cancelSleepTimer();
        setOn(false);
      } else {
        state.value = state.value.copyWith(sleepRemaining: () => left);
      }
    });
  }

  void cancelSleepTimer() {
    _sleepTicker?.cancel();
    _sleepTicker = null;
    _sleepEndsAt = null;
    if (state.value.sleepRemaining != null) {
      state.value = state.value.copyWith(sleepRemaining: () => null);
    }
  }

  Future<void> _update(AmbienceState next) async {
    state.value = next.copyWith(
        playing: state.value.playing,
        sleepRemaining: () => state.value.sleepRemaining);
    await _preferences.setAmbienceJson(jsonEncode(next.toJson()));
    _schedule();
    await _queue;
  }

  // ---- reacting to the book -----------------------------------------------

  void _onBookChanged() => _schedule();

  void _onSleepTimerFired() {
    // Sleep means sleep: an independent mix stops too.
    if (state.value.on) setOn(false);
  }

  // ---- mixing ---------------------------------------------------------------

  /// Serialises every change, so a burst of slider moves or book state
  /// changes can never interleave half-applied.
  void _schedule() {
    _queue = _queue.then((_) => _apply()).catchError((Object e) {
      debugPrint('AmbienceService: $e');
    });
  }

  double _targetFor(String id) {
    final s = state.value;
    final level = s.mix[id] ?? 0;
    return level * s.master * (_bookPlaying ? kAmbienceNarrationDuck : 1.0);
  }

  Future<void> _apply() async {
    if (_disposed) return;
    final play = _shouldPlay;
    final wanted = play ? state.value.mix.keys.toSet() : <String>{};

    // Fade out and release anything no longer wanted.
    for (final id in _channels.keys.toList()) {
      if (wanted.contains(id)) continue;
      final channel = _channels.remove(id)!;
      await _ramp(channel, _volumes.remove(id) ?? 0, 0);
      await channel.pause();
      await channel.dispose();
    }
    // Start, or move to the new level.
    for (final id in wanted) {
      var channel = _channels[id];
      if (channel == null) {
        final sound = AmbienceSound.byId(id);
        if (sound == null) continue;
        channel = _newChannel();
        await channel.load(sound.asset);
        await channel.setVolume(0);
        await channel.play();
        _channels[id] = channel;
        _volumes[id] = 0;
      }
      final target = _targetFor(id);
      await _ramp(channel, _volumes[id] ?? 0, target);
      _volumes[id] = target;
    }
    if (play && !_bookPlaying && _useSession) {
      // Alone, the mix needs audio focus of its own.
      try {
        await (await AudioSession.instance).setActive(true);
      } catch (_) {}
    }
    if (state.value.playing != play) {
      state.value = state.value.copyWith(playing: play);
    }
  }

  Future<void> _ramp(AmbienceChannel channel, double from, double to) async {
    if ((from - to).abs() < 0.001) return;
    const steps = 6;
    // Big jumps (starting, stopping, ducking) fade; slider nudges are
    // near-instant, since the finger is the fade.
    final big = (from - to).abs() > 0.15;
    final step = big ? _fade ~/ steps : Duration.zero;
    for (var i = 1; i <= steps; i++) {
      await channel.setVolume(from + (to - from) * i / steps);
      if (step > Duration.zero) await Future<void>.delayed(step);
    }
  }

  Future<void> dispose() async {
    cancelSleepTimer();
    _book.stateNotifier.removeListener(_onBookChanged);
    _book.sleepTimerFired.removeListener(_onSleepTimerFired);
    for (final s in _subscriptions) {
      await s.cancel();
    }
    await _queue;
    _disposed = true;
    for (final channel in _channels.values) {
      await channel.dispose();
    }
    _channels.clear();
  }
}

/// Puts the [AmbienceService] in reach of the player UI. Absent (null) on
/// the web demo and in tests that do not provide one; the UI then simply
/// hides the ambience controls.
class AmbienceScope extends InheritedWidget {
  final AmbienceService service;
  const AmbienceScope({super.key, required this.service, required super.child});

  static AmbienceService? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AmbienceScope>()?.service;

  @override
  bool updateShouldNotify(AmbienceScope oldWidget) =>
      service != oldWidget.service;
}
