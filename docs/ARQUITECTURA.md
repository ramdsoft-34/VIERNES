# Arquitectura de Viernes

## Principios

1. **Clean Architecture por funcionalidad.** Cada carpeta de `lib/features/` tiene
   `domain/`, `data/` y `presentation/`.
2. **El dominio es Dart puro.** No conoce Flutter, SQLite ni la IA. Ahí viven las
   reglas de negocio y es lo más probado.
3. **Las dependencias apuntan hacia adentro:** presentación → dominio ← datos.
4. **Todo lo intercambiable va detrás de una interfaz:** repositorios, reloj,
   generador de IDs y, en las próximas fases, voz, intérprete y alarmas.
5. **Errores tipados.** Los casos de uso devuelven `Result<T>` (`Ok` / `Err` con una
   `Failure`), nunca lanzan excepciones hacia la UI.

## Capas

```
presentation  Pantallas, widgets, providers de Riverpod
     │
     ▼
domain        Entidades inmutables, casos de uso, contratos (interfaces)
     ▲
     │
data          Implementaciones: Drift, SharedPreferences, mapeos
```

## Estructura

```
lib/
├── main.dart / main_dev.dart / main_prod.dart
├── app/            arranque, versiones, providers globales, router, tema
├── core/           errores, base de datos, utilidades, widgets comunes
├── features/
│   ├── account/    inicio de sesión con Google, bienvenida, cerrar y eliminar cuenta
│   ├── sync/       sincronización base local ⇄ Firestore
│   ├── reminders/  entidades, casos de uso, repositorio, editor y lista
│   ├── home/       pantalla de inicio
│   ├── calendar/   calendario y proyección de repeticiones
│   ├── history/    historial y estadísticas
│   ├── settings/   preferencias
│   └── voice_assistant/  (Fase 2) escucha, intérprete y confirmación
└── l10n/           textos (ARB) y código generado
```

## Modelo de datos

**Recordatorio** (`reminders`): qué hacer, fecha límite (`dueAt`), anticipación
(`leadTime`), regla de repetición (formato tipo RRULE), prioridad, categoría,
estado (`pending`, `snoozed` o `completed`), aplazamiento, origen (manual o voz),
frase original y confianza de la IA.

- `remindAt = dueAt − leadTime`: cuándo se avisa.
- `nextTriggerAt`: `snoozedUntil` si está pospuesto; si no, `remindAt`.
- Un recordatorio que se repite **no se completa**: registra el evento y avanza a la
  siguiente ocurrencia futura.

**Evento** (`reminder_events`): historial inmutable (creado, completado, pospuesto,
eliminado…). Es la base de las estadísticas y se conserva aunque se borre el
recordatorio. Para "a tiempo" se usa `onTime`.

**Sincronización** (esquema v3): `reminders.dirty` y `reminder_events.dirty`
marcan lo que falta subir; `reminder_events.sync_id` identifica cada evento en
la nube; `sync_tombstones` guarda los borrados pendientes. Ver
[CUENTAS.md](CUENTAS.md).

## Flujo de una acción

```
Widget → ReminderActions → CompleteReminder (caso de uso)
       → ReminderRepository.save(reminder, event)   [transacción]
       → Drift notifica el stream → providers → UI se actualiza sola
```

## Inteligencia (`lib/ai/`)

```
ai/
├── ai_providers.dart        piezas intercambiables (sobrescribibles en pruebas)
├── speech/                  voz ↔ texto
│   ├── speech_recognizer.dart   contratos SpeechRecognizer y Speaker
│   ├── android_speech_recognizer.dart
│   └── tts_speaker.dart
├── nlu/                     entender frases
│   ├── interpretation.dart      ParsedReminder, Interpretation, AgendaQuery
│   ├── reminder_interpreter.dart  contrato
│   └── es/                      todo lo específico del español
│       ├── spanish_rule_interpreter.dart   motor de reglas
│       ├── spanish_reply_parser.dart       sí / no / corrección
│       ├── spanish_speech.dart             frases que dice Viernes
│       ├── category_classifier.dart
│       └── spanish_text.dart               normalización y números
└── dataset/                 ejemplos para entrenar (con consentimiento)
```

**Cómo interpreta una frase.** Normaliza el texto (minúsculas y sin tildes,
**conservando la longitud**), busca expresiones en orden (anticipación →
repetición → tiempo relativo → hora → franja → fecha → prioridad) y "reclama"
sus posiciones. Lo que sobra, sin muletillas, es el título, recortado del texto
original para conservar tildes y mayúsculas.

**`ParsedReminder` guarda partes, no una fecha final.** Así una corrección
("no, a las 9") cambia solo la hora, y decisiones como "¿8 de la mañana o de la
noche?" se toman en `resolveDue(now)` cuando ya se conoce el día.

**Conversación** (`features/voice_assistant/`): `VoiceAssistantController` es
una máquina de estados (escuchando → pensando → confirmando → listo/falló) que
recibe la voz y los botones por el mismo canal de decisiones.

**Aprendizaje personal (v0.6, `ai/learning/`):** `PersonalModel` se
reentrena en el teléfono con cada cambio de los recordatorios: un clasificador
Naive Bayes de categorías y los hábitos del usuario (horarios por franja,
anticipación por categoría). `HybridInterpreter` aplica lo aprendido sobre el
resultado de las reglas. Detalle y formato de datos en `training/nlu/`.

**Camino al modelo neuronal:** cada conversación guardada con
consentimiento deja en `nlu_samples` la frase, lo que entendió el motor de
reglas y lo que finalmente se guardó. Con esos pares se entrena un modelo
TFLite que implementará `ReminderInterpreter`; un intérprete híbrido usará el
modelo cuando tenga confianza alta y las reglas en caso contrario.

## Cuentas y nube (`features/account`, `features/sync`)

```
AuthRepository ── FirebaseAuthRepository (Google + Firebase Auth)
               └─ UnavailableAuthRepository (sin google-services.json)
AccountService: iniciar sesión → asociar datos del teléfono → sincronizar
                cerrar sesión → subir pendientes → borrar datos locales
SyncEngine:     push (dirty + tombstones) → pull (desde el cursor) → aplicar
SyncController: cuándo sincronizar (inicio, volver a la app, cambios, manual)
RemoteSyncSource ── FirestoreSyncSource (users/{uid}/...)
```

La base local sigue siendo la fuente de verdad: la app funciona igual sin
internet y sin cuenta. Cambiar de proveedor de nube es otra implementación de
`RemoteSyncSource` y `AuthRepository`.

## Decisiones (ADR)

Ver `docs/adr/`.

## Cómo agregar una funcionalidad

1. Entidades y contrato en `domain/`, con sus pruebas.
2. Caso de uso que devuelva `Result<T>`, con pruebas usando `FakeReminderRepository`.
3. Implementación en `data/`.
4. Providers y pantallas en `presentation/`; textos en `lib/l10n/arb/app_es.arb`.
5. `flutter analyze` sin problemas y `flutter test` en verde.
