package com.overengineeredhobbies.diegema

import com.ryanheise.audioservice.AudioServiceActivity

// AudioServiceActivity (a FlutterActivity subclass provided by audio_service)
// links this activity to the plugin's shared FlutterEngine so the
// background playback service and the app's own UI can share one Dart
// isolate. See the audio_service README's "Custom Android activity" section.
class MainActivity : AudioServiceActivity()
