# ==============================================================================
# Split Reflex - ProGuard / R8 Optimization & Obfuscation Rules for Play Store
# ==============================================================================

# Flutter Engine & Architecture
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Keep native methods and JNI bindings
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep Serializable and Parcelable implementations
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}
-keep class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

# Generated Plugin Registrant
-keep public class io.flutter.plugins.GeneratedPluginRegistrant {
    public *;
}

# AndroidX and Support Annotations
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keepattributes Signature
-keepattributes InnerClasses,EnclosingMethod

# Flutter Play Core Deferred Components (optional Play Store dynamic modules)
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**

# Audioplayers & Native Audio Services
-keep class xyz.luan.audioplayers.** { *; }

# Sensors Plus
-keep class dev.fluttercommunity.plus.sensors.** { *; }

# Battery Plus
-keep class dev.fluttercommunity.plus.battery.** { *; }

# Vibration Plugin
-keep class com.benjaminabel.vibration.** { *; }

# Supabase / HTTP / WebSockets client models
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**
-dontwarn kotlin.**

# Optimize and remove unused code aggressively
-repackageclasses ''
-allowaccessmodification
