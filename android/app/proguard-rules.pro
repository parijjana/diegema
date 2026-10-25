# Keep rules for plugins that use reflection / JNI / WorkManager initialisers.
# Flutter's own rules are added by the Flutter Gradle plugin.

# audio_service / just_audio / media session
-keep class com.ryanheise.** { *; }
-keep class androidx.media.** { *; }
-keep class androidx.media3.** { *; }
-dontwarn androidx.media3.**

# background_downloader (WorkManager workers are instantiated by class name)
-keep class com.bbflight.background_downloader.** { *; }
-keep class * extends androidx.work.ListenableWorker { *; }
-keep class * extends androidx.work.Worker { *; }

# sqlite3 / sqlite3_flutter_libs / drift (native + JNI bindings)
-keep class eu.simonbinder.** { *; }
-keep class org.sqlite.** { *; }
-keep class org.dartlang.** { *; }

# file_picker, permission_handler, secure storage, scanner
-keep class com.mr.flutter.plugin.filepicker.** { *; }
-keep class com.baseflow.permissionhandler.** { *; }
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-keep class dev.steenbakker.mobile_scanner.** { *; }
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# Play Core is referenced by Flutter's deferred components but not shipped
-dontwarn com.google.android.play.core.**
