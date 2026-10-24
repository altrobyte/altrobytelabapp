# Altron's wake word (Vosk) reaches its native library through JNA, which finds classes and fields by name at run time.
# The release shrinker renamed them and the app crashed at start ("Can't obtain peer field ID for class com.sun.jna.Pointer").
-keep class com.sun.jna.** { *; }
-keep class * implements com.sun.jna.** { *; }
-keep class org.vosk.** { *; }
-dontwarn java.awt.**
