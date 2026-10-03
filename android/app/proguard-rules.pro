# Vosk llama a su biblioteca nativa a través de JNA, que usa reflexión:
# si R8 renombra o elimina estas clases, el modelo no carga en release.
-keep class com.sun.jna.** { *; }
-keep class * implements com.sun.jna.** { *; }
-keep class org.vosk.** { *; }
-dontwarn java.awt.**
-dontwarn com.sun.jna.**
