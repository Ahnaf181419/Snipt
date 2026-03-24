# Flutter specific ProGuard rules for R8

# Flutter engine
-keep class io.flutter.embedding.engine.** { *; }
-dontwarn io.flutter.embedding.engine.**

# GeneratedPluginRegistrant
-keep class com.example.snipt.** { *; }
-keep class io.flutter.plugins.** { *; }
