# Registro de cambios

Formato basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/);
versionado [semántico](https://semver.org/lang/es/).

## [0.9.0] — Ubicación, compartir y más naturalidad

### Agregado
- **Varias tareas en una frase**: «recuérdame mañana a las 8 pagar la luz y
  llamar a mi mamá» crea un recordatorio por tarea.
- **Avisos relativos a otro recordatorio**: «avísame dos días antes del
  cumpleaños de Sofi» calcula la fecha desde tu agenda.
- **Recordatorios por ubicación**: «recuérdame comprar leche cuando llegue a
  casa» / «al salir del trabajo». Lugares guardados con tu ubicación actual
  (Ajustes → Lugares) y geocercas de Android que avisan con la app cerrada y
  se restauran solas al reiniciar el teléfono.
- **Recordatorios compartidos**: «recuérdale a Sofi recoger el paquete mañana
  a las 5». Le llega a su Viernes, y a ti te avisa cuando lo hace. Pestaña
  Enviados con el estado de cada uno.
- **Listas compartidas** en tiempo real (mercado, casa…): crear, invitar por
  correo, marcar y quitar. Por voz: «agrega leche y pan a la lista del
  mercado», «¿qué hay en la lista del mercado?».
- **Contactos** para compartir (viajan con tu cuenta).
- **Sonido al activarse** «Viernes» (se puede apagar).
- **Tras reiniciar el teléfono**, una notificación para reactivar la escucha.
- **Grabaciones de cada activación** (solo con consentimiento), etiquetadas
  como reales o por error, exportables para reentrenar el detector.
- «Cómo aprende Viernes»: comparación de **reglas frente a red neuronal**
  con tus frases reales.

### Técnico
- Base de datos v4: `places` y `location_reminders`.
- Reglas de Firestore para `shared_reminders` y `lists`.

## [0.8.0] — IA propia: detector «Viernes» e intérprete neuronal

### Agregado
- **Detector propio de «Viernes»** (openWakeWord + clasificador entrenado en
  Colab): viene dentro de la app (~3 MB), no descarga nada y gasta menos que
  Vosk. En Ajustes → Activación por voz → **Detector** se elige «Propio» o
  «Vosk» (respaldo). Medido en habla real que no vio: ~65 % de detección con
  una voz nueva y menos de una activación falsa por hora (sensibilidad media).
- **Red neuronal propia para entender frases** (en Dart, sin bibliotecas
  nativas): etiqueta tarea, fecha, hora, repetición, prioridad y anticipación,
  y clasifica la intención. Acierta el título en el 99 % de frases con tareas
  que nunca vio. Llena lo que las reglas no entienden.
- «Cómo aprende Viernes» → **Red neuronal propia**: versión, acierto, modo
  experimental «Títulos con la red neuronal» y un campo para probarla.
- Cuaderno de Colab (`training/colab/viernes_ia.ipynb`) que entrena los dos
  modelos; métricas en `training/results/`.

## [0.7.1] — Cancelar por voz

### Agregado
- **Cancelar en cualquier momento de la conversación**: «cancela», «olvídalo»,
  «nada», «ya no quiero», «ya no lo necesito», «no hace falta», «mejor no»,
  «después te digo»… Funciona al principio, cuando Viernes pregunta la hora o
  qué recordar, y en la confirmación.
- **Si se activó por error**: «me equivoqué», «fue sin querer», «no te estaba
  hablando», «falsa alarma» → «Está bien. Aquí estoy si me necesitas.»
- **En la alerta**: «ya no lo necesito», «cancélalo», «bórralo» o «ya no me lo
  recuerdes» eliminan el recordatorio (queda en el historial).

### Corregido
- En la alerta, «ya no…» se tomaba como «ya lo hice» por empezar con «ya».

## [0.7.0] — Cuentas con Google y respaldo en la nube

### Agregado
- **Iniciar sesión con Google** con un toque (Firebase Auth). La sesión queda
  abierta aunque se cierre la app o se reinicie el teléfono.
- **Bienvenida** en la primera apertura: «Continuar con Google» o «Usar sin
  cuenta» (se puede iniciar sesión después desde Ajustes).
- **Respaldo en la nube** (Cloud Firestore) de recordatorios, historial y
  preferencias, vinculado a cada cuenta. Al iniciar sesión en otro teléfono
  se recupera todo, alarmas incluidas.
- **Sincronización automática** unos segundos después de cada cambio (también
  los hechos desde la notificación), al abrir la app y al volver a ella. Funciona
  sin internet: los cambios esperan y se suben solos.
- Lo que había **sin cuenta se une** a la cuenta al iniciar sesión.
- Ajustes → **Cuenta**: foto y nombre, estado de la sincronización, cambios
  por subir, «Sincronizar ahora», **Cerrar sesión** (sube lo pendiente, avisa
  si no hay internet y limpia el teléfono) y **Eliminar mi cuenta** (pide
  confirmar con Google y borra todo).
- Reglas de seguridad de Firestore (`firebase/firestore.rules`): cada usuario
  solo ve lo suyo.
- Guía paso a paso en `docs/CUENTAS.md` y decisión en `docs/adr/0002`.

### Técnico
- Base de datos v3: `dirty`, `sync_id` y `sync_tombstones` (migración
  automática).
- Sin `google-services.json` la app compila y funciona sin cuentas.

## [0.6.0] — Fase 6: IA propia v1 (aprende de ti)

### Agregado
- **Aprendizaje personal en el teléfono** (sin internet), que se reentrena
  solo con cada cambio:
  - **Categorías**: clasificador Naive Bayes que aprende tu vocabulario
    («Sofi» → Personal, «daily» → Trabajo). Tus elecciones manuales pesan el
    doble. Precisión medida con validación cruzada.
  - **Tus horarios**: «en la tarde» pasa a ser la hora a la que sueles
    agendar (p. ej. 4:00 p. m.) en vez de 3:00 p. m. fijo.
  - **Tu anticipación habitual** por categoría.
- **Intérprete híbrido**: reglas + modelo personal; lo que dices
  explícitamente siempre manda.
- **Sugerencia de categoría** al escribir un recordatorio a mano.
- Pantalla **«Cómo aprende Viernes»** (Ajustes → Privacidad e IA): qué
  aprendió, su porcentaje de acierto, tus horarios, conversaciones entendidas
  a la primera, y opción para apagar el aprendizaje.
- **Exportar frases (JSONL)** para entrenar el futuro modelo neuronal; tú
  eliges a dónde enviarlas.
- Documentación del formato y del plan v2 en `training/nlu/README.md`.

## [0.5.0] — Fase 5: resúmenes, widget y estadísticas

### Agregado
- **Resumen de la mañana** (7:00 por defecto): «Buenos días ☀️ — Hoy tienes 3
  pendientes: entregar el informe a las 8 de la mañana…».
- **Resumen de la noche** (9:00 p. m.): «Quedaron 2 sin confirmar: … ¿Las paso
  a mañana?» con botón **Pasar a mañana**, que funciona con la app cerrada.
- Los resúmenes de los próximos 7 días se recalculan solos con cada cambio,
  así el texto siempre coincide con la agenda real.
- **«Pasar a mañana»** también en Inicio, junto a los vencidos (los que se
  repiten no se mueven).
- **Widget** para la pantalla de inicio: cuántos pendientes hay hoy, los 3
  próximos (los vencidos en rojo) y un botón de micrófono que abre la
  conversación. Se agrega desde Ajustes → Resúmenes.
- **Historial**: gráfico de completados en los últimos 7 días y «Lo que más
  pospones».
- **Recordatorios**: filtro por categoría.

### Corregido
- Los resúmenes y la agenda hablada respetan los nombres propios y las siglas
  («llamar a Juan», no «llamar a juan»).

## [0.4.0] — Fase 4: di «Viernes» para activarlo

### Agregado
- **Activación por voz**: servicio nativo en primer plano (tipo micrófono) que
  escucha solo la palabra «Viernes», **sin internet**, y abre la conversación
  «Te escucho». Funciona con la app cerrada y con el teléfono bloqueado.
- Motor `VoskWakeWordEngine` (Vosk, gramática de una palabra) detrás de la
  interfaz `WakeWordEngine`, lista para cambiarlo por un modelo openWakeWord
  propio (ver `training/wake_word/README.md`).
- El modelo de voz en español (~38 MB) se descarga dentro de la app al
  activar la función, con barra de progreso; se puede borrar.
- Ajustes → «Activación por voz»: activar/desactivar, **sensibilidad** y
  permiso opcional «abrir al instante sobre otras apps».
- Notificación permanente «Viernes está atento» con botón «Desactivar».
- El micrófono se comparte: la escucha se pausa durante la conversación y al
  responder una alerta por voz, y se reanuda al terminar.

### Corregido
- **Notificaciones en el APK de producción**: R8 eliminaba el ícono de las
  notificaciones (se usa por nombre), lo que hacía fallar los avisos en
  silencio. Ahora se conserva con `res/raw/keep.xml`.

## [0.3.0] — Fase 3: Viernes avisa y hace seguimiento

### Agregado
- **Alarmas exactas** (funcionan con el teléfono en reposo) para cada
  recordatorio, que se reprograman solas al crear, editar, completar, posponer,
  reabrir o eliminar.
- **Notificación con botones** «✓ Ya lo hice» y «⏰ Recordar después», que
  funcionan incluso con la app cerrada.
- **Alerta a pantalla completa** sobre la pantalla de bloqueo: tarea, fecha,
  botones grandes, opciones para posponer (5 min a mañana) y **respuesta por
  voz** («ya lo hice», «todavía no», «en 20 minutos»). Viernes lee la tarea en
  voz alta.
- **Insistencia progresiva**: si no respondes, vuelve a avisar a los 10, 30 y
  60 minutos; la última vez suena hasta que la atiendas.
- **Prioridad urgente**: canal de máxima importancia con sonido de alarma.
- **Horario de silencio**: lo no urgente avisa sin sonido y no insiste.
- Los avisos sobreviven al reinicio del teléfono y se reprograman al abrir la
  app o al cambiar los ajustes de alertas.
- Permisos: tarjeta en Inicio si faltan los esenciales y sección «Permisos» en
  Ajustes (notificaciones, alarmas exactas, pantalla completa).

### Técnico
- Repositorio decorador `SchedulingReminderRepository`: ningún caso de uso
  tiene que acordarse de las alarmas.
- Planificador puro `AlertPlanner` (probado) e ids de notificación estables
  (FNV-1a).
- Puente nativo `MainActivity.kt`: mostrar sobre la pantalla de bloqueo solo
  durante la alerta y consultar el permiso de pantalla completa (Android 14+).
- Base de datos con `busy_timeout` y refresco al volver a la app, porque los
  botones de la notificación escriben desde otro proceso de Flutter.

## [0.2.0] — Fase 2: Viernes entiende y habla

### Agregado
- **Intérprete propio en español** (motor de reglas `rules-es-1.0`): fechas
  ("mañana", "el lunes", "el 20 de octubre", "pasado mañana", "fin de mes"),
  horas ("a las 2 de la tarde", "8 y media", "10 menos cuarto", "9 pm",
  "mediodía"), franjas ("en la tarde", "esta noche", "temprano"), tiempo
  relativo ("en 20 minutos", "en una hora y media"), límites ("antes de las 8"),
  repeticiones ("todos los lunes y miércoles", "el 5 de cada mes", "de lunes a
  viernes", "cada 15 días"), prioridad ("urgente", "sin prisa"), anticipación
  ("avísame 15 minutos antes") y categoría automática.
- Limpieza del título: quita "recuérdame", "tengo que", "por favor"… y conserva
  tildes y mayúsculas.
- Consultas de agenda: "¿qué tengo hoy / mañana / esta semana?".
- Conversación por voz: "Te escucho" → escucha → pregunta lo que falta →
  confirma en voz alta → guarda. Si no oye nada: "No te escuché, dime qué
  necesitas recordar".
- Correcciones habladas ("no, a las 9", "mejor el jueves") y respuestas cortas
  ("tres", "a las 3") cuando Viernes pregunta.
- Botones Guardar / Editar / Cancelar / Hablar durante la confirmación; "Editar"
  abre el formulario con lo entendido.
- Dataset para entrenar la IA propia (tabla `nlu_samples`, esquema v2), solo con
  consentimiento; contador y borrado en Ajustes.
- Permisos de micrófono y declaración de servicios de voz en Android.

### Cambiado
- Una hora como "a las 8" sin "mañana/noche" se resuelve según el día elegido:
  hoy después de las 8 a. m. es en la noche; otro día, en la mañana.

## [0.1.0] — Fase 1: base de la app

### Agregado
- Arquitectura limpia organizada por funcionalidades (dominio, datos y presentación).
- Base de datos local (Drift/SQLite) con recordatorios e historial de eventos.
- Recordatorios con fecha límite, anticipación, repetición (diaria, lunes a viernes,
  semanal por días, mensual y anual), prioridad y categoría.
- Acciones: completar (con deshacer), posponer, reabrir, editar y eliminar (con deshacer).
- Pantallas: Inicio, Recordatorios (pendientes, pospuestos, completados), Calendario,
  Historial con estadísticas (racha, a tiempo, pospuestos) y Ajustes.
- Ajustes persistentes: anticipación, posponer, alertas, insistencia, horario de
  silencio, resúmenes, confirmación por voz, consentimiento de datos para la IA y tema.
- Versiones `dev` y `prod` instalables en paralelo.
- Textos en archivos ARB, listos para traducir.
- Pruebas unitarias, de base de datos y de widgets; CI con GitHub Actions.
