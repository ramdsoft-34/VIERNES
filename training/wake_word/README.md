# Palabra de activación propia («Viernes»)

## Motores

| Motor | Tamaño | Descarga | Cómo funciona |
|---|---|---|---|
| **Propio** (por defecto) | ~2,5 MB dentro del APK | No | openWakeWord: melspectrograma → embeddings → clasificador entrenado solo para «Viernes» |
| **Vosk** (respaldo) | ~38 MB | Sí, dentro de la app | Reconocedor de voz general limitado a la palabra «viernes» |

Se elige en Ajustes → Activación por voz → Detector. Si el APK no trae el
modelo propio (`android/app/src/main/assets/wakeword/viernes.tflite`), la app
usa Vosk automáticamente.

## Arquitectura en el teléfono

`OpenWakeWordEngine.kt` (implementa `WakeWordEngine`, el servicio no cambia):

```text
audio 16 kHz (bloques de 80 ms)
  → melspectrogram.tflite   32 bandas por cada 10 ms   (openWakeWord, Apache 2.0)
  → embedding_model.tflite  96 valores cada 80 ms      (openWakeWord, Apache 2.0)
  → viernes.tflite          últimos 16 embeddings → probabilidad (propio)
```

Replica `openwakeword.utils.AudioFeatures` en modo streaming para que el
teléfono calcule lo mismo que el entrenamiento. Corre con LiteRT
(TensorFlow Lite). El umbral sale de la sensibilidad:
`0,85 − 0,5 × sensibilidad`, que da 0,6 en sensibilidad media.

## Entrenar (Google Colab, gratis)

1. Abre
   [`training/colab/viernes_ia.ipynb`](../colab/viernes_ia.ipynb) en Colab
   (GitHub → Colab) con GPU T4.
2. Ejecuta todo. El paso 5 corre `train_wakeword.py`:
   - **Positivos sintéticos**: «Viernes», «Oye Viernes», «¿Viernes?»… con 8
     voces Piper en español (España, México y Argentina) y variaciones de
     velocidad y entonación.
   - **Aumentos**: cambio de tono (simula más voces, incluidas femeninas),
     ruido, volumen y reverberación de habitaciones.
   - **Negativos difíciles**: palabras que suenan parecido («jueves»,
     «invierno», «vienes», «bienes»…) y frases del guion de grabación sin
     «Viernes».
   - **Negativos generales**: características precalculadas de openWakeWord
     (miles de horas de habla y ruido).
   - **Medición**: aciertos con una voz que no se usó al entrenar
     (`es_AR-daniela`), activaciones falsas por hora (~11 h de audio) y cuántas
     palabras parecidas lo activan. Sugiere el umbral.
3. Copia `viernes.tflite` a `android/app/src/main/assets/wakeword/` y
   compila.

## Mejorarlo con voces reales

La voz sintética no cubre todos los acentos. Para mejorarlo:

- **Grabaciones del guion** (`training/voice/guion-grabacion.md`): las frases
  con «Viernes» sirven como positivos reales y las demás como negativos.
- Súbelas a la carpeta de Drive y agrégalas como positivos en
  `train_wakeword.py` (función `make_clips`).
- Vuelve a entrenar y compara `wakeword_metrics.json` antes de reemplazar el
  modelo.
