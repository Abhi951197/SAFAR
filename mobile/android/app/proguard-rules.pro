# flutter_local_notifications stores scheduled notifications through Gson.
# R8 can strip generic signatures needed by Gson TypeToken in release builds,
# which causes "Missing type parameter" crashes when reading/canceling alarms.
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses
-keep class com.google.gson.reflect.TypeToken
-keep class * extends com.google.gson.reflect.TypeToken
-keep public class * implements java.lang.reflect.Type
