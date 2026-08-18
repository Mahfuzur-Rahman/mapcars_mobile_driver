# R8/ProGuard keep rules for the release build (isMinifyEnabled = true).
#
# flutter_local_notifications ships no consumer rules of its own (checked
# against 17.2.4), and it deserialises its notification details through GSON
# reflection. R8 renames those classes, so without these keeps the plugin
# fails only in a minified release build — never in debug, and never in
# `flutter run --release` on a dev machine with different flags.
#
# The new-ride-request alert is exactly what this plugin raises, so a silent
# failure here is a driver missing jobs without ever knowing there were any.
-keep class com.dexterous.** { *; }
-keep class com.dexterous.flutterlocalnotifications.models.** { *; }

# GSON needs generic signatures and its TypeToken machinery intact.
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
