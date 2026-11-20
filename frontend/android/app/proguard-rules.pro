# Flutter ProGuard rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-dontwarn io.flutter.embedding.**
-dontwarn io.flutter.plugins.**

# Keep references to MainActivity
-keep class com.jobeval.app.MainActivity { *; }

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}