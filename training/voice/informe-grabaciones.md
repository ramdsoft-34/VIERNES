# Informe de grabaciones · Voz de Viernes (frases 1–180)

Seis notas de voz del iPhone: dos tomas (V1 y V2) de las frases 1–65, 66–115
y 116–180 del [guion](guion-grabacion.md). Analizadas el 5 de octubre de 2026.

## Resumen

| Aspecto | Resultado | Veredicto |
|---|---|---|
| Duración total | 11,1 min (≈ 9,2 min de voz) | Bien para probar; poco para entrenar |
| Frases distintas | 180 de 463 (39 %), cada una con 2 tomas | Faltan 283 |
| Formato | AAC comprimido 64 kbps, 44,1/48 kHz, mono | Mejorable: grabar «sin pérdida» |
| Ruido de fondo | −57 a −62 dBFS (relación voz/ruido ≈ 44 dB) | Excelente, cuarto silencioso |
| Saturación | 0 muestras saturadas | Bien |
| Picos | hasta −0,3 dBFS | Al límite: alejarse un poco del micrófono |
| Volumen de la voz | V1 ≈ −18,5 dBFS (V1 1–65 más bajo: −22), V2 ≈ −16,5 | Parejo tras nivelar |
| Claridad | El reconocedor entendió 357 de 360 frases completas | Excelente dicción |
| Ritmo | 3,1 palabras/s de mediana; 36 tomas por encima de 4,2 | Algo rápido en frases cortas |
| Pausas entre frases | Muy cortas (a veces < 0,2 s) | Dejar 1 s de silencio entre frases |

## Cómo se procesó

1. Se pasaron a WAV y Vosk (español) ubicó cada palabra en el tiempo.
2. Cada frase del guion se alineó con lo reconocido: las 180 frases de las
   dos tomas quedaron ubicadas (358 de 360 con certeza alta).
3. Se recortaron los bordes buscando el silencio real, se quitó el retumbe
   grave (filtro de 70 Hz), se niveló cada frase a la misma sonoridad
   (−19 dBFS de voz, pico máximo −1,5 dBFS) y se suavizaron los bordes.
4. Para cada frase se eligió la mejor toma: la que mejor se entendió, sin
   bordes cortados, sin picos al límite y que necesitó menos ganancia.
   Quedaron 121 de V1 y 59 de V2. Solo la 161 («Doscientos treinta y
   cuatro») tiene las dos tomas con el inicio algo pegado.

Los recortes están en `assets/voice/` (no se suben a GitHub: es la voz de
una persona).

## ¿Alcanza para entrenar?

- **Para que Viernes diga estas frases con su voz: sí.** Ya funciona en la
  app (Ajustes → Asistente → Voz grabada).
- **Para una voz que diga cualquier cosa (modelo de texto a voz): todavía
  no.** Hay unos 4–5 minutos de frases distintas. Un modelo propio necesita,
  como mínimo, 30 minutos de frases distintas (el guion completo más la
  lectura continua del bloque 17) y, para sonar natural, cerca de una hora.

## Recomendaciones para las próximas grabaciones

1. iPhone → Ajustes → Apps → Notas de voz → Calidad de audio: **Sin
   pérdida**.
2. Mismo lugar, misma distancia (un palmo, el teléfono un poco de lado) y
   misma hora del día para que la voz suene igual.
3. **Un segundo de silencio** entre frase y frase, y empezar cada grabación
   con 2 segundos de silencio.
4. Hablar un poco más pausado en las frases cortas («A la orden», «¿A qué
   hora?»).
5. Con dos tomas por frase basta; si una sale mal, repetirla en el momento
   diciendo el número otra vez no hace falta: el alineador la descarta.
6. Siguiente lote: frases 181–463 (bloques 8 a 17).

## Repetir el proceso

Los scripts están en `training/voice/tools/`: `analyze.py` (medidas),
`asr_align.py` (ubicar frases con Vosk) y `cut.py` (recortar, nivelar,
elegir toma y exportar a la app). Requieren Python con `numpy` y `vosk`,
`ffmpeg` y el modelo `vosk-model-small-es-0.42`.
