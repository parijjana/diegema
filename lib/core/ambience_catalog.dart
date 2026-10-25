import 'package:flutter/material.dart';

/// Groups in the ambience picker. The same vocabulary is meant to be reused
/// later by scene cues (see `future-work/diegema-read-along.md`), which is
/// why the ids are plain, stable words.
enum AmbienceGroup {
  water('Water'),
  nature('Nature'),
  weather('Weather'),
  places('Places'),
  noise('Noise');

  final String label;
  const AmbienceGroup(this.label);
}

/// One bundled, seamlessly looping background sound. Built by
/// `tool/ambience/prepare_ambience.py`; recordings are CC0 (BigSoundBank, plus `battle` and `sword_fight` from Freesound),
/// the three noises are synthesised (see `assets/ambience/CREDITS.md`).
class AmbienceSound {
  final String id;
  final String name;
  final AmbienceGroup group;
  final IconData icon;

  const AmbienceSound(this.id, this.name, this.group, this.icon);

  String get asset => 'assets/ambience/$id.m4a';

  static const List<AmbienceSound> all = [
    AmbienceSound(
        'ocean_surf', 'Ocean surf', AmbienceGroup.water, Icons.waves_rounded),
    AmbienceSound('ocean_waves', 'Gentle waves', AmbienceGroup.water,
        Icons.water_rounded),
    AmbienceSound(
        'forest', 'Forest', AmbienceGroup.nature, Icons.forest_rounded),
    AmbienceSound(
        'deep_forest', 'Deep forest', AmbienceGroup.nature, Icons.park_rounded),
    AmbienceSound('campfire', 'Campfire', AmbienceGroup.nature,
        Icons.local_fire_department_rounded),
    AmbienceSound(
        'rain', 'Rain', AmbienceGroup.weather, Icons.water_drop_rounded),
    AmbienceSound('thunderstorm', 'Thunderstorm', AmbienceGroup.weather,
        Icons.thunderstorm_rounded),
    AmbienceSound('city_street', 'City street', AmbienceGroup.places,
        Icons.location_city_rounded),
    AmbienceSound('river', 'River', AmbienceGroup.water, Icons.water_rounded),
    AmbienceSound(
        'gulls', 'Seagulls', AmbienceGroup.nature, Icons.flutter_dash_rounded),
    AmbienceSound('jungle_insects', 'Jungle insects', AmbienceGroup.nature,
        Icons.bug_report_rounded),
    AmbienceSound('night_crickets', 'Night crickets', AmbienceGroup.nature,
        Icons.nightlight_round),
    AmbienceSound('wind', 'Wind', AmbienceGroup.weather, Icons.air_rounded),
    AmbienceSound('tavern_crowd', 'Tavern crowd', AmbienceGroup.places,
        Icons.local_bar_rounded),
    AmbienceSound('fireplace', 'Fireplace', AmbienceGroup.places,
        Icons.fireplace_rounded),
    AmbienceSound('ship_timbers', 'Ship timbers', AmbienceGroup.places,
        Icons.sailing_rounded),
    AmbienceSound('horses', 'Horses', AmbienceGroup.places, Icons.pets_rounded),
    AmbienceSound('battle', 'Battlefield', AmbienceGroup.places,
        Icons.shield_rounded),
    AmbienceSound('sword_fight', 'Sword fight', AmbienceGroup.places,
        Icons.sports_martial_arts_rounded),
    AmbienceSound('white_noise', 'White noise', AmbienceGroup.noise,
        Icons.graphic_eq_rounded),
    AmbienceSound('pink_noise', 'Pink noise', AmbienceGroup.noise,
        Icons.graphic_eq_rounded),
    AmbienceSound('brown_noise', 'Brown noise', AmbienceGroup.noise,
        Icons.graphic_eq_rounded),
  ];

  static AmbienceSound? byId(String id) {
    for (final sound in all) {
      if (sound.id == id) return sound;
    }
    return null;
  }
}
