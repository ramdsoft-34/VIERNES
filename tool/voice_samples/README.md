# Voces de prueba para el reconocimiento del dueño

`SpeakerVerifierTest` mide si la activación por voz acepta a quien registró
su voz y rechaza a otras personas. Usa voces sintéticas de Windows
(Helena, Laura y Pablo, español de España).

1. Generar las grabaciones (PowerShell, Windows 10/11 con esas voces):

       powershell -File tool/voice_samples/generate.ps1

   Cambia `$out` en el script por la carpeta donde quieres los WAV.

2. Pasarlas a PCM 16 kHz mono (con ffmpeg), una limpia y otra con ruido:

       for f in raw_*.wav; do b=${f#raw_}; ffmpeg -y -i "$f" -af "adelay=300|300,apad=pad_dur=0.4" -ar 16000 -ac 1 -f s16le "${b%.wav}.pcm"; done

3. Correr la prueba:

       cd android
       VIERNES_VOICES=/ruta/a/las/grabaciones ./gradlew :app:testProdDebugUnitTest --tests "*SpeakerVerifierTest"

Sin la variable `VIERNES_VOICES` la prueba de voces se salta.
