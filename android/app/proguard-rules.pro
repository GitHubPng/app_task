# flutter_local_notifications serializa os avisos agendados com Gson.
# Sem estas regras, o R8 do build de release remove as assinaturas
# genéricas e o agendamento falha ("Missing type parameter").
# Fonte: README do plugin → regras do Gson.

-keep class com.dexterous.** { *; }

-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**

-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}

-keep,allowobfuscation,allowshrinking class com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class * extends com.google.gson.reflect.TypeToken
