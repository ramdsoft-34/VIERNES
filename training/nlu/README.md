# IA propia de Viernes: intérprete

## v1 (app 0.6): aprendizaje personal en el teléfono

Sin servidores ni internet. Se reentrena sola cada vez que cambian los
recordatorios (`lib/ai/learning/`):

| Pieza | Qué aprende | Técnica |
|---|---|---|
| `CategoryModel` | Vocabulario propio por categoría («Sofi» → Personal) | Naive Bayes multinomial con suavizado de Laplace; las elecciones manuales pesan ×2; precisión medida con validación cruzada de 5 particiones |
| `PersonalHabits` | Hora habitual de «en la mañana/tarde/noche»; anticipación habitual por categoría | Mediana redondeada a 15 min (≥3 ejemplos); moda de la anticipación si es clara (≥50 %) |
| `HybridInterpreter` | Combina reglas + lo aprendido | Reglas primero; el modelo cambia la categoría con confianza ≥ 0,75 (≥ 0,5 si las reglas dijeron «Otra») |

## Datos exportados (JSONL)

Ajustes → Cómo aprende Viernes → **Exportar frases**. Una conversación por
línea (solo si el usuario activó «Ayudar a entrenar a Viernes»):

```json
{"utterances":["mañana a las 8 correr","no, a las 9","sí"],
 "initial":{"title":"Correr","date":"2026-10-02T00:00:00.000","time":"8:0",
            "dayPeriod":null,"exactDue":null,"isDeadline":false,
            "leadTimeMinutes":null,"recurrence":null,"priority":null,
            "category":"health","ambiguousHour":true},
 "final":{"title":"Correr","dueAt":"2026-10-02T09:00:00.000",
          "leadTimeMinutes":15,"recurrence":null,"priority":"normal",
          "category":"health"},
 "corrected":true,"confidence":1.0,"interpreter":"rules-es-1.0",
 "createdAt":"2026-10-01T10:00:00.000"}
```

- `initial`: lo que entendió el intérprete con la primera frase.
- `final`: lo que se guardó tras preguntas y correcciones (la «respuesta
  correcta»).
- `corrected`: si hizo falta preguntar o corregir algo.

## v2 (app 0.8): red neuronal propia en el teléfono

`lib/ai/nlu/ml/`: corre en **Dart puro** (sin bibliotecas nativas), ~450 KB.

```text
palabra → embedding(48) + terminación(16) → conv1d(96, k=3) → conv1d(96, k=3)
  ├─ por palabra: etiquetas BIO (TAREA, FECHA, HORA, REP, PRIO, ANTIC)
  └─ máximo global: intención (crear, consultar, cancelar, otro)
```

- **Entrenamiento**: `train_nlu.py` (paso 4 del cuaderno de Colab). Usa
  frases sintéticas etiquetadas por construcción (`nlu_data.py`: cientos de
  verbos × objetos × fechas × horas, con palabras inventadas para que aprenda
  por el contexto) y, si existen, las frases reales exportadas por la app
  (`*.jsonl` en la carpeta de Drive), que pesan 5 veces más.
- **Medición honesta**: separa verbos, objetos y plantillas que nunca ve al
  entrenar («tareas no vistas»).
- **Paridad**: `nlu_parity.json` (en `test/fixtures/`) verifica que Dart dé
  las mismas probabilidades que Keras.
- **Uso en la app** (`HybridInterpreter`): las reglas siguen mandando. La red
  crea el recordatorio cuando las reglas no entendieron (intención ≥ 0,85) y
  llena el título cuando faltó. Con «Títulos con la red neuronal»
  (experimental) decide el título si está muy segura (≥ 0,9).

### Para actualizar el modelo

1. Exporta frases desde la app (Ajustes → Cómo aprende Viernes) y súbelas a la
   carpeta de Drive `IA-Viernes`.
2. Ejecuta el cuaderno. Revisa `nlu_metrics.json`.
3. Copia `nlu_model.json` a `assets/ai/` y `nlu_parity.json` a
   `test/fixtures/`; corre `flutter test`.

Regla de oro: el modelo nuevo solo reemplaza al anterior si mejora con los
mismos datos.
