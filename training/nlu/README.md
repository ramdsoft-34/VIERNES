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

## v2 (siguiente): modelo neuronal en el teléfono

Cuando haya unos cientos de conversaciones reales:

1. **Etiquetar**: convertir cada `utterances[0]` + `final` en etiquetas por
   palabra (BIO: `TAREA`, `FECHA`, `HORA`, `REPETICIÓN`, `PRIORIDAD`) y la
   intención (`crear`, `consultar`).
2. **Aumentar**: generar variaciones con plantillas («mañana a las {hora}
   {tarea}», «recuérdame {tarea} el {día}») para cubrir lo poco frecuente.
3. **Entrenar** un etiquetador pequeño (BiLSTM-CRF o un transformer
   distilado en español) en Colab.
4. **Exportar** a TensorFlow Lite (<5 MB) y cargarlo en
   `lib/ai/nlu/ml/` como otro `ReminderInterpreter`.
5. **Combinar** en `HybridInterpreter`: usar el modelo si su confianza supera
   la de las reglas; medir con `AccuracyReport` antes y después.

Regla de oro: el modelo nuevo solo reemplaza a las reglas cuando su
porcentaje de «entendidas a la primera» es mayor con los mismos datos.
