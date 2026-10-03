// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appName => 'Viernes';

  @override
  String get navHome => 'Ahora';

  @override
  String get navReminders => 'Pendientes';

  @override
  String get navCalendar => 'Calendario';

  @override
  String get navHistory => 'Progreso';

  @override
  String get navSettings => 'Ajustes';

  @override
  String get greetingMorning => 'Buenos días';

  @override
  String get greetingAfternoon => 'Buenas tardes';

  @override
  String get greetingEvening => 'Buenas noches';

  @override
  String homeTodaySummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Hoy tienes $count pendientes',
      one: 'Hoy tienes 1 pendiente',
      zero: 'No tienes pendientes para hoy',
    );
    return '$_temp0';
  }

  @override
  String homeOverdueSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vencidos sin confirmar',
      one: '1 vencido sin confirmar',
    );
    return '$_temp0';
  }

  @override
  String get homeSectionOverdue => 'Vencidos sin confirmar';

  @override
  String get homeSectionUpcoming => 'Próximos';

  @override
  String get homeEmptyTitle => 'Todo en orden';

  @override
  String get homeEmptyBody =>
      'Toca el micrófono o el botón + para crear tu primer recordatorio.';

  @override
  String get homeSeeAll => 'Ver todos';

  @override
  String get voiceButtonLabel => 'Hablar con Viernes';

  @override
  String get voiceButtonHint => 'Toca y dime qué necesitas recordar';

  @override
  String get voiceStarting => 'Un momento…';

  @override
  String get voiceListening => 'Escuchando';

  @override
  String get voiceWhenMissing => 'Falta la fecha o la hora';

  @override
  String get voiceSpeak => 'Hablar';

  @override
  String get voiceDone => 'Listo';

  @override
  String get voiceClose => 'Cerrar';

  @override
  String get voiceTryAgain => 'Intentar de nuevo';

  @override
  String get newReminder => 'Nuevo recordatorio';

  @override
  String get editReminder => 'Editar recordatorio';

  @override
  String get remindersTabPending => 'Pendientes';

  @override
  String get remindersTabSnoozed => 'Pospuestos';

  @override
  String get remindersTabCompleted => 'Completados';

  @override
  String get remindersEmptyPendingTitle => 'Sin pendientes';

  @override
  String get remindersEmptyPendingBody =>
      'Cuando crees un recordatorio aparecerá aquí.';

  @override
  String get remindersEmptySnoozedTitle => 'Nada pospuesto';

  @override
  String get remindersEmptySnoozedBody =>
      'Lo que dejes para después se mostrará aquí.';

  @override
  String get remindersEmptyCompletedTitle => 'Aún no hay completados';

  @override
  String get remindersEmptyCompletedBody =>
      'Confirma tus tareas con «Ya lo hice» y aparecerán aquí.';

  @override
  String get actionComplete => 'Ya lo hice';

  @override
  String get actionSnooze => 'Recordar después';

  @override
  String get actionEdit => 'Editar';

  @override
  String get actionDelete => 'Eliminar';

  @override
  String get actionReopen => 'Marcar como pendiente';

  @override
  String get actionUndo => 'Deshacer';

  @override
  String get actionSave => 'Guardar';

  @override
  String get actionCancel => 'Cancelar';

  @override
  String get actionMore => 'Más opciones';

  @override
  String get feedbackCompleted => '¡Bien hecho! Tarea completada';

  @override
  String get feedbackCompletedRecurring =>
      '¡Bien hecho! Te recordaré la próxima vez';

  @override
  String feedbackSnoozed(String duration) {
    return 'Te lo recuerdo en $duration';
  }

  @override
  String get feedbackDeleted => 'Recordatorio eliminado';

  @override
  String get feedbackReopened => 'Vuelve a estar pendiente';

  @override
  String get feedbackSaved => 'Recordatorio guardado';

  @override
  String get errorGeneric => 'Algo salió mal. Intenta de nuevo.';

  @override
  String get deleteConfirmTitle => '¿Eliminar este recordatorio?';

  @override
  String get deleteConfirmBody =>
      'Se quitará de tu lista. Tu historial se conserva.';

  @override
  String get fieldTitle => '¿Qué necesitas recordar?';

  @override
  String get fieldTitleHint => 'Ej.: Entregar el informe';

  @override
  String get fieldTitleRequired => 'Escribe qué necesitas recordar';

  @override
  String get fieldNotes => 'Notas (opcional)';

  @override
  String get fieldDate => 'Fecha';

  @override
  String get fieldTime => 'Hora';

  @override
  String get fieldLeadTime => 'Avisarme';

  @override
  String get fieldRecurrence => 'Repetir';

  @override
  String get fieldPriority => 'Prioridad';

  @override
  String get fieldCategory => 'Categoría';

  @override
  String get fieldWeekdays => 'Días';

  @override
  String get leadTimeNone => 'A la hora exacta';

  @override
  String leadTimeMinutes(int minutes) {
    return '$minutes min antes';
  }

  @override
  String leadTimeHours(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours horas antes',
      one: '1 hora antes',
    );
    return '$_temp0';
  }

  @override
  String leadTimeDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days días antes',
      one: '1 día antes',
    );
    return '$_temp0';
  }

  @override
  String durationMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String durationHours(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours horas',
      one: '1 hora',
    );
    return '$_temp0';
  }

  @override
  String get recurrenceNone => 'No se repite';

  @override
  String get recurrenceDaily => 'Todos los días';

  @override
  String get recurrenceWeekdays => 'De lunes a viernes';

  @override
  String get recurrenceWeekly => 'Cada semana';

  @override
  String recurrenceWeeklyOn(String days) {
    return 'Cada semana: $days';
  }

  @override
  String get recurrenceMonthly => 'Cada mes';

  @override
  String get recurrenceYearly => 'Cada año';

  @override
  String get priorityLow => 'Baja';

  @override
  String get priorityNormal => 'Normal';

  @override
  String get priorityHigh => 'Alta';

  @override
  String get priorityUrgent => 'Urgente';

  @override
  String get categoryPersonal => 'Personal';

  @override
  String get categoryWork => 'Trabajo';

  @override
  String get categoryStudy => 'Estudio';

  @override
  String get categoryHealth => 'Salud';

  @override
  String get categoryHome => 'Hogar';

  @override
  String get categoryFinance => 'Finanzas';

  @override
  String get categoryOther => 'Otra';

  @override
  String get statusOverdue => 'Vencido';

  @override
  String statusSnoozedUntil(String time) {
    return 'Pospuesto hasta $time';
  }

  @override
  String statusCompletedAt(String date) {
    return 'Completado $date';
  }

  @override
  String get dateToday => 'Hoy';

  @override
  String get dateTomorrow => 'Mañana';

  @override
  String get dateYesterday => 'Ayer';

  @override
  String get calendarEmptyDay => 'No hay recordatorios este día';

  @override
  String get calendarAddForDay => 'Agregar';

  @override
  String get calendarMonth => 'Mes';

  @override
  String get calendarTwoWeeks => '2 semanas';

  @override
  String get calendarWeek => 'Semana';

  @override
  String get reminderNotFound => 'Este recordatorio ya no existe';

  @override
  String get historyProgress => 'Tu progreso';

  @override
  String get historyRecent => 'Actividad reciente';

  @override
  String get historyEmptyTitle => 'Tu historial está vacío';

  @override
  String get historyEmptyBody =>
      'Cuando completes recordatorios verás aquí tu progreso.';

  @override
  String get statCompletedWeek => 'Esta semana';

  @override
  String get statStreak => 'Racha actual';

  @override
  String get statBestStreak => 'Mejor racha';

  @override
  String get statOnTime => 'A tiempo';

  @override
  String get statSnoozed => 'Pospuestos (30 días)';

  @override
  String statDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days días',
      one: '1 día',
    );
    return '$_temp0';
  }

  @override
  String get eventCompleted => 'Completado';

  @override
  String get eventCompletedLate => 'Completado tarde';

  @override
  String get eventSnoozed => 'Pospuesto';

  @override
  String get eventCreated => 'Creado';

  @override
  String get eventUpdated => 'Editado';

  @override
  String get eventDeleted => 'Eliminado';

  @override
  String get eventRestored => 'Restaurado';

  @override
  String get eventReopened => 'Reabierto';

  @override
  String get eventNotified => 'Avisado';

  @override
  String get eventEscalated => 'Insistió';

  @override
  String get settingsSectionReminders => 'Recordatorios';

  @override
  String get settingsDefaultLeadTime => 'Anticipación por defecto';

  @override
  String get settingsSnoozeDuration => 'Al posponer, recordar en';

  @override
  String get settingsSectionAlerts => 'Alertas';

  @override
  String get settingsFullScreen => 'Alerta en pantalla completa';

  @override
  String get settingsFullScreenSubtitle =>
      'Aparece sobre otras apps, como una alarma';

  @override
  String get settingsSound => 'Sonido';

  @override
  String get settingsVibration => 'Vibración';

  @override
  String get settingsEscalation => 'Insistir si no respondo';

  @override
  String get settingsEscalationSubtitle =>
      'Vuelve a avisar a los 10, 30 y 60 minutos';

  @override
  String get settingsSectionQuietHours => 'Horario de silencio';

  @override
  String get settingsQuietHours => 'Activar horario de silencio';

  @override
  String get settingsQuietHoursSubtitle =>
      'Solo lo urgente suena en este horario';

  @override
  String get settingsFrom => 'Desde';

  @override
  String get settingsTo => 'Hasta';

  @override
  String get settingsSectionSummaries => 'Resúmenes';

  @override
  String get settingsMorningSummary => 'Resumen de la mañana';

  @override
  String get settingsMorningSummarySubtitle => 'Lo que tienes para hoy';

  @override
  String get settingsNightSummary => 'Resumen de la noche';

  @override
  String get settingsNightSummarySubtitle => 'Lo que quedó pendiente';

  @override
  String get settingsSectionAssistant => 'Asistente';

  @override
  String get settingsVoiceConfirmation => 'Confirmar en voz alta';

  @override
  String get settingsVoiceConfirmationSubtitle =>
      'Viernes repite lo que entendió antes de guardar';

  @override
  String get settingsSectionPrivacy => 'Privacidad e IA';

  @override
  String get settingsDataCollection => 'Ayudar a entrenar a Viernes';

  @override
  String get settingsDataCollectionSubtitle =>
      'Guarda en tu teléfono las frases que dictas y tus correcciones para mejorar la IA. Nada sale del dispositivo sin tu permiso.';

  @override
  String settingsTrainingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count frases guardadas',
      one: '1 frase guardada',
      zero: 'Sin frases guardadas',
    );
    return '$_temp0';
  }

  @override
  String get settingsTrainingDelete => 'Borrar frases guardadas';

  @override
  String get settingsTrainingDeleteConfirm =>
      '¿Borrar todas las frases guardadas para entrenar a Viernes? Esta acción no se puede deshacer.';

  @override
  String get settingsTrainingDeleted => 'Frases borradas';

  @override
  String get settingsSectionAppearance => 'Apariencia';

  @override
  String get settingsTheme => 'Tema';

  @override
  String get themeSystem => 'Según el sistema';

  @override
  String get themeLight => 'Claro';

  @override
  String get themeDark => 'Oscuro';

  @override
  String get settingsSectionPermissions => 'Permisos';

  @override
  String get permissionNotifications => 'Notificaciones';

  @override
  String get permissionExactAlarms => 'Alarmas a la hora exacta';

  @override
  String get permissionFullScreen => 'Alertas a pantalla completa';

  @override
  String get permissionGranted => 'Permitido';

  @override
  String get permissionMissing => 'Falta permiso';

  @override
  String get permissionsGrant => 'Permitir';

  @override
  String get permissionsBannerTitle => 'Viernes no puede avisarte';

  @override
  String get permissionsBannerBody =>
      'Para que tus recordatorios suenen a tiempo, permite las notificaciones y las alarmas.';

  @override
  String get channelReminders => 'Recordatorios';

  @override
  String get channelUrgent => 'Recordatorios urgentes';

  @override
  String get channelSilent => 'Recordatorios en horario de silencio';

  @override
  String get channelDescription => 'Avisos de tus recordatorios';

  @override
  String get channelSummaries => 'Resúmenes diarios';

  @override
  String get channelSummariesDescription =>
      'Lo que tienes en la mañana y lo que quedó pendiente en la noche';

  @override
  String get summaryMoveToTomorrow => 'Pasar a mañana';

  @override
  String get homeMoveToTomorrow => 'Pasar a mañana';

  @override
  String feedbackMovedToTomorrow(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Pasé $count recordatorios a mañana',
      one: 'Pasé 1 recordatorio a mañana',
      zero: 'No había nada para mover',
    );
    return '$_temp0';
  }

  @override
  String get remindersFilterAll => 'Todas';

  @override
  String get historyLast7Days => 'Últimos 7 días';

  @override
  String get historyMostSnoozed => 'Lo que más pospones';

  @override
  String historySnoozedTimes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count veces',
      one: '1 vez',
    );
    return '$_temp0';
  }

  @override
  String get widgetAdd => 'Agregar widget a la pantalla de inicio';

  @override
  String get widgetAddSubtitle =>
      'Tus próximos recordatorios y un botón para hablar con Viernes';

  @override
  String alertBodyWithLead(String when, String remaining) {
    return '$when · faltan $remaining';
  }

  @override
  String alertStillPending(String when) {
    return 'Sigue pendiente · $when';
  }

  @override
  String alertSpoken(String title) {
    return 'Recordatorio: $title. ¿Ya lo hiciste?';
  }

  @override
  String get alertSnoozeQuestion => '¿Cuándo te lo recuerdo?';

  @override
  String alertSnoozeIn(String duration) {
    return 'En $duration';
  }

  @override
  String get alertSnoozeTomorrow => 'Mañana a esta hora';

  @override
  String get alertReplyByVoice => 'Responder por voz';

  @override
  String get alertListeningHint =>
      'Di «ya lo hice», «todavía no» o «ya no lo necesito»';

  @override
  String get alertDismissed => 'Listo, ya no te lo recordaré.';

  @override
  String get alertDidNotUnderstand =>
      'No te entendí. Toca un botón o vuelve a intentarlo.';

  @override
  String get alertNoMic => 'El micrófono no está disponible.';

  @override
  String get wakeSection => 'Activación por voz';

  @override
  String get wakeEnable => 'Decir «Viernes» para activar';

  @override
  String get wakeSubtitle =>
      'Escucha solo su nombre, sin internet. Usa algo más de batería.';

  @override
  String get wakeDownloadNote =>
      'La primera vez descarga un modelo de voz de unos 38 MB (mejor con Wi‑Fi).';

  @override
  String wakeDownloading(int percent) {
    return 'Descargando el modelo de voz… $percent %';
  }

  @override
  String get wakeListening => 'Atento: di «Viernes» cuando quieras';

  @override
  String get wakeSensitivity => 'Sensibilidad';

  @override
  String get wakeSensitivityLow => 'Menos falsas activaciones';

  @override
  String get wakeSensitivityMedium => 'Equilibrada';

  @override
  String get wakeSensitivityHigh => 'Responde más fácil';

  @override
  String get wakeOverlay => 'Abrir al instante sobre otras apps';

  @override
  String get wakeOverlaySubtitle =>
      'Sin este permiso, si estás usando otra app verás un aviso para tocar.';

  @override
  String get wakeRemoveModel => 'Borrar el modelo de voz descargado';

  @override
  String get wakeErrorMic => 'Necesito permiso para usar el micrófono.';

  @override
  String get wakeChime => 'Sonido al activarse';

  @override
  String get wakeChimeSubtitle => 'Un tono corto confirma que Viernes te oyó';

  @override
  String get wakeEngine => 'Detector';

  @override
  String get wakeEngineOwn => 'Propio';

  @override
  String get wakeEngineVosk => 'Vosk';

  @override
  String get wakeEngineOwnNote =>
      'Detector propio de Viernes: ligero y sin descargas.';

  @override
  String get wakeEngineVoskNote =>
      'Modelo general de voz (38 MB). Úsalo si el propio no te reconoce bien.';

  @override
  String get wakeErrorDownload =>
      'No se pudo descargar el modelo de voz. Revisa tu conexión e inténtalo de nuevo.';

  @override
  String get learningTitle => 'Cómo aprende Viernes';

  @override
  String get learningOpen => 'Cómo aprende Viernes';

  @override
  String get learningOpenSubtitle =>
      'Lo que aprendió de ti y qué tan bien te entiende';

  @override
  String get learningPrivacy =>
      'Viernes aprende de tus recordatorios en este teléfono. Nada se envía a internet.';

  @override
  String get learningEnable => 'Aprendizaje personal';

  @override
  String get learningEnableSubtitle =>
      'Ajusta categorías, horarios y anticipación a tu forma de usarlo';

  @override
  String get learningWhatItLearned => 'Lo que aprendió';

  @override
  String learningTrainedOn(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Aprendió de $count recordatorios',
      one: 'Aprendió de 1 recordatorio',
      zero: 'Aún no hay recordatorios para aprender',
    );
    return '$_temp0';
  }

  @override
  String get learningCategories => 'Categorías';

  @override
  String learningAccuracy(int percent) {
    return 'Acierta en el $percent % de los casos (medido con tus datos)';
  }

  @override
  String get learningNeedsMoreData =>
      'Necesita al menos 10 recordatorios con categoría para medir su acierto';

  @override
  String get learningYourTimes => 'Tus horarios';

  @override
  String get learningMorning => 'En la mañana';

  @override
  String get learningAfternoon => 'En la tarde';

  @override
  String get learningNight => 'En la noche';

  @override
  String get learningNotYet => 'aún aprendiendo';

  @override
  String get learningLeadTimes => 'Tu anticipación habitual';

  @override
  String get learningConversations => 'Conversaciones';

  @override
  String learningFirstTry(int percent) {
    return 'Entendidas a la primera: $percent %';
  }

  @override
  String learningTitleFixes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count títulos corregidos',
      one: '1 título corregido',
      zero: 'Ningún título corregido',
    );
    return '$_temp0';
  }

  @override
  String get learningExport => 'Exportar frases (JSONL)';

  @override
  String get learningExportSubtitle =>
      'Para entrenar la próxima versión de la IA. Tú eliges a dónde enviarlas.';

  @override
  String wakeSamplesTitle(int real, int errors) {
    return '$real activaciones reales · $errors por error';
  }

  @override
  String get wakeSamplesSubtitle =>
      'Audio de 2 s de cada «Viernes» (solo con tu consentimiento) para entrenar un detector que te reconozca mejor.';

  @override
  String get wakeSamplesExport => 'Exportar grabaciones';

  @override
  String get wakeSamplesDelete => 'Borrar grabaciones';

  @override
  String get wakeSamplesSection => 'Detector de «Viernes»';

  @override
  String get neuralSection => 'Red neuronal propia';

  @override
  String get neuralUnavailable => 'Esta versión no trae la red neuronal.';

  @override
  String neuralVersion(String version) {
    return 'Modelo $version';
  }

  @override
  String neuralAccuracy(int percent) {
    return 'Acierta el título en el $percent % de frases con tareas que nunca vio';
  }

  @override
  String get neuralTitles => 'Títulos con la red neuronal (experimental)';

  @override
  String get neuralTitlesSubtitle =>
      'Si está muy segura, la red decide qué tarea guardar. Si no, mandan las reglas.';

  @override
  String neuralCompare(int count, int rules, int neural) {
    return 'Con tus $count frases: reglas $rules % · red neuronal $neural %';
  }

  @override
  String get neuralCompareNeedsData =>
      'Con 10 frases guardadas (activando «Ayudar a entrenar a Viernes») podrás comparar reglas y red con tu forma de hablar.';

  @override
  String get neuralTry => 'Prueba la red';

  @override
  String get neuralTryHint => 'Mañana a las 8 llamar a Juan';

  @override
  String get settingsSectionAbout => 'Acerca de';

  @override
  String get settingsVersion => 'Versión';

  @override
  String get settingsEnvironment => 'Entorno';

  @override
  String get placesTitle => 'Lugares';

  @override
  String get placesAdd => 'Agregar lugar';

  @override
  String get placesAddTitle => 'Guardar este lugar';

  @override
  String get placesAddHint =>
      'Se guarda tu ubicación actual. Hazlo cuando estés en el lugar.';

  @override
  String get placesName => 'Nombre';

  @override
  String get placesRadiusLabel => 'Distancia para avisar';

  @override
  String placesRadius(int meters) {
    return 'A $meters m';
  }

  @override
  String get placesUseHere => 'Guardar aquí';

  @override
  String get placesLocating => 'Buscando tu ubicación…';

  @override
  String get placesNoLocation =>
      'No pude obtener tu ubicación. Revisa que el GPS esté encendido.';

  @override
  String placesSaved(String name) {
    return 'Guardé «$name»';
  }

  @override
  String get placesEmpty => 'Aún no tienes lugares';

  @override
  String get placesEmptySubtitle =>
      'Guarda Casa, Trabajo o el supermercado para que Viernes te avise al llegar.';

  @override
  String get placeHome => 'Casa';

  @override
  String get placeWork => 'Trabajo';

  @override
  String get placeSupermarket => 'Supermercado';

  @override
  String get placeGym => 'Gimnasio';

  @override
  String get locationPermissionTitle => 'Permiso de ubicación';

  @override
  String get locationPermissionFine =>
      'Para guardar lugares, Viernes necesita saber dónde estás.';

  @override
  String get locationPermissionBackground =>
      'Para avisarte con la app cerrada, elige «Permitir todo el tiempo». Viernes solo usa tu ubicación para estos avisos.';

  @override
  String get locationRemindersTitle => 'Por ubicación';

  @override
  String get locationRemindersAdd => 'Nuevo por ubicación';

  @override
  String get locationRemindersEmpty => 'Sin recordatorios por ubicación';

  @override
  String get locationRemindersEmptySubtitle =>
      'Dile a Viernes: «recuérdame comprar leche cuando llegue a casa».';

  @override
  String locationOnArrive(String place) {
    return 'Al llegar a $place';
  }

  @override
  String locationOnLeave(String place) {
    return 'Al salir de $place';
  }

  @override
  String get locationArrive => 'Al llegar';

  @override
  String get locationLeave => 'Al salir';

  @override
  String get settingsPlaces => 'Lugares y recordatorios por ubicación';

  @override
  String get settingsPlacesSubtitle =>
      'Avisos al llegar a casa, al trabajo o al supermercado';

  @override
  String get sharingTitle => 'Compartir';

  @override
  String get sharingSignIn => 'Inicia sesión para compartir';

  @override
  String get sharingSignInSubtitle =>
      'Las listas y los recordatorios compartidos usan tu cuenta de Google.';

  @override
  String get sharingOffline =>
      'Sin conexión. Las listas compartidas necesitan internet.';

  @override
  String get sharingTabLists => 'Listas';

  @override
  String get sharingTabSent => 'Enviados';

  @override
  String get sharingTabContacts => 'Contactos';

  @override
  String get settingsSharing => 'Compartir';

  @override
  String get settingsSharingSubtitle =>
      'Listas compartidas, recordatorios enviados y contactos';

  @override
  String get listsNew => 'Nueva lista';

  @override
  String get listsName => 'Nombre de la lista';

  @override
  String get listsNameHint => 'Mercado';

  @override
  String get listsEmpty => 'Aún no tienes listas';

  @override
  String get listsEmptySubtitle =>
      'Crea una (mercado, pendientes de la casa…) y compártela. O dile a Viernes: «agrega leche a la lista del mercado».';

  @override
  String listsMembers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count personas',
      one: 'Solo tú',
    );
    return '$_temp0';
  }

  @override
  String get listsShare => 'Compartir lista';

  @override
  String get listsShareByEmail => 'Con otro correo…';

  @override
  String get listsAddItem => 'Agregar…';

  @override
  String get listsNoItems => 'Lista vacía';

  @override
  String get listsNoItemsSubtitle =>
      'Escribe arriba o dile a Viernes qué agregar.';

  @override
  String listsAddedBy(String name) {
    return 'Lo agregó $name';
  }

  @override
  String get listsClearDone => 'Quitar los marcados';

  @override
  String get listsDelete => 'Eliminar lista';

  @override
  String get listsLeave => 'Salir de la lista';

  @override
  String get sentEmpty => 'No has enviado recordatorios';

  @override
  String get sentEmptySubtitle =>
      'Dile a Viernes: «recuérdale a Sofi recoger el paquete mañana a las 5».';

  @override
  String get sentPending => 'enviado';

  @override
  String get sentAccepted => 'en su agenda';

  @override
  String get sentDone => '¡lo hizo!';

  @override
  String get sentCancelled => 'cancelado';

  @override
  String get contactsAdd => 'Agregar contacto';

  @override
  String get contactsEmpty => 'Sin contactos';

  @override
  String get contactsEmptySubtitle =>
      'Agrega a quienes usan Viernes para enviarles recordatorios por voz.';

  @override
  String get contactsHint =>
      'Usa el correo con el que esa persona inicia sesión en Viernes.';

  @override
  String get contactsName => 'Nombre (como lo dirás)';

  @override
  String get contactsEmail => 'Correo de Google';

  @override
  String get welcomeTitle => 'Hola, soy Viernes';

  @override
  String get welcomeSubtitle =>
      'Te recuerdo lo importante y te hago seguimiento hasta que lo hagas.';

  @override
  String get welcomeBenefitBackup =>
      'Tus recordatorios e historial, respaldados en tu cuenta';

  @override
  String get welcomeBenefitRestore =>
      'Si cambias de teléfono, lo recuperas todo al iniciar sesión';

  @override
  String get welcomeBenefitPrivate => 'Solo tú puedes ver tus datos';

  @override
  String get welcomeGoogle => 'Continuar con Google';

  @override
  String get welcomeSkip => 'Usar sin cuenta';

  @override
  String get welcomeSkipNote =>
      'Puedes iniciar sesión cuando quieras desde Ajustes.';

  @override
  String get accountSection => 'Cuenta';

  @override
  String get accountSignedOutTitle => 'Inicia sesión con Google';

  @override
  String get accountSignedOutSubtitle =>
      'Respalda tus recordatorios e historial y recupéralos en cualquier teléfono';

  @override
  String get accountUnavailable => 'Cuentas no disponibles en esta versión';

  @override
  String get accountUnavailableSubtitle =>
      'Falta configurar Google en la app (ver docs/CUENTAS.md)';

  @override
  String accountGreeting(String name) {
    return 'Hola, $name';
  }

  @override
  String get accountSyncNow => 'Sincronizar ahora';

  @override
  String get accountSyncing => 'Sincronizando…';

  @override
  String accountSyncedAt(String time) {
    return 'Sincronizado $time';
  }

  @override
  String get accountNeverSynced => 'Aún no se ha sincronizado';

  @override
  String get accountOffline =>
      'Sin conexión: se sincronizará al volver internet';

  @override
  String get accountSyncError =>
      'No se pudo sincronizar. Se reintentará en un momento.';

  @override
  String accountPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cambios por subir',
      one: '1 cambio por subir',
    );
    return '$_temp0';
  }

  @override
  String get accountSignOut => 'Cerrar sesión';

  @override
  String get accountSignOutConfirm =>
      'Tus recordatorios quedan guardados en tu cuenta. Se quitarán de este teléfono y sus avisos dejarán de sonar hasta que vuelvas a iniciar sesión.';

  @override
  String accountSignOutBlocked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Hay $count cambios sin subir porque no hay internet.',
      one: 'Hay 1 cambio sin subir porque no hay internet.',
    );
    return '$_temp0 Si cierras sesión ahora se perderán.';
  }

  @override
  String get accountSignOutAnyway => 'Cerrar de todos modos';

  @override
  String get accountSignedOut => 'Sesión cerrada';

  @override
  String get accountDelete => 'Eliminar mi cuenta';

  @override
  String get accountDeleteSubtitle =>
      'Borra tu cuenta y todos tus datos de la nube';

  @override
  String get accountDeleteConfirm =>
      'Se borrarán para siempre tu cuenta, tus recordatorios y tu historial, en la nube y en este teléfono. Google te pedirá confirmar que eres tú.';

  @override
  String get accountDeleted => 'Tu cuenta y tus datos se eliminaron';

  @override
  String accountWelcomeBack(String name) {
    return '¡Bienvenido, $name! Tus datos están al día.';
  }

  @override
  String get accountMerged =>
      'Tus recordatorios de este teléfono se guardaron en tu cuenta.';

  @override
  String get accountSignInLater =>
      'Sesión iniciada. Tus datos se sincronizarán cuando haya internet.';

  @override
  String get authErrorCancelled => 'Inicio de sesión cancelado';

  @override
  String get authErrorNetwork => 'Sin conexión a internet. Inténtalo de nuevo.';

  @override
  String get authErrorNotConfigured =>
      'El inicio de sesión con Google aún no está configurado en esta versión.';

  @override
  String get authErrorRejected =>
      'Google no permitió el acceso con esta cuenta.';

  @override
  String get authErrorUnknown => 'No se pudo completar. Inténtalo de nuevo.';

  @override
  String get attachTitle => 'Fotos y notas de voz';

  @override
  String get attachPhoto => 'Foto';

  @override
  String get attachVoiceNote => 'Nota de voz';

  @override
  String get attachCamera => 'Tomar foto';

  @override
  String get attachGallery => 'Elegir de la galería';

  @override
  String get attachPhotoError => 'No se pudo agregar la foto';

  @override
  String get attachDeleteConfirm => '¿Quitar este adjunto?';

  @override
  String get attachMicDenied => 'Necesito permiso para usar el micrófono';

  @override
  String get attachRecordError => 'No se pudo grabar';

  @override
  String get attachRecording => 'Nota de voz';

  @override
  String get attachRecordingHint =>
      'Habla ahora. Hasta 2 minutos; toca Listo al terminar.';

  @override
  String get attachStop => 'Listo';

  @override
  String get calendarFromPhone => 'De tu calendario';

  @override
  String get calendarAllDay => 'Todo el día';

  @override
  String get summaryListen => 'Escuchar';

  @override
  String get alertSnoozeUsual => 'Lo que sueles elegir';

  @override
  String get alertSnoozeOther => 'Otro tiempo';

  @override
  String alertSnoozeFor(String duration) {
    return 'Posponer $duration';
  }

  @override
  String get routineTitle => 'Viernes notó una costumbre';

  @override
  String routineBody(String title, String repeat, String time) {
    return 'Sueles crear «$title» $repeat, a las $time. ¿Lo dejo como repetitivo?';
  }

  @override
  String get routineYes => 'Sí, repetir';

  @override
  String get routineNo => 'No, gracias';

  @override
  String get routineDone => 'Listo: ahora se repite solo';

  @override
  String get birthdaysTitle => 'Cumpleaños de tus contactos';

  @override
  String get birthdaysIntro =>
      'Viernes lee los cumpleaños guardados en los contactos del teléfono y crea un recordatorio que se repite cada año.';

  @override
  String get birthdaysPermissionTitle => 'Permite leer tus contactos';

  @override
  String get birthdaysPermissionBody =>
      'Solo se leen el nombre y la fecha de cumpleaños. Nada sale del teléfono.';

  @override
  String get birthdaysAllow => 'Permitir';

  @override
  String get birthdaysTime => 'Hora del aviso';

  @override
  String get birthdaysBefore => 'Aviso previo';

  @override
  String birthdaysDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days días antes',
      one: '1 día antes',
      zero: 'Sin aviso previo',
    );
    return '$_temp0';
  }

  @override
  String get birthdaysAuto => 'Agregar solos los nuevos';

  @override
  String get birthdaysAutoSubtitle =>
      'Al abrir la app, si guardas un cumpleaños nuevo en tus contactos';

  @override
  String get birthdaysEmpty => 'Tus contactos no tienen cumpleaños guardados';

  @override
  String get birthdaysEmptyBody =>
      'Agrega la fecha en la app Contactos (campo «Cumpleaños») y vuelve aquí.';

  @override
  String birthdaysAdd(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Agregar $count cumpleaños',
      one: 'Agregar 1 cumpleaños',
      zero: 'Nada nuevo por agregar',
    );
    return '$_temp0';
  }

  @override
  String birthdaysAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Se agregaron $count cumpleaños',
      one: 'Se agregó 1 cumpleaños',
      zero: 'No se agregó ninguno',
    );
    return '$_temp0';
  }

  @override
  String get birthdaysAlready => 'ya en tu agenda';

  @override
  String birthdaysTurns(int age) {
    return 'cumple $age';
  }

  @override
  String get settingsCalendar => 'Incluir mi calendario';

  @override
  String get settingsCalendarSubtitle =>
      'Viernes lee tus eventos de Google Calendar para responder «¿tengo algo el viernes?» y para el resumen del día';

  @override
  String get settingsCalendarDenied =>
      'Sin permiso de calendario no puedo leer tus eventos';

  @override
  String get settingsBirthdaysSubtitle =>
      'Agrégalos a tu agenda con aviso previo';

  @override
  String get settingsDriving => 'Modo conducción';

  @override
  String get settingsDrivingHelp =>
      'Respuestas más cortas y botones grandes para usar Viernes sin mirar mucho la pantalla.';

  @override
  String drivingMode(String mode) {
    String _temp0 = intl.Intl.selectLogic(
      mode,
      {
        'off': 'Desactivado',
        'on': 'Siempre activado',
        'other':
            'Automático: al conectar el carro por Bluetooth o con Android Auto',
      },
    );
    return '$_temp0';
  }

  @override
  String get settingsHeadset => 'Botón de los audífonos';

  @override
  String get settingsHeadsetSubtitle =>
      'Mantén presionado el botón del audífono o del asistente y elige Viernes. Toca para abrir los ajustes del asistente del teléfono.';

  @override
  String get settingsSpeakBriefing => 'Leer el resumen de la mañana';

  @override
  String get settingsSpeakBriefingSubtitle =>
      'Al tocar el resumen de la mañana, Viernes te lo dice en voz alta';

  @override
  String get wakeLowBattery => 'Pausar con batería baja';

  @override
  String get wakeLowBatterySubtitle =>
      'Con 15 % o menos y sin cargar, deja de escuchar hasta que cargues';

  @override
  String learningSnooze(String duration) {
    return 'Sueles posponer $duration';
  }

  @override
  String get learningSnoozeSubtitle =>
      'Es el tiempo del botón «Posponer» y de «recuérdamelo después»';

  @override
  String get learningForget => 'Olvidar';

  @override
  String get batterySection => 'Consumo de la escucha';

  @override
  String get batteryNoData => 'Aún no hay datos';

  @override
  String get batteryNoDataSubtitle =>
      'Activa «Viernes» por voz y vuelve en un rato para ver cuánto gasta.';

  @override
  String get batteryMeasuring => 'Midiendo la batería…';

  @override
  String batteryPerHour(String percent) {
    return '≈ $percent % de batería por hora mientras escucha (todo el teléfono)';
  }

  @override
  String batteryListening(String hours, int saved) {
    return '$hours h escuchando · $saved % del tiempo en silencio (ahorro)';
  }

  @override
  String batteryCpu(String cpu, String ms) {
    return 'Procesador: $cpu % · $ms ms por análisis';
  }

  @override
  String get batteryReset => 'Reiniciar cifras';

  @override
  String get listsAssign => 'Asignar';

  @override
  String listsAssignTitle(String item) {
    return '¿A quién le toca «$item»?';
  }

  @override
  String get listsMe => 'Yo';

  @override
  String get listsNobody => 'A nadie';

  @override
  String get listsForYou => 'Te toca a ti';

  @override
  String listsFor(String name) {
    return 'Le toca a $name';
  }

  @override
  String get homeYourDay => 'Tu día';

  @override
  String get homeNew => 'Nuevo';

  @override
  String get homeFree => 'Libre.';

  @override
  String get homeNow => 'Ahora';

  @override
  String get homeDay => 'día';

  @override
  String get homeDays => 'días';

  @override
  String get homeUntilNext => 'Falta para lo próximo';

  @override
  String get voiceThinking => 'Pensando…';

  @override
  String get voiceConfirming => '¿Lo guardo?';

  @override
  String get voiceProblem => 'No salió';

  @override
  String get voiceSayIt => 'Dime qué necesitas…';

  @override
  String get voiceTokenWhat => 'qué';

  @override
  String get voiceTokenWhen => 'cuándo';

  @override
  String get voiceTokenNotice => 'aviso';

  @override
  String get voiceTokenRepeat => 'repite';

  @override
  String get alertSwipeDone => 'Desliza si ya lo hiciste';

  @override
  String get alertTomorrowShort => 'mañana';

  @override
  String get remindersHeader => 'Recordatorios';
}
