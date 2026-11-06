# LOVE / SDL are called from native code by name.
-keep class org.love2d.android.** { *; }
-keep class org.libsdl.app.** { *; }
-keep class com.wearports.firered.** { *; }
-dontwarn org.love2d.android.**
