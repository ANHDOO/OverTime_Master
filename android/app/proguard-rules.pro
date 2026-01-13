-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class com.dexterous.flutterlocalnotifications.models.** { *; }
-keep class androidx.core.app.NotificationCompat** { *; }

# Gson specific rules
-keep class com.google.gson.** { *; }
-keep class com.google.gson.reflect.TypeToken { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# Fix for Missing type parameter
-keep class * extends com.google.gson.reflect.TypeToken

# Google ML Kit rules
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_** { *; }
-keep class com.google.android.gms.common.internal.safeparcel.SafeParcelable { *; }
-keep class * extends com.google.android.gms.common.internal.safeparcel.SafeParcelable
-keep class com.google.mlkit.vision.text.** { *; }

# Ignore missing optional ML Kit language models
-dontwarn com.google.mlkit.vision.text.**
-dontwarn com.google.android.gms.internal.mlkit_vision_text_common.**
