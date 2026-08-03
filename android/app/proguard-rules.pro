# ProGuard/R8 rules for the release build.
#
# R8 shrinks and obfuscates the Dart-hosting Android layer. Flutter and the
# Firebase SDKs rely on reflection in places R8 cannot see, so the classes they
# look up by name must be kept or the app crashes at runtime with a
# ClassNotFoundException that only reproduces in release.

# --- Flutter engine / embedding ---------------------------------------------
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Flutter's embedding references Play Core (deferred components / split
# install) unconditionally, but this app does not ship the Play Core library
# and does not use deferred components. Without this, R8 fails the build on
# ~11 "Missing class com.google.android.play.core.*" errors. The referencing
# code paths are never reached at runtime.
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**
-dontwarn io.flutter.embedding.android.FlutterPlayStoreSplitApplication

# --- Firebase ----------------------------------------------------------------
# Firestore/Auth deserialize into model classes via reflection, and Crashlytics
# style tooling reads annotations off them.
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Firebase Messaging resolves the background service + receivers by name from
# the manifest.
-keep class com.google.firebase.messaging.** { *; }

# --- Google Sign-In ----------------------------------------------------------
-keep class com.google.android.gms.auth.** { *; }

# --- Kotlin ------------------------------------------------------------------
-dontwarn kotlin.**
-keep class kotlin.Metadata { *; }

# --- Keep annotations and signatures needed for generics/reflection ----------
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# Line numbers make release stack traces readable; the source file name itself
# is renamed so it leaks nothing.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
