# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Suppress missing Play Core classes (not used in sideload builds)
-dontwarn com.google.android.play.core.**

# Keep speech_to_text JNI
-keep class com.csdcorp.** { *; }

# Riverpod
-keep class dev.riverpod.** { *; }
