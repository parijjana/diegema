import 'package:flutter_test/flutter_test.dart';
import 'package:diegema/core/ui_preferences.dart';
import 'package:diegema/services/ambience_service.dart';
import 'package:diegema/services/audio_playback_service.dart';

import '../support/fake_playback_service.dart';

class FakeChannel implements AmbienceChannel {
  String? asset;
  double volume = -1;
  bool playing = false;
  bool disposed = false;

  @override
  Future<void> load(String asset) async => this.asset = asset;
  @override
  Future<void> setVolume(double volume) async => this.volume = volume;
  @override
  Future<void> play() async => playing = true;
  @override
  Future<void> pause() async => playing = false;
  @override
  Future<void> dispose() async => disposed = true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakePlaybackService book;
  late Map<String, Object> store;
  late List<FakeChannel> channels;

  AmbienceService build() => AmbienceService(
        book: book,
        preferences: UiPreferences(overrides: store),
        channelFactory: () {
          final c = FakeChannel();
          channels.add(c);
          return c;
        },
        fade: Duration.zero,
        useAudioSession: false,
      );

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  List<FakeChannel> live() =>
      channels.where((c) => !c.disposed && c.playing).toList();

  setUp(() {
    book = FakePlaybackService();
    store = {};
    channels = [];
  });

  test('following the book: silent until the book plays, ducked under it',
      () async {
    final amb = build();
    await amb.init();
    await amb.toggleSound('rain');
    expect(live(), isEmpty, reason: 'the book is not playing');
    expect(amb.state.value.playing, isFalse);

    book.stateNotifier.value = PlaybackState.playing;
    await settle();
    await amb.setMaster(1.0);
    expect(live().single.asset, 'assets/ambience/rain.m4a');
    expect(live().single.volume, closeTo(0.7 * kAmbienceNarrationDuck, 1e-9),
        reason: 'the default level, kept under the narration');
    expect(amb.state.value.playing, isTrue);

    book.stateNotifier.value = PlaybackState.paused;
    await settle();
    await amb.setMaster(1.0);
    expect(live(), isEmpty);
    await amb.dispose();
  });

  test('on its own: plays without a book, at full level until the book starts',
      () async {
    final amb = build();
    await amb.init();
    await amb.setFollowBook(false);
    await amb.toggleSound('campfire');
    await amb.setMaster(0.5);
    expect(live().single.volume, closeTo(0.7 * 0.5, 1e-9));

    book.stateNotifier.value = PlaybackState.playing;
    await settle();
    await amb.setMaster(0.5);
    expect(live().single.volume,
        closeTo(0.7 * 0.5 * kAmbienceNarrationDuck, 1e-9));
    await amb.dispose();
  });

  test('a mix of sounds, each at its own level; removing one stops it',
      () async {
    final amb = build();
    await amb.init();
    await amb.setFollowBook(false);
    await amb.toggleSound('rain');
    await amb.toggleSound('thunderstorm');
    await amb.setLevel('thunderstorm', 0.2);
    await amb.setMaster(1.0);
    expect(live(), hasLength(2));
    expect(live().map((c) => c.volume), containsAll([0.7, 0.2]));

    await amb.toggleSound('rain');
    expect(live().single.asset, 'assets/ambience/thunderstorm.m4a');
    await amb.dispose();
  });

  test("the book's sleep timer stops ambience too", () async {
    final amb = build();
    await amb.init();
    await amb.setFollowBook(false);
    await amb.toggleSound('rain');
    expect(live(), hasLength(1));

    book.sleepTimerFired.value++;
    await settle();
    await amb.setMaster(0.7);
    expect(amb.state.value.on, isFalse);
    expect(live(), isEmpty);
    await amb.dispose();
  });

  test('ambience has its own sleep timer', () async {
    final amb = build();
    await amb.init();
    await amb.setFollowBook(false);
    await amb.toggleSound('forest');
    amb.setSleepTimer(const Duration(seconds: 1));
    expect(amb.state.value.sleepRemaining, const Duration(seconds: 1));

    await Future<void>.delayed(const Duration(milliseconds: 2200));
    await amb.setMaster(0.7);
    expect(amb.state.value.on, isFalse);
    expect(amb.state.value.sleepRemaining, isNull);
    expect(live(), isEmpty);
    expect(book.stateNotifier.value, isNot(PlaybackState.paused),
        reason: "ambience's timer leaves the book alone");
    await amb.dispose();
  });

  test('mixes can be saved, recalled, deleted and restored', () async {
    final amb = build();
    await amb.init();
    await amb.toggleSound('ocean_surf');
    await amb.setLevel('ocean_surf', 0.4);
    await amb.saveMix('  Sea voyage ');
    await amb.toggleSound('ocean_surf');
    await amb.toggleSound('city_street');
    await amb.saveMix('Town');

    expect(amb.state.value.saved.map((m) => m.name), ['Town', 'Sea voyage']);

    await amb.applyMix(amb.state.value.saved.last);
    expect(amb.state.value.mix, {'ocean_surf': 0.4});
    expect(amb.state.value.on, isTrue);

    final town = amb.state.value.saved.first;
    await amb.deleteMix(town);
    expect(amb.state.value.saved.map((m) => m.name), ['Sea voyage']);
    await amb.restoreMix(town, 0);
    expect(amb.state.value.saved.map((m) => m.name), ['Town', 'Sea voyage']);

    // Saving under an existing name replaces it.
    await amb.saveMix('town');
    expect(amb.state.value.saved, hasLength(2));
    await amb.dispose();
  });

  test('settings survive a restart; an independent mix never auto-starts',
      () async {
    final first = build();
    await first.init();
    await first.setFollowBook(false);
    await first.toggleSound('rain');
    await first.setMaster(0.3);
    await first.saveMix('Wet');
    await first.dispose();

    final second = build();
    await second.init();
    final s = second.state.value;
    expect(s.mix, {'rain': 0.7});
    expect(s.master, 0.3);
    expect(s.followBook, isFalse);
    expect(s.saved.single.name, 'Wet');
    expect(s.on, isFalse, reason: 'noise never starts by itself on launch');
    await second.dispose();
  });

  test('unknown sounds in stored settings are dropped', () {
    final s = AmbienceState.fromJson({
      'mix': {'rain': 0.5, 'dragons': 1.0},
      'saved': [
        {
          'name': 'x',
          'mix': {'nope': 1}
        },
        {
          'name': 'y',
          'mix': {'forest': 2}
        },
      ],
    });
    expect(s.mix, {'rain': 0.5});
    expect(s.saved.single.name, 'y');
    expect(s.saved.single.mix, {'forest': 1.0});
  });
}
