# Palabra de activación propia («Viernes»)

## Hoy (v0.4)

El servicio `WakeWordService.kt` usa la interfaz `WakeWordEngine` con
`VoskWakeWordEngine`: el modelo pequeño de Vosk en español (38 MB, se descarga
en la app), con una gramática de una sola palabra (`viernes` / `[unk]`).
Funciona sin internet y sin entrenamiento, pero es más pesado y menos preciso
que un detector dedicado.

## Meta (Fase 6): modelo propio con openWakeWord

Un detector entrenado solo para «Viernes» pesa ~200 KB, gasta menos batería y
tiene menos falsas activaciones.

1. **Datos positivos sintéticos**: generar miles de grabaciones de «Viernes» y
   «Oye Viernes» con voces TTS en español (Piper `es_ES`/`es_MX`), variando
   velocidad, tono y ruido.
2. **Datos reales (opcional, con consentimiento)**: activaciones confirmadas y
   falsas guardadas por la app en el teléfono.
3. **Negativos**: habla en español sin la palabra (Common Voice ES) + ruido
   ambiente (MUSAN, AudioSet).
4. **Entrenar** con el notebook de openWakeWord (`automatic_model_training`)
   en Colab con GPU. Salida: `viernes.onnx` (o `.tflite`).
5. **Integrar**: `OpenWakeWordEngine` (Kotlin) con ONNX Runtime Android,
   que encadena `melspectrogram.onnx` → `embedding_model.onnx` →
   `viernes.onnx`, e implementa `WakeWordEngine`. El servicio no cambia.
6. **Medir** antes de reemplazar a Vosk: falsas activaciones por hora y
   porcentaje de detección en ruido real.
