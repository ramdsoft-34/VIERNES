import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('es')];

  /// No description provided for @appName.
  ///
  /// In es, this message translates to:
  /// **'Viernes'**
  String get appName;

  /// No description provided for @navHome.
  ///
  /// In es, this message translates to:
  /// **'Inicio'**
  String get navHome;

  /// No description provided for @navReminders.
  ///
  /// In es, this message translates to:
  /// **'Recordatorios'**
  String get navReminders;

  /// No description provided for @navCalendar.
  ///
  /// In es, this message translates to:
  /// **'Calendario'**
  String get navCalendar;

  /// No description provided for @navHistory.
  ///
  /// In es, this message translates to:
  /// **'Historial'**
  String get navHistory;

  /// No description provided for @navSettings.
  ///
  /// In es, this message translates to:
  /// **'Ajustes'**
  String get navSettings;

  /// No description provided for @greetingMorning.
  ///
  /// In es, this message translates to:
  /// **'Buenos días'**
  String get greetingMorning;

  /// No description provided for @greetingAfternoon.
  ///
  /// In es, this message translates to:
  /// **'Buenas tardes'**
  String get greetingAfternoon;

  /// No description provided for @greetingEvening.
  ///
  /// In es, this message translates to:
  /// **'Buenas noches'**
  String get greetingEvening;

  /// No description provided for @homeTodaySummary.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =0{No tienes pendientes para hoy} =1{Hoy tienes 1 pendiente} other{Hoy tienes {count} pendientes}}'**
  String homeTodaySummary(int count);

  /// No description provided for @homeOverdueSummary.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 vencido sin confirmar} other{{count} vencidos sin confirmar}}'**
  String homeOverdueSummary(int count);

  /// No description provided for @homeSectionOverdue.
  ///
  /// In es, this message translates to:
  /// **'Vencidos sin confirmar'**
  String get homeSectionOverdue;

  /// No description provided for @homeSectionUpcoming.
  ///
  /// In es, this message translates to:
  /// **'Próximos'**
  String get homeSectionUpcoming;

  /// No description provided for @homeEmptyTitle.
  ///
  /// In es, this message translates to:
  /// **'Todo en orden'**
  String get homeEmptyTitle;

  /// No description provided for @homeEmptyBody.
  ///
  /// In es, this message translates to:
  /// **'Toca el micrófono o el botón + para crear tu primer recordatorio.'**
  String get homeEmptyBody;

  /// No description provided for @homeSeeAll.
  ///
  /// In es, this message translates to:
  /// **'Ver todos'**
  String get homeSeeAll;

  /// No description provided for @voiceButtonLabel.
  ///
  /// In es, this message translates to:
  /// **'Hablar con Viernes'**
  String get voiceButtonLabel;

  /// No description provided for @voiceButtonHint.
  ///
  /// In es, this message translates to:
  /// **'Toca y dime qué necesitas recordar'**
  String get voiceButtonHint;

  /// No description provided for @voiceStarting.
  ///
  /// In es, this message translates to:
  /// **'Un momento…'**
  String get voiceStarting;

  /// No description provided for @voiceListening.
  ///
  /// In es, this message translates to:
  /// **'Escuchando'**
  String get voiceListening;

  /// No description provided for @voiceWhenMissing.
  ///
  /// In es, this message translates to:
  /// **'Falta la fecha o la hora'**
  String get voiceWhenMissing;

  /// No description provided for @voiceSpeak.
  ///
  /// In es, this message translates to:
  /// **'Hablar'**
  String get voiceSpeak;

  /// No description provided for @voiceDone.
  ///
  /// In es, this message translates to:
  /// **'Listo'**
  String get voiceDone;

  /// No description provided for @voiceClose.
  ///
  /// In es, this message translates to:
  /// **'Cerrar'**
  String get voiceClose;

  /// No description provided for @voiceTryAgain.
  ///
  /// In es, this message translates to:
  /// **'Intentar de nuevo'**
  String get voiceTryAgain;

  /// No description provided for @newReminder.
  ///
  /// In es, this message translates to:
  /// **'Nuevo recordatorio'**
  String get newReminder;

  /// No description provided for @editReminder.
  ///
  /// In es, this message translates to:
  /// **'Editar recordatorio'**
  String get editReminder;

  /// No description provided for @remindersTabPending.
  ///
  /// In es, this message translates to:
  /// **'Pendientes'**
  String get remindersTabPending;

  /// No description provided for @remindersTabSnoozed.
  ///
  /// In es, this message translates to:
  /// **'Pospuestos'**
  String get remindersTabSnoozed;

  /// No description provided for @remindersTabCompleted.
  ///
  /// In es, this message translates to:
  /// **'Completados'**
  String get remindersTabCompleted;

  /// No description provided for @remindersEmptyPendingTitle.
  ///
  /// In es, this message translates to:
  /// **'Sin pendientes'**
  String get remindersEmptyPendingTitle;

  /// No description provided for @remindersEmptyPendingBody.
  ///
  /// In es, this message translates to:
  /// **'Cuando crees un recordatorio aparecerá aquí.'**
  String get remindersEmptyPendingBody;

  /// No description provided for @remindersEmptySnoozedTitle.
  ///
  /// In es, this message translates to:
  /// **'Nada pospuesto'**
  String get remindersEmptySnoozedTitle;

  /// No description provided for @remindersEmptySnoozedBody.
  ///
  /// In es, this message translates to:
  /// **'Lo que dejes para después se mostrará aquí.'**
  String get remindersEmptySnoozedBody;

  /// No description provided for @remindersEmptyCompletedTitle.
  ///
  /// In es, this message translates to:
  /// **'Aún no hay completados'**
  String get remindersEmptyCompletedTitle;

  /// No description provided for @remindersEmptyCompletedBody.
  ///
  /// In es, this message translates to:
  /// **'Confirma tus tareas con «Ya lo hice» y aparecerán aquí.'**
  String get remindersEmptyCompletedBody;

  /// No description provided for @actionComplete.
  ///
  /// In es, this message translates to:
  /// **'Ya lo hice'**
  String get actionComplete;

  /// No description provided for @actionSnooze.
  ///
  /// In es, this message translates to:
  /// **'Recordar después'**
  String get actionSnooze;

  /// No description provided for @actionEdit.
  ///
  /// In es, this message translates to:
  /// **'Editar'**
  String get actionEdit;

  /// No description provided for @actionDelete.
  ///
  /// In es, this message translates to:
  /// **'Eliminar'**
  String get actionDelete;

  /// No description provided for @actionReopen.
  ///
  /// In es, this message translates to:
  /// **'Marcar como pendiente'**
  String get actionReopen;

  /// No description provided for @actionUndo.
  ///
  /// In es, this message translates to:
  /// **'Deshacer'**
  String get actionUndo;

  /// No description provided for @actionSave.
  ///
  /// In es, this message translates to:
  /// **'Guardar'**
  String get actionSave;

  /// No description provided for @actionCancel.
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get actionCancel;

  /// No description provided for @actionMore.
  ///
  /// In es, this message translates to:
  /// **'Más opciones'**
  String get actionMore;

  /// No description provided for @feedbackCompleted.
  ///
  /// In es, this message translates to:
  /// **'¡Bien hecho! Tarea completada'**
  String get feedbackCompleted;

  /// No description provided for @feedbackCompletedRecurring.
  ///
  /// In es, this message translates to:
  /// **'¡Bien hecho! Te recordaré la próxima vez'**
  String get feedbackCompletedRecurring;

  /// No description provided for @feedbackSnoozed.
  ///
  /// In es, this message translates to:
  /// **'Te lo recuerdo en {duration}'**
  String feedbackSnoozed(String duration);

  /// No description provided for @feedbackDeleted.
  ///
  /// In es, this message translates to:
  /// **'Recordatorio eliminado'**
  String get feedbackDeleted;

  /// No description provided for @feedbackReopened.
  ///
  /// In es, this message translates to:
  /// **'Vuelve a estar pendiente'**
  String get feedbackReopened;

  /// No description provided for @feedbackSaved.
  ///
  /// In es, this message translates to:
  /// **'Recordatorio guardado'**
  String get feedbackSaved;

  /// No description provided for @errorGeneric.
  ///
  /// In es, this message translates to:
  /// **'Algo salió mal. Intenta de nuevo.'**
  String get errorGeneric;

  /// No description provided for @deleteConfirmTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Eliminar este recordatorio?'**
  String get deleteConfirmTitle;

  /// No description provided for @deleteConfirmBody.
  ///
  /// In es, this message translates to:
  /// **'Se quitará de tu lista. Tu historial se conserva.'**
  String get deleteConfirmBody;

  /// No description provided for @fieldTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Qué necesitas recordar?'**
  String get fieldTitle;

  /// No description provided for @fieldTitleHint.
  ///
  /// In es, this message translates to:
  /// **'Ej.: Entregar el informe'**
  String get fieldTitleHint;

  /// No description provided for @fieldTitleRequired.
  ///
  /// In es, this message translates to:
  /// **'Escribe qué necesitas recordar'**
  String get fieldTitleRequired;

  /// No description provided for @fieldNotes.
  ///
  /// In es, this message translates to:
  /// **'Notas (opcional)'**
  String get fieldNotes;

  /// No description provided for @fieldDate.
  ///
  /// In es, this message translates to:
  /// **'Fecha'**
  String get fieldDate;

  /// No description provided for @fieldTime.
  ///
  /// In es, this message translates to:
  /// **'Hora'**
  String get fieldTime;

  /// No description provided for @fieldLeadTime.
  ///
  /// In es, this message translates to:
  /// **'Avisarme'**
  String get fieldLeadTime;

  /// No description provided for @fieldRecurrence.
  ///
  /// In es, this message translates to:
  /// **'Repetir'**
  String get fieldRecurrence;

  /// No description provided for @fieldPriority.
  ///
  /// In es, this message translates to:
  /// **'Prioridad'**
  String get fieldPriority;

  /// No description provided for @fieldCategory.
  ///
  /// In es, this message translates to:
  /// **'Categoría'**
  String get fieldCategory;

  /// No description provided for @fieldWeekdays.
  ///
  /// In es, this message translates to:
  /// **'Días'**
  String get fieldWeekdays;

  /// No description provided for @leadTimeNone.
  ///
  /// In es, this message translates to:
  /// **'A la hora exacta'**
  String get leadTimeNone;

  /// No description provided for @leadTimeMinutes.
  ///
  /// In es, this message translates to:
  /// **'{minutes} min antes'**
  String leadTimeMinutes(int minutes);

  /// No description provided for @leadTimeHours.
  ///
  /// In es, this message translates to:
  /// **'{hours, plural, =1{1 hora antes} other{{hours} horas antes}}'**
  String leadTimeHours(int hours);

  /// No description provided for @leadTimeDays.
  ///
  /// In es, this message translates to:
  /// **'{days, plural, =1{1 día antes} other{{days} días antes}}'**
  String leadTimeDays(int days);

  /// No description provided for @durationMinutes.
  ///
  /// In es, this message translates to:
  /// **'{minutes} min'**
  String durationMinutes(int minutes);

  /// No description provided for @durationHours.
  ///
  /// In es, this message translates to:
  /// **'{hours, plural, =1{1 hora} other{{hours} horas}}'**
  String durationHours(int hours);

  /// No description provided for @recurrenceNone.
  ///
  /// In es, this message translates to:
  /// **'No se repite'**
  String get recurrenceNone;

  /// No description provided for @recurrenceDaily.
  ///
  /// In es, this message translates to:
  /// **'Todos los días'**
  String get recurrenceDaily;

  /// No description provided for @recurrenceWeekdays.
  ///
  /// In es, this message translates to:
  /// **'De lunes a viernes'**
  String get recurrenceWeekdays;

  /// No description provided for @recurrenceWeekly.
  ///
  /// In es, this message translates to:
  /// **'Cada semana'**
  String get recurrenceWeekly;

  /// No description provided for @recurrenceWeeklyOn.
  ///
  /// In es, this message translates to:
  /// **'Cada semana: {days}'**
  String recurrenceWeeklyOn(String days);

  /// No description provided for @recurrenceMonthly.
  ///
  /// In es, this message translates to:
  /// **'Cada mes'**
  String get recurrenceMonthly;

  /// No description provided for @recurrenceYearly.
  ///
  /// In es, this message translates to:
  /// **'Cada año'**
  String get recurrenceYearly;

  /// No description provided for @priorityLow.
  ///
  /// In es, this message translates to:
  /// **'Baja'**
  String get priorityLow;

  /// No description provided for @priorityNormal.
  ///
  /// In es, this message translates to:
  /// **'Normal'**
  String get priorityNormal;

  /// No description provided for @priorityHigh.
  ///
  /// In es, this message translates to:
  /// **'Alta'**
  String get priorityHigh;

  /// No description provided for @priorityUrgent.
  ///
  /// In es, this message translates to:
  /// **'Urgente'**
  String get priorityUrgent;

  /// No description provided for @categoryPersonal.
  ///
  /// In es, this message translates to:
  /// **'Personal'**
  String get categoryPersonal;

  /// No description provided for @categoryWork.
  ///
  /// In es, this message translates to:
  /// **'Trabajo'**
  String get categoryWork;

  /// No description provided for @categoryStudy.
  ///
  /// In es, this message translates to:
  /// **'Estudio'**
  String get categoryStudy;

  /// No description provided for @categoryHealth.
  ///
  /// In es, this message translates to:
  /// **'Salud'**
  String get categoryHealth;

  /// No description provided for @categoryHome.
  ///
  /// In es, this message translates to:
  /// **'Hogar'**
  String get categoryHome;

  /// No description provided for @categoryFinance.
  ///
  /// In es, this message translates to:
  /// **'Finanzas'**
  String get categoryFinance;

  /// No description provided for @categoryOther.
  ///
  /// In es, this message translates to:
  /// **'Otra'**
  String get categoryOther;

  /// No description provided for @statusOverdue.
  ///
  /// In es, this message translates to:
  /// **'Vencido'**
  String get statusOverdue;

  /// No description provided for @statusSnoozedUntil.
  ///
  /// In es, this message translates to:
  /// **'Pospuesto hasta {time}'**
  String statusSnoozedUntil(String time);

  /// No description provided for @statusCompletedAt.
  ///
  /// In es, this message translates to:
  /// **'Completado {date}'**
  String statusCompletedAt(String date);

  /// No description provided for @dateToday.
  ///
  /// In es, this message translates to:
  /// **'Hoy'**
  String get dateToday;

  /// No description provided for @dateTomorrow.
  ///
  /// In es, this message translates to:
  /// **'Mañana'**
  String get dateTomorrow;

  /// No description provided for @dateYesterday.
  ///
  /// In es, this message translates to:
  /// **'Ayer'**
  String get dateYesterday;

  /// No description provided for @calendarEmptyDay.
  ///
  /// In es, this message translates to:
  /// **'No hay recordatorios este día'**
  String get calendarEmptyDay;

  /// No description provided for @calendarAddForDay.
  ///
  /// In es, this message translates to:
  /// **'Agregar'**
  String get calendarAddForDay;

  /// No description provided for @calendarMonth.
  ///
  /// In es, this message translates to:
  /// **'Mes'**
  String get calendarMonth;

  /// No description provided for @calendarTwoWeeks.
  ///
  /// In es, this message translates to:
  /// **'2 semanas'**
  String get calendarTwoWeeks;

  /// No description provided for @calendarWeek.
  ///
  /// In es, this message translates to:
  /// **'Semana'**
  String get calendarWeek;

  /// No description provided for @reminderNotFound.
  ///
  /// In es, this message translates to:
  /// **'Este recordatorio ya no existe'**
  String get reminderNotFound;

  /// No description provided for @historyProgress.
  ///
  /// In es, this message translates to:
  /// **'Tu progreso'**
  String get historyProgress;

  /// No description provided for @historyRecent.
  ///
  /// In es, this message translates to:
  /// **'Actividad reciente'**
  String get historyRecent;

  /// No description provided for @historyEmptyTitle.
  ///
  /// In es, this message translates to:
  /// **'Tu historial está vacío'**
  String get historyEmptyTitle;

  /// No description provided for @historyEmptyBody.
  ///
  /// In es, this message translates to:
  /// **'Cuando completes recordatorios verás aquí tu progreso.'**
  String get historyEmptyBody;

  /// No description provided for @statCompletedWeek.
  ///
  /// In es, this message translates to:
  /// **'Esta semana'**
  String get statCompletedWeek;

  /// No description provided for @statStreak.
  ///
  /// In es, this message translates to:
  /// **'Racha actual'**
  String get statStreak;

  /// No description provided for @statBestStreak.
  ///
  /// In es, this message translates to:
  /// **'Mejor racha'**
  String get statBestStreak;

  /// No description provided for @statOnTime.
  ///
  /// In es, this message translates to:
  /// **'A tiempo'**
  String get statOnTime;

  /// No description provided for @statSnoozed.
  ///
  /// In es, this message translates to:
  /// **'Pospuestos (30 días)'**
  String get statSnoozed;

  /// No description provided for @statDays.
  ///
  /// In es, this message translates to:
  /// **'{days, plural, =1{1 día} other{{days} días}}'**
  String statDays(int days);

  /// No description provided for @eventCompleted.
  ///
  /// In es, this message translates to:
  /// **'Completado'**
  String get eventCompleted;

  /// No description provided for @eventCompletedLate.
  ///
  /// In es, this message translates to:
  /// **'Completado tarde'**
  String get eventCompletedLate;

  /// No description provided for @eventSnoozed.
  ///
  /// In es, this message translates to:
  /// **'Pospuesto'**
  String get eventSnoozed;

  /// No description provided for @eventCreated.
  ///
  /// In es, this message translates to:
  /// **'Creado'**
  String get eventCreated;

  /// No description provided for @eventUpdated.
  ///
  /// In es, this message translates to:
  /// **'Editado'**
  String get eventUpdated;

  /// No description provided for @eventDeleted.
  ///
  /// In es, this message translates to:
  /// **'Eliminado'**
  String get eventDeleted;

  /// No description provided for @eventRestored.
  ///
  /// In es, this message translates to:
  /// **'Restaurado'**
  String get eventRestored;

  /// No description provided for @eventReopened.
  ///
  /// In es, this message translates to:
  /// **'Reabierto'**
  String get eventReopened;

  /// No description provided for @eventNotified.
  ///
  /// In es, this message translates to:
  /// **'Avisado'**
  String get eventNotified;

  /// No description provided for @eventEscalated.
  ///
  /// In es, this message translates to:
  /// **'Insistió'**
  String get eventEscalated;

  /// No description provided for @settingsSectionReminders.
  ///
  /// In es, this message translates to:
  /// **'Recordatorios'**
  String get settingsSectionReminders;

  /// No description provided for @settingsDefaultLeadTime.
  ///
  /// In es, this message translates to:
  /// **'Anticipación por defecto'**
  String get settingsDefaultLeadTime;

  /// No description provided for @settingsSnoozeDuration.
  ///
  /// In es, this message translates to:
  /// **'Al posponer, recordar en'**
  String get settingsSnoozeDuration;

  /// No description provided for @settingsSectionAlerts.
  ///
  /// In es, this message translates to:
  /// **'Alertas'**
  String get settingsSectionAlerts;

  /// No description provided for @settingsFullScreen.
  ///
  /// In es, this message translates to:
  /// **'Alerta en pantalla completa'**
  String get settingsFullScreen;

  /// No description provided for @settingsFullScreenSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Aparece sobre otras apps, como una alarma'**
  String get settingsFullScreenSubtitle;

  /// No description provided for @settingsSound.
  ///
  /// In es, this message translates to:
  /// **'Sonido'**
  String get settingsSound;

  /// No description provided for @settingsVibration.
  ///
  /// In es, this message translates to:
  /// **'Vibración'**
  String get settingsVibration;

  /// No description provided for @settingsEscalation.
  ///
  /// In es, this message translates to:
  /// **'Insistir si no respondo'**
  String get settingsEscalation;

  /// No description provided for @settingsEscalationSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Vuelve a avisar a los 10, 30 y 60 minutos'**
  String get settingsEscalationSubtitle;

  /// No description provided for @settingsSectionQuietHours.
  ///
  /// In es, this message translates to:
  /// **'Horario de silencio'**
  String get settingsSectionQuietHours;

  /// No description provided for @settingsQuietHours.
  ///
  /// In es, this message translates to:
  /// **'Activar horario de silencio'**
  String get settingsQuietHours;

  /// No description provided for @settingsQuietHoursSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Solo lo urgente suena en este horario'**
  String get settingsQuietHoursSubtitle;

  /// No description provided for @settingsFrom.
  ///
  /// In es, this message translates to:
  /// **'Desde'**
  String get settingsFrom;

  /// No description provided for @settingsTo.
  ///
  /// In es, this message translates to:
  /// **'Hasta'**
  String get settingsTo;

  /// No description provided for @settingsSectionSummaries.
  ///
  /// In es, this message translates to:
  /// **'Resúmenes'**
  String get settingsSectionSummaries;

  /// No description provided for @settingsMorningSummary.
  ///
  /// In es, this message translates to:
  /// **'Resumen de la mañana'**
  String get settingsMorningSummary;

  /// No description provided for @settingsMorningSummarySubtitle.
  ///
  /// In es, this message translates to:
  /// **'Lo que tienes para hoy'**
  String get settingsMorningSummarySubtitle;

  /// No description provided for @settingsNightSummary.
  ///
  /// In es, this message translates to:
  /// **'Resumen de la noche'**
  String get settingsNightSummary;

  /// No description provided for @settingsNightSummarySubtitle.
  ///
  /// In es, this message translates to:
  /// **'Lo que quedó pendiente'**
  String get settingsNightSummarySubtitle;

  /// No description provided for @settingsSectionAssistant.
  ///
  /// In es, this message translates to:
  /// **'Asistente'**
  String get settingsSectionAssistant;

  /// No description provided for @settingsVoiceConfirmation.
  ///
  /// In es, this message translates to:
  /// **'Confirmar en voz alta'**
  String get settingsVoiceConfirmation;

  /// No description provided for @settingsVoiceConfirmationSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Viernes repite lo que entendió antes de guardar'**
  String get settingsVoiceConfirmationSubtitle;

  /// No description provided for @settingsSectionPrivacy.
  ///
  /// In es, this message translates to:
  /// **'Privacidad e IA'**
  String get settingsSectionPrivacy;

  /// No description provided for @settingsDataCollection.
  ///
  /// In es, this message translates to:
  /// **'Ayudar a entrenar a Viernes'**
  String get settingsDataCollection;

  /// No description provided for @settingsDataCollectionSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Guarda en tu teléfono las frases que dictas y tus correcciones para mejorar la IA. Nada sale del dispositivo sin tu permiso.'**
  String get settingsDataCollectionSubtitle;

  /// No description provided for @settingsTrainingCount.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =0{Sin frases guardadas} =1{1 frase guardada} other{{count} frases guardadas}}'**
  String settingsTrainingCount(int count);

  /// No description provided for @settingsTrainingDelete.
  ///
  /// In es, this message translates to:
  /// **'Borrar frases guardadas'**
  String get settingsTrainingDelete;

  /// No description provided for @settingsTrainingDeleteConfirm.
  ///
  /// In es, this message translates to:
  /// **'¿Borrar todas las frases guardadas para entrenar a Viernes? Esta acción no se puede deshacer.'**
  String get settingsTrainingDeleteConfirm;

  /// No description provided for @settingsTrainingDeleted.
  ///
  /// In es, this message translates to:
  /// **'Frases borradas'**
  String get settingsTrainingDeleted;

  /// No description provided for @settingsSectionAppearance.
  ///
  /// In es, this message translates to:
  /// **'Apariencia'**
  String get settingsSectionAppearance;

  /// No description provided for @settingsTheme.
  ///
  /// In es, this message translates to:
  /// **'Tema'**
  String get settingsTheme;

  /// No description provided for @themeSystem.
  ///
  /// In es, this message translates to:
  /// **'Según el sistema'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In es, this message translates to:
  /// **'Claro'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In es, this message translates to:
  /// **'Oscuro'**
  String get themeDark;

  /// No description provided for @settingsSectionPermissions.
  ///
  /// In es, this message translates to:
  /// **'Permisos'**
  String get settingsSectionPermissions;

  /// No description provided for @permissionNotifications.
  ///
  /// In es, this message translates to:
  /// **'Notificaciones'**
  String get permissionNotifications;

  /// No description provided for @permissionExactAlarms.
  ///
  /// In es, this message translates to:
  /// **'Alarmas a la hora exacta'**
  String get permissionExactAlarms;

  /// No description provided for @permissionFullScreen.
  ///
  /// In es, this message translates to:
  /// **'Alertas a pantalla completa'**
  String get permissionFullScreen;

  /// No description provided for @permissionGranted.
  ///
  /// In es, this message translates to:
  /// **'Permitido'**
  String get permissionGranted;

  /// No description provided for @permissionMissing.
  ///
  /// In es, this message translates to:
  /// **'Falta permiso'**
  String get permissionMissing;

  /// No description provided for @permissionsGrant.
  ///
  /// In es, this message translates to:
  /// **'Permitir'**
  String get permissionsGrant;

  /// No description provided for @permissionsBannerTitle.
  ///
  /// In es, this message translates to:
  /// **'Viernes no puede avisarte'**
  String get permissionsBannerTitle;

  /// No description provided for @permissionsBannerBody.
  ///
  /// In es, this message translates to:
  /// **'Para que tus recordatorios suenen a tiempo, permite las notificaciones y las alarmas.'**
  String get permissionsBannerBody;

  /// No description provided for @channelReminders.
  ///
  /// In es, this message translates to:
  /// **'Recordatorios'**
  String get channelReminders;

  /// No description provided for @channelUrgent.
  ///
  /// In es, this message translates to:
  /// **'Recordatorios urgentes'**
  String get channelUrgent;

  /// No description provided for @channelSilent.
  ///
  /// In es, this message translates to:
  /// **'Recordatorios en horario de silencio'**
  String get channelSilent;

  /// No description provided for @channelDescription.
  ///
  /// In es, this message translates to:
  /// **'Avisos de tus recordatorios'**
  String get channelDescription;

  /// No description provided for @channelSummaries.
  ///
  /// In es, this message translates to:
  /// **'Resúmenes diarios'**
  String get channelSummaries;

  /// No description provided for @channelSummariesDescription.
  ///
  /// In es, this message translates to:
  /// **'Lo que tienes en la mañana y lo que quedó pendiente en la noche'**
  String get channelSummariesDescription;

  /// No description provided for @summaryMoveToTomorrow.
  ///
  /// In es, this message translates to:
  /// **'Pasar a mañana'**
  String get summaryMoveToTomorrow;

  /// No description provided for @homeMoveToTomorrow.
  ///
  /// In es, this message translates to:
  /// **'Pasar a mañana'**
  String get homeMoveToTomorrow;

  /// No description provided for @feedbackMovedToTomorrow.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =0{No había nada para mover} =1{Pasé 1 recordatorio a mañana} other{Pasé {count} recordatorios a mañana}}'**
  String feedbackMovedToTomorrow(int count);

  /// No description provided for @remindersFilterAll.
  ///
  /// In es, this message translates to:
  /// **'Todas'**
  String get remindersFilterAll;

  /// No description provided for @historyLast7Days.
  ///
  /// In es, this message translates to:
  /// **'Últimos 7 días'**
  String get historyLast7Days;

  /// No description provided for @historyMostSnoozed.
  ///
  /// In es, this message translates to:
  /// **'Lo que más pospones'**
  String get historyMostSnoozed;

  /// No description provided for @historySnoozedTimes.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 vez} other{{count} veces}}'**
  String historySnoozedTimes(int count);

  /// No description provided for @widgetAdd.
  ///
  /// In es, this message translates to:
  /// **'Agregar widget a la pantalla de inicio'**
  String get widgetAdd;

  /// No description provided for @widgetAddSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Tus próximos recordatorios y un botón para hablar con Viernes'**
  String get widgetAddSubtitle;

  /// No description provided for @alertBodyWithLead.
  ///
  /// In es, this message translates to:
  /// **'{when} · faltan {remaining}'**
  String alertBodyWithLead(String when, String remaining);

  /// No description provided for @alertStillPending.
  ///
  /// In es, this message translates to:
  /// **'Sigue pendiente · {when}'**
  String alertStillPending(String when);

  /// No description provided for @alertSpoken.
  ///
  /// In es, this message translates to:
  /// **'Recordatorio: {title}. ¿Ya lo hiciste?'**
  String alertSpoken(String title);

  /// No description provided for @alertSnoozeQuestion.
  ///
  /// In es, this message translates to:
  /// **'¿Cuándo te lo recuerdo?'**
  String get alertSnoozeQuestion;

  /// No description provided for @alertSnoozeIn.
  ///
  /// In es, this message translates to:
  /// **'En {duration}'**
  String alertSnoozeIn(String duration);

  /// No description provided for @alertSnoozeTomorrow.
  ///
  /// In es, this message translates to:
  /// **'Mañana a esta hora'**
  String get alertSnoozeTomorrow;

  /// No description provided for @alertReplyByVoice.
  ///
  /// In es, this message translates to:
  /// **'Responder por voz'**
  String get alertReplyByVoice;

  /// No description provided for @alertListeningHint.
  ///
  /// In es, this message translates to:
  /// **'Di «ya lo hice», «todavía no» o «ya no lo necesito»'**
  String get alertListeningHint;

  /// No description provided for @alertDismissed.
  ///
  /// In es, this message translates to:
  /// **'Listo, ya no te lo recordaré.'**
  String get alertDismissed;

  /// No description provided for @alertDidNotUnderstand.
  ///
  /// In es, this message translates to:
  /// **'No te entendí. Toca un botón o vuelve a intentarlo.'**
  String get alertDidNotUnderstand;

  /// No description provided for @alertNoMic.
  ///
  /// In es, this message translates to:
  /// **'El micrófono no está disponible.'**
  String get alertNoMic;

  /// No description provided for @wakeSection.
  ///
  /// In es, this message translates to:
  /// **'Activación por voz'**
  String get wakeSection;

  /// No description provided for @wakeEnable.
  ///
  /// In es, this message translates to:
  /// **'Decir «Viernes» para activar'**
  String get wakeEnable;

  /// No description provided for @wakeSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Escucha solo su nombre, sin internet. Usa algo más de batería.'**
  String get wakeSubtitle;

  /// No description provided for @wakeDownloadNote.
  ///
  /// In es, this message translates to:
  /// **'La primera vez descarga un modelo de voz de unos 38 MB (mejor con Wi‑Fi).'**
  String get wakeDownloadNote;

  /// No description provided for @wakeDownloading.
  ///
  /// In es, this message translates to:
  /// **'Descargando el modelo de voz… {percent} %'**
  String wakeDownloading(int percent);

  /// No description provided for @wakeListening.
  ///
  /// In es, this message translates to:
  /// **'Atento: di «Viernes» cuando quieras'**
  String get wakeListening;

  /// No description provided for @wakeSensitivity.
  ///
  /// In es, this message translates to:
  /// **'Sensibilidad'**
  String get wakeSensitivity;

  /// No description provided for @wakeSensitivityLow.
  ///
  /// In es, this message translates to:
  /// **'Menos falsas activaciones'**
  String get wakeSensitivityLow;

  /// No description provided for @wakeSensitivityMedium.
  ///
  /// In es, this message translates to:
  /// **'Equilibrada'**
  String get wakeSensitivityMedium;

  /// No description provided for @wakeSensitivityHigh.
  ///
  /// In es, this message translates to:
  /// **'Responde más fácil'**
  String get wakeSensitivityHigh;

  /// No description provided for @wakeOverlay.
  ///
  /// In es, this message translates to:
  /// **'Abrir al instante sobre otras apps'**
  String get wakeOverlay;

  /// No description provided for @wakeOverlaySubtitle.
  ///
  /// In es, this message translates to:
  /// **'Sin este permiso, si estás usando otra app verás un aviso para tocar.'**
  String get wakeOverlaySubtitle;

  /// No description provided for @wakeRemoveModel.
  ///
  /// In es, this message translates to:
  /// **'Borrar el modelo de voz descargado'**
  String get wakeRemoveModel;

  /// No description provided for @wakeErrorMic.
  ///
  /// In es, this message translates to:
  /// **'Necesito permiso para usar el micrófono.'**
  String get wakeErrorMic;

  /// No description provided for @wakeChime.
  ///
  /// In es, this message translates to:
  /// **'Sonido al activarse'**
  String get wakeChime;

  /// No description provided for @wakeChimeSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Un tono corto confirma que Viernes te oyó'**
  String get wakeChimeSubtitle;

  /// No description provided for @wakeEngine.
  ///
  /// In es, this message translates to:
  /// **'Detector'**
  String get wakeEngine;

  /// No description provided for @wakeEngineOwn.
  ///
  /// In es, this message translates to:
  /// **'Propio'**
  String get wakeEngineOwn;

  /// No description provided for @wakeEngineVosk.
  ///
  /// In es, this message translates to:
  /// **'Vosk'**
  String get wakeEngineVosk;

  /// No description provided for @wakeEngineOwnNote.
  ///
  /// In es, this message translates to:
  /// **'Detector propio de Viernes: ligero y sin descargas.'**
  String get wakeEngineOwnNote;

  /// No description provided for @wakeEngineVoskNote.
  ///
  /// In es, this message translates to:
  /// **'Modelo general de voz (38 MB). Úsalo si el propio no te reconoce bien.'**
  String get wakeEngineVoskNote;

  /// No description provided for @wakeErrorDownload.
  ///
  /// In es, this message translates to:
  /// **'No se pudo descargar el modelo de voz. Revisa tu conexión e inténtalo de nuevo.'**
  String get wakeErrorDownload;

  /// No description provided for @learningTitle.
  ///
  /// In es, this message translates to:
  /// **'Cómo aprende Viernes'**
  String get learningTitle;

  /// No description provided for @learningOpen.
  ///
  /// In es, this message translates to:
  /// **'Cómo aprende Viernes'**
  String get learningOpen;

  /// No description provided for @learningOpenSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Lo que aprendió de ti y qué tan bien te entiende'**
  String get learningOpenSubtitle;

  /// No description provided for @learningPrivacy.
  ///
  /// In es, this message translates to:
  /// **'Viernes aprende de tus recordatorios en este teléfono. Nada se envía a internet.'**
  String get learningPrivacy;

  /// No description provided for @learningEnable.
  ///
  /// In es, this message translates to:
  /// **'Aprendizaje personal'**
  String get learningEnable;

  /// No description provided for @learningEnableSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Ajusta categorías, horarios y anticipación a tu forma de usarlo'**
  String get learningEnableSubtitle;

  /// No description provided for @learningWhatItLearned.
  ///
  /// In es, this message translates to:
  /// **'Lo que aprendió'**
  String get learningWhatItLearned;

  /// No description provided for @learningTrainedOn.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =0{Aún no hay recordatorios para aprender} =1{Aprendió de 1 recordatorio} other{Aprendió de {count} recordatorios}}'**
  String learningTrainedOn(int count);

  /// No description provided for @learningCategories.
  ///
  /// In es, this message translates to:
  /// **'Categorías'**
  String get learningCategories;

  /// No description provided for @learningAccuracy.
  ///
  /// In es, this message translates to:
  /// **'Acierta en el {percent} % de los casos (medido con tus datos)'**
  String learningAccuracy(int percent);

  /// No description provided for @learningNeedsMoreData.
  ///
  /// In es, this message translates to:
  /// **'Necesita al menos 10 recordatorios con categoría para medir su acierto'**
  String get learningNeedsMoreData;

  /// No description provided for @learningYourTimes.
  ///
  /// In es, this message translates to:
  /// **'Tus horarios'**
  String get learningYourTimes;

  /// No description provided for @learningMorning.
  ///
  /// In es, this message translates to:
  /// **'En la mañana'**
  String get learningMorning;

  /// No description provided for @learningAfternoon.
  ///
  /// In es, this message translates to:
  /// **'En la tarde'**
  String get learningAfternoon;

  /// No description provided for @learningNight.
  ///
  /// In es, this message translates to:
  /// **'En la noche'**
  String get learningNight;

  /// No description provided for @learningNotYet.
  ///
  /// In es, this message translates to:
  /// **'aún aprendiendo'**
  String get learningNotYet;

  /// No description provided for @learningLeadTimes.
  ///
  /// In es, this message translates to:
  /// **'Tu anticipación habitual'**
  String get learningLeadTimes;

  /// No description provided for @learningConversations.
  ///
  /// In es, this message translates to:
  /// **'Conversaciones'**
  String get learningConversations;

  /// No description provided for @learningFirstTry.
  ///
  /// In es, this message translates to:
  /// **'Entendidas a la primera: {percent} %'**
  String learningFirstTry(int percent);

  /// No description provided for @learningTitleFixes.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =0{Ningún título corregido} =1{1 título corregido} other{{count} títulos corregidos}}'**
  String learningTitleFixes(int count);

  /// No description provided for @learningExport.
  ///
  /// In es, this message translates to:
  /// **'Exportar frases (JSONL)'**
  String get learningExport;

  /// No description provided for @learningExportSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Para entrenar la próxima versión de la IA. Tú eliges a dónde enviarlas.'**
  String get learningExportSubtitle;

  /// No description provided for @wakeSamplesTitle.
  ///
  /// In es, this message translates to:
  /// **'{real} activaciones reales · {errors} por error'**
  String wakeSamplesTitle(int real, int errors);

  /// No description provided for @wakeSamplesSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Audio de 2 s de cada «Viernes» (solo con tu consentimiento) para entrenar un detector que te reconozca mejor.'**
  String get wakeSamplesSubtitle;

  /// No description provided for @wakeSamplesExport.
  ///
  /// In es, this message translates to:
  /// **'Exportar grabaciones'**
  String get wakeSamplesExport;

  /// No description provided for @wakeSamplesDelete.
  ///
  /// In es, this message translates to:
  /// **'Borrar grabaciones'**
  String get wakeSamplesDelete;

  /// No description provided for @wakeSamplesSection.
  ///
  /// In es, this message translates to:
  /// **'Detector de «Viernes»'**
  String get wakeSamplesSection;

  /// No description provided for @neuralSection.
  ///
  /// In es, this message translates to:
  /// **'Red neuronal propia'**
  String get neuralSection;

  /// No description provided for @neuralUnavailable.
  ///
  /// In es, this message translates to:
  /// **'Esta versión no trae la red neuronal.'**
  String get neuralUnavailable;

  /// No description provided for @neuralVersion.
  ///
  /// In es, this message translates to:
  /// **'Modelo {version}'**
  String neuralVersion(String version);

  /// No description provided for @neuralAccuracy.
  ///
  /// In es, this message translates to:
  /// **'Acierta el título en el {percent} % de frases con tareas que nunca vio'**
  String neuralAccuracy(int percent);

  /// No description provided for @neuralTitles.
  ///
  /// In es, this message translates to:
  /// **'Títulos con la red neuronal (experimental)'**
  String get neuralTitles;

  /// No description provided for @neuralTitlesSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Si está muy segura, la red decide qué tarea guardar. Si no, mandan las reglas.'**
  String get neuralTitlesSubtitle;

  /// No description provided for @neuralCompare.
  ///
  /// In es, this message translates to:
  /// **'Con tus {count} frases: reglas {rules} % · red neuronal {neural} %'**
  String neuralCompare(int count, int rules, int neural);

  /// No description provided for @neuralCompareNeedsData.
  ///
  /// In es, this message translates to:
  /// **'Con 10 frases guardadas (activando «Ayudar a entrenar a Viernes») podrás comparar reglas y red con tu forma de hablar.'**
  String get neuralCompareNeedsData;

  /// No description provided for @neuralTry.
  ///
  /// In es, this message translates to:
  /// **'Prueba la red'**
  String get neuralTry;

  /// No description provided for @neuralTryHint.
  ///
  /// In es, this message translates to:
  /// **'Mañana a las 8 llamar a Juan'**
  String get neuralTryHint;

  /// No description provided for @settingsSectionAbout.
  ///
  /// In es, this message translates to:
  /// **'Acerca de'**
  String get settingsSectionAbout;

  /// No description provided for @settingsVersion.
  ///
  /// In es, this message translates to:
  /// **'Versión'**
  String get settingsVersion;

  /// No description provided for @settingsEnvironment.
  ///
  /// In es, this message translates to:
  /// **'Entorno'**
  String get settingsEnvironment;

  /// No description provided for @placesTitle.
  ///
  /// In es, this message translates to:
  /// **'Lugares'**
  String get placesTitle;

  /// No description provided for @placesAdd.
  ///
  /// In es, this message translates to:
  /// **'Agregar lugar'**
  String get placesAdd;

  /// No description provided for @placesAddTitle.
  ///
  /// In es, this message translates to:
  /// **'Guardar este lugar'**
  String get placesAddTitle;

  /// No description provided for @placesAddHint.
  ///
  /// In es, this message translates to:
  /// **'Se guarda tu ubicación actual. Hazlo cuando estés en el lugar.'**
  String get placesAddHint;

  /// No description provided for @placesName.
  ///
  /// In es, this message translates to:
  /// **'Nombre'**
  String get placesName;

  /// No description provided for @placesRadiusLabel.
  ///
  /// In es, this message translates to:
  /// **'Distancia para avisar'**
  String get placesRadiusLabel;

  /// No description provided for @placesRadius.
  ///
  /// In es, this message translates to:
  /// **'A {meters} m'**
  String placesRadius(int meters);

  /// No description provided for @placesUseHere.
  ///
  /// In es, this message translates to:
  /// **'Guardar aquí'**
  String get placesUseHere;

  /// No description provided for @placesLocating.
  ///
  /// In es, this message translates to:
  /// **'Buscando tu ubicación…'**
  String get placesLocating;

  /// No description provided for @placesNoLocation.
  ///
  /// In es, this message translates to:
  /// **'No pude obtener tu ubicación. Revisa que el GPS esté encendido.'**
  String get placesNoLocation;

  /// No description provided for @placesSaved.
  ///
  /// In es, this message translates to:
  /// **'Guardé «{name}»'**
  String placesSaved(String name);

  /// No description provided for @placesEmpty.
  ///
  /// In es, this message translates to:
  /// **'Aún no tienes lugares'**
  String get placesEmpty;

  /// No description provided for @placesEmptySubtitle.
  ///
  /// In es, this message translates to:
  /// **'Guarda Casa, Trabajo o el supermercado para que Viernes te avise al llegar.'**
  String get placesEmptySubtitle;

  /// No description provided for @placeHome.
  ///
  /// In es, this message translates to:
  /// **'Casa'**
  String get placeHome;

  /// No description provided for @placeWork.
  ///
  /// In es, this message translates to:
  /// **'Trabajo'**
  String get placeWork;

  /// No description provided for @placeSupermarket.
  ///
  /// In es, this message translates to:
  /// **'Supermercado'**
  String get placeSupermarket;

  /// No description provided for @placeGym.
  ///
  /// In es, this message translates to:
  /// **'Gimnasio'**
  String get placeGym;

  /// No description provided for @locationPermissionTitle.
  ///
  /// In es, this message translates to:
  /// **'Permiso de ubicación'**
  String get locationPermissionTitle;

  /// No description provided for @locationPermissionFine.
  ///
  /// In es, this message translates to:
  /// **'Para guardar lugares, Viernes necesita saber dónde estás.'**
  String get locationPermissionFine;

  /// No description provided for @locationPermissionBackground.
  ///
  /// In es, this message translates to:
  /// **'Para avisarte con la app cerrada, elige «Permitir todo el tiempo». Viernes solo usa tu ubicación para estos avisos.'**
  String get locationPermissionBackground;

  /// No description provided for @locationRemindersTitle.
  ///
  /// In es, this message translates to:
  /// **'Por ubicación'**
  String get locationRemindersTitle;

  /// No description provided for @locationRemindersAdd.
  ///
  /// In es, this message translates to:
  /// **'Nuevo por ubicación'**
  String get locationRemindersAdd;

  /// No description provided for @locationRemindersEmpty.
  ///
  /// In es, this message translates to:
  /// **'Sin recordatorios por ubicación'**
  String get locationRemindersEmpty;

  /// No description provided for @locationRemindersEmptySubtitle.
  ///
  /// In es, this message translates to:
  /// **'Dile a Viernes: «recuérdame comprar leche cuando llegue a casa».'**
  String get locationRemindersEmptySubtitle;

  /// No description provided for @locationOnArrive.
  ///
  /// In es, this message translates to:
  /// **'Al llegar a {place}'**
  String locationOnArrive(String place);

  /// No description provided for @locationOnLeave.
  ///
  /// In es, this message translates to:
  /// **'Al salir de {place}'**
  String locationOnLeave(String place);

  /// No description provided for @locationArrive.
  ///
  /// In es, this message translates to:
  /// **'Al llegar'**
  String get locationArrive;

  /// No description provided for @locationLeave.
  ///
  /// In es, this message translates to:
  /// **'Al salir'**
  String get locationLeave;

  /// No description provided for @settingsPlaces.
  ///
  /// In es, this message translates to:
  /// **'Lugares y recordatorios por ubicación'**
  String get settingsPlaces;

  /// No description provided for @settingsPlacesSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Avisos al llegar a casa, al trabajo o al supermercado'**
  String get settingsPlacesSubtitle;

  /// No description provided for @sharingTitle.
  ///
  /// In es, this message translates to:
  /// **'Compartir'**
  String get sharingTitle;

  /// No description provided for @sharingSignIn.
  ///
  /// In es, this message translates to:
  /// **'Inicia sesión para compartir'**
  String get sharingSignIn;

  /// No description provided for @sharingSignInSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Las listas y los recordatorios compartidos usan tu cuenta de Google.'**
  String get sharingSignInSubtitle;

  /// No description provided for @sharingOffline.
  ///
  /// In es, this message translates to:
  /// **'Sin conexión. Las listas compartidas necesitan internet.'**
  String get sharingOffline;

  /// No description provided for @sharingTabLists.
  ///
  /// In es, this message translates to:
  /// **'Listas'**
  String get sharingTabLists;

  /// No description provided for @sharingTabSent.
  ///
  /// In es, this message translates to:
  /// **'Enviados'**
  String get sharingTabSent;

  /// No description provided for @sharingTabContacts.
  ///
  /// In es, this message translates to:
  /// **'Contactos'**
  String get sharingTabContacts;

  /// No description provided for @settingsSharing.
  ///
  /// In es, this message translates to:
  /// **'Compartir'**
  String get settingsSharing;

  /// No description provided for @settingsSharingSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Listas compartidas, recordatorios enviados y contactos'**
  String get settingsSharingSubtitle;

  /// No description provided for @listsNew.
  ///
  /// In es, this message translates to:
  /// **'Nueva lista'**
  String get listsNew;

  /// No description provided for @listsName.
  ///
  /// In es, this message translates to:
  /// **'Nombre de la lista'**
  String get listsName;

  /// No description provided for @listsNameHint.
  ///
  /// In es, this message translates to:
  /// **'Mercado'**
  String get listsNameHint;

  /// No description provided for @listsEmpty.
  ///
  /// In es, this message translates to:
  /// **'Aún no tienes listas'**
  String get listsEmpty;

  /// No description provided for @listsEmptySubtitle.
  ///
  /// In es, this message translates to:
  /// **'Crea una (mercado, pendientes de la casa…) y compártela. O dile a Viernes: «agrega leche a la lista del mercado».'**
  String get listsEmptySubtitle;

  /// No description provided for @listsMembers.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{Solo tú} other{{count} personas}}'**
  String listsMembers(int count);

  /// No description provided for @listsShare.
  ///
  /// In es, this message translates to:
  /// **'Compartir lista'**
  String get listsShare;

  /// No description provided for @listsShareByEmail.
  ///
  /// In es, this message translates to:
  /// **'Con otro correo…'**
  String get listsShareByEmail;

  /// No description provided for @listsAddItem.
  ///
  /// In es, this message translates to:
  /// **'Agregar…'**
  String get listsAddItem;

  /// No description provided for @listsNoItems.
  ///
  /// In es, this message translates to:
  /// **'Lista vacía'**
  String get listsNoItems;

  /// No description provided for @listsNoItemsSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Escribe arriba o dile a Viernes qué agregar.'**
  String get listsNoItemsSubtitle;

  /// No description provided for @listsAddedBy.
  ///
  /// In es, this message translates to:
  /// **'Lo agregó {name}'**
  String listsAddedBy(String name);

  /// No description provided for @listsClearDone.
  ///
  /// In es, this message translates to:
  /// **'Quitar los marcados'**
  String get listsClearDone;

  /// No description provided for @listsDelete.
  ///
  /// In es, this message translates to:
  /// **'Eliminar lista'**
  String get listsDelete;

  /// No description provided for @listsLeave.
  ///
  /// In es, this message translates to:
  /// **'Salir de la lista'**
  String get listsLeave;

  /// No description provided for @sentEmpty.
  ///
  /// In es, this message translates to:
  /// **'No has enviado recordatorios'**
  String get sentEmpty;

  /// No description provided for @sentEmptySubtitle.
  ///
  /// In es, this message translates to:
  /// **'Dile a Viernes: «recuérdale a Sofi recoger el paquete mañana a las 5».'**
  String get sentEmptySubtitle;

  /// No description provided for @sentPending.
  ///
  /// In es, this message translates to:
  /// **'enviado'**
  String get sentPending;

  /// No description provided for @sentAccepted.
  ///
  /// In es, this message translates to:
  /// **'en su agenda'**
  String get sentAccepted;

  /// No description provided for @sentDone.
  ///
  /// In es, this message translates to:
  /// **'¡lo hizo!'**
  String get sentDone;

  /// No description provided for @sentCancelled.
  ///
  /// In es, this message translates to:
  /// **'cancelado'**
  String get sentCancelled;

  /// No description provided for @contactsAdd.
  ///
  /// In es, this message translates to:
  /// **'Agregar contacto'**
  String get contactsAdd;

  /// No description provided for @contactsEmpty.
  ///
  /// In es, this message translates to:
  /// **'Sin contactos'**
  String get contactsEmpty;

  /// No description provided for @contactsEmptySubtitle.
  ///
  /// In es, this message translates to:
  /// **'Agrega a quienes usan Viernes para enviarles recordatorios por voz.'**
  String get contactsEmptySubtitle;

  /// No description provided for @contactsHint.
  ///
  /// In es, this message translates to:
  /// **'Usa el correo con el que esa persona inicia sesión en Viernes.'**
  String get contactsHint;

  /// No description provided for @contactsName.
  ///
  /// In es, this message translates to:
  /// **'Nombre (como lo dirás)'**
  String get contactsName;

  /// No description provided for @contactsEmail.
  ///
  /// In es, this message translates to:
  /// **'Correo de Google'**
  String get contactsEmail;

  /// No description provided for @welcomeTitle.
  ///
  /// In es, this message translates to:
  /// **'Hola, soy Viernes'**
  String get welcomeTitle;

  /// No description provided for @welcomeSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Te recuerdo lo importante y te hago seguimiento hasta que lo hagas.'**
  String get welcomeSubtitle;

  /// No description provided for @welcomeBenefitBackup.
  ///
  /// In es, this message translates to:
  /// **'Tus recordatorios e historial, respaldados en tu cuenta'**
  String get welcomeBenefitBackup;

  /// No description provided for @welcomeBenefitRestore.
  ///
  /// In es, this message translates to:
  /// **'Si cambias de teléfono, lo recuperas todo al iniciar sesión'**
  String get welcomeBenefitRestore;

  /// No description provided for @welcomeBenefitPrivate.
  ///
  /// In es, this message translates to:
  /// **'Solo tú puedes ver tus datos'**
  String get welcomeBenefitPrivate;

  /// No description provided for @welcomeGoogle.
  ///
  /// In es, this message translates to:
  /// **'Continuar con Google'**
  String get welcomeGoogle;

  /// No description provided for @welcomeSkip.
  ///
  /// In es, this message translates to:
  /// **'Usar sin cuenta'**
  String get welcomeSkip;

  /// No description provided for @welcomeSkipNote.
  ///
  /// In es, this message translates to:
  /// **'Puedes iniciar sesión cuando quieras desde Ajustes.'**
  String get welcomeSkipNote;

  /// No description provided for @accountSection.
  ///
  /// In es, this message translates to:
  /// **'Cuenta'**
  String get accountSection;

  /// No description provided for @accountSignedOutTitle.
  ///
  /// In es, this message translates to:
  /// **'Inicia sesión con Google'**
  String get accountSignedOutTitle;

  /// No description provided for @accountSignedOutSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Respalda tus recordatorios e historial y recupéralos en cualquier teléfono'**
  String get accountSignedOutSubtitle;

  /// No description provided for @accountUnavailable.
  ///
  /// In es, this message translates to:
  /// **'Cuentas no disponibles en esta versión'**
  String get accountUnavailable;

  /// No description provided for @accountUnavailableSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Falta configurar Google en la app (ver docs/CUENTAS.md)'**
  String get accountUnavailableSubtitle;

  /// No description provided for @accountGreeting.
  ///
  /// In es, this message translates to:
  /// **'Hola, {name}'**
  String accountGreeting(String name);

  /// No description provided for @accountSyncNow.
  ///
  /// In es, this message translates to:
  /// **'Sincronizar ahora'**
  String get accountSyncNow;

  /// No description provided for @accountSyncing.
  ///
  /// In es, this message translates to:
  /// **'Sincronizando…'**
  String get accountSyncing;

  /// No description provided for @accountSyncedAt.
  ///
  /// In es, this message translates to:
  /// **'Sincronizado {time}'**
  String accountSyncedAt(String time);

  /// No description provided for @accountNeverSynced.
  ///
  /// In es, this message translates to:
  /// **'Aún no se ha sincronizado'**
  String get accountNeverSynced;

  /// No description provided for @accountOffline.
  ///
  /// In es, this message translates to:
  /// **'Sin conexión: se sincronizará al volver internet'**
  String get accountOffline;

  /// No description provided for @accountSyncError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo sincronizar. Se reintentará en un momento.'**
  String get accountSyncError;

  /// No description provided for @accountPending.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 cambio por subir} other{{count} cambios por subir}}'**
  String accountPending(int count);

  /// No description provided for @accountSignOut.
  ///
  /// In es, this message translates to:
  /// **'Cerrar sesión'**
  String get accountSignOut;

  /// No description provided for @accountSignOutConfirm.
  ///
  /// In es, this message translates to:
  /// **'Tus recordatorios quedan guardados en tu cuenta. Se quitarán de este teléfono y sus avisos dejarán de sonar hasta que vuelvas a iniciar sesión.'**
  String get accountSignOutConfirm;

  /// No description provided for @accountSignOutBlocked.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{Hay 1 cambio sin subir porque no hay internet.} other{Hay {count} cambios sin subir porque no hay internet.}} Si cierras sesión ahora se perderán.'**
  String accountSignOutBlocked(int count);

  /// No description provided for @accountSignOutAnyway.
  ///
  /// In es, this message translates to:
  /// **'Cerrar de todos modos'**
  String get accountSignOutAnyway;

  /// No description provided for @accountSignedOut.
  ///
  /// In es, this message translates to:
  /// **'Sesión cerrada'**
  String get accountSignedOut;

  /// No description provided for @accountDelete.
  ///
  /// In es, this message translates to:
  /// **'Eliminar mi cuenta'**
  String get accountDelete;

  /// No description provided for @accountDeleteSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Borra tu cuenta y todos tus datos de la nube'**
  String get accountDeleteSubtitle;

  /// No description provided for @accountDeleteConfirm.
  ///
  /// In es, this message translates to:
  /// **'Se borrarán para siempre tu cuenta, tus recordatorios y tu historial, en la nube y en este teléfono. Google te pedirá confirmar que eres tú.'**
  String get accountDeleteConfirm;

  /// No description provided for @accountDeleted.
  ///
  /// In es, this message translates to:
  /// **'Tu cuenta y tus datos se eliminaron'**
  String get accountDeleted;

  /// No description provided for @accountWelcomeBack.
  ///
  /// In es, this message translates to:
  /// **'¡Bienvenido, {name}! Tus datos están al día.'**
  String accountWelcomeBack(String name);

  /// No description provided for @accountMerged.
  ///
  /// In es, this message translates to:
  /// **'Tus recordatorios de este teléfono se guardaron en tu cuenta.'**
  String get accountMerged;

  /// No description provided for @accountSignInLater.
  ///
  /// In es, this message translates to:
  /// **'Sesión iniciada. Tus datos se sincronizarán cuando haya internet.'**
  String get accountSignInLater;

  /// No description provided for @authErrorCancelled.
  ///
  /// In es, this message translates to:
  /// **'Inicio de sesión cancelado'**
  String get authErrorCancelled;

  /// No description provided for @authErrorNetwork.
  ///
  /// In es, this message translates to:
  /// **'Sin conexión a internet. Inténtalo de nuevo.'**
  String get authErrorNetwork;

  /// No description provided for @authErrorNotConfigured.
  ///
  /// In es, this message translates to:
  /// **'El inicio de sesión con Google aún no está configurado en esta versión.'**
  String get authErrorNotConfigured;

  /// No description provided for @authErrorRejected.
  ///
  /// In es, this message translates to:
  /// **'Google no permitió el acceso con esta cuenta.'**
  String get authErrorRejected;

  /// No description provided for @authErrorUnknown.
  ///
  /// In es, this message translates to:
  /// **'No se pudo completar. Inténtalo de nuevo.'**
  String get authErrorUnknown;

  /// No description provided for @attachTitle.
  ///
  /// In es, this message translates to:
  /// **'Fotos y notas de voz'**
  String get attachTitle;

  /// No description provided for @attachPhoto.
  ///
  /// In es, this message translates to:
  /// **'Foto'**
  String get attachPhoto;

  /// No description provided for @attachVoiceNote.
  ///
  /// In es, this message translates to:
  /// **'Nota de voz'**
  String get attachVoiceNote;

  /// No description provided for @attachCamera.
  ///
  /// In es, this message translates to:
  /// **'Tomar foto'**
  String get attachCamera;

  /// No description provided for @attachGallery.
  ///
  /// In es, this message translates to:
  /// **'Elegir de la galería'**
  String get attachGallery;

  /// No description provided for @attachPhotoError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo agregar la foto'**
  String get attachPhotoError;

  /// No description provided for @attachDeleteConfirm.
  ///
  /// In es, this message translates to:
  /// **'¿Quitar este adjunto?'**
  String get attachDeleteConfirm;

  /// No description provided for @attachMicDenied.
  ///
  /// In es, this message translates to:
  /// **'Necesito permiso para usar el micrófono'**
  String get attachMicDenied;

  /// No description provided for @attachRecordError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo grabar'**
  String get attachRecordError;

  /// No description provided for @attachRecording.
  ///
  /// In es, this message translates to:
  /// **'Nota de voz'**
  String get attachRecording;

  /// No description provided for @attachRecordingHint.
  ///
  /// In es, this message translates to:
  /// **'Habla ahora. Hasta 2 minutos; toca Listo al terminar.'**
  String get attachRecordingHint;

  /// No description provided for @attachStop.
  ///
  /// In es, this message translates to:
  /// **'Listo'**
  String get attachStop;

  /// No description provided for @calendarFromPhone.
  ///
  /// In es, this message translates to:
  /// **'De tu calendario'**
  String get calendarFromPhone;

  /// No description provided for @calendarAllDay.
  ///
  /// In es, this message translates to:
  /// **'Todo el día'**
  String get calendarAllDay;

  /// No description provided for @summaryListen.
  ///
  /// In es, this message translates to:
  /// **'Escuchar'**
  String get summaryListen;

  /// No description provided for @alertSnoozeUsual.
  ///
  /// In es, this message translates to:
  /// **'Lo que sueles elegir'**
  String get alertSnoozeUsual;

  /// No description provided for @alertSnoozeOther.
  ///
  /// In es, this message translates to:
  /// **'Otro tiempo'**
  String get alertSnoozeOther;

  /// No description provided for @alertSnoozeFor.
  ///
  /// In es, this message translates to:
  /// **'Posponer {duration}'**
  String alertSnoozeFor(String duration);

  /// No description provided for @routineTitle.
  ///
  /// In es, this message translates to:
  /// **'Viernes notó una costumbre'**
  String get routineTitle;

  /// No description provided for @routineBody.
  ///
  /// In es, this message translates to:
  /// **'Sueles crear «{title}» {repeat}, a las {time}. ¿Lo dejo como repetitivo?'**
  String routineBody(String title, String repeat, String time);

  /// No description provided for @routineYes.
  ///
  /// In es, this message translates to:
  /// **'Sí, repetir'**
  String get routineYes;

  /// No description provided for @routineNo.
  ///
  /// In es, this message translates to:
  /// **'No, gracias'**
  String get routineNo;

  /// No description provided for @routineDone.
  ///
  /// In es, this message translates to:
  /// **'Listo: ahora se repite solo'**
  String get routineDone;

  /// No description provided for @birthdaysTitle.
  ///
  /// In es, this message translates to:
  /// **'Cumpleaños de tus contactos'**
  String get birthdaysTitle;

  /// No description provided for @birthdaysIntro.
  ///
  /// In es, this message translates to:
  /// **'Viernes lee los cumpleaños guardados en los contactos del teléfono y crea un recordatorio que se repite cada año.'**
  String get birthdaysIntro;

  /// No description provided for @birthdaysPermissionTitle.
  ///
  /// In es, this message translates to:
  /// **'Permite leer tus contactos'**
  String get birthdaysPermissionTitle;

  /// No description provided for @birthdaysPermissionBody.
  ///
  /// In es, this message translates to:
  /// **'Solo se leen el nombre y la fecha de cumpleaños. Nada sale del teléfono.'**
  String get birthdaysPermissionBody;

  /// No description provided for @birthdaysAllow.
  ///
  /// In es, this message translates to:
  /// **'Permitir'**
  String get birthdaysAllow;

  /// No description provided for @birthdaysTime.
  ///
  /// In es, this message translates to:
  /// **'Hora del aviso'**
  String get birthdaysTime;

  /// No description provided for @birthdaysBefore.
  ///
  /// In es, this message translates to:
  /// **'Aviso previo'**
  String get birthdaysBefore;

  /// No description provided for @birthdaysDays.
  ///
  /// In es, this message translates to:
  /// **'{days, plural, =0{Sin aviso previo} =1{1 día antes} other{{days} días antes}}'**
  String birthdaysDays(int days);

  /// No description provided for @birthdaysAuto.
  ///
  /// In es, this message translates to:
  /// **'Agregar solos los nuevos'**
  String get birthdaysAuto;

  /// No description provided for @birthdaysAutoSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Al abrir la app, si guardas un cumpleaños nuevo en tus contactos'**
  String get birthdaysAutoSubtitle;

  /// No description provided for @birthdaysEmpty.
  ///
  /// In es, this message translates to:
  /// **'Tus contactos no tienen cumpleaños guardados'**
  String get birthdaysEmpty;

  /// No description provided for @birthdaysEmptyBody.
  ///
  /// In es, this message translates to:
  /// **'Agrega la fecha en la app Contactos (campo «Cumpleaños») y vuelve aquí.'**
  String get birthdaysEmptyBody;

  /// No description provided for @birthdaysAdd.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =0{Nada nuevo por agregar} =1{Agregar 1 cumpleaños} other{Agregar {count} cumpleaños}}'**
  String birthdaysAdd(int count);

  /// No description provided for @birthdaysAdded.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =0{No se agregó ninguno} =1{Se agregó 1 cumpleaños} other{Se agregaron {count} cumpleaños}}'**
  String birthdaysAdded(int count);

  /// No description provided for @birthdaysAlready.
  ///
  /// In es, this message translates to:
  /// **'ya en tu agenda'**
  String get birthdaysAlready;

  /// No description provided for @birthdaysTurns.
  ///
  /// In es, this message translates to:
  /// **'cumple {age}'**
  String birthdaysTurns(int age);

  /// No description provided for @settingsCalendar.
  ///
  /// In es, this message translates to:
  /// **'Incluir mi calendario'**
  String get settingsCalendar;

  /// No description provided for @settingsCalendarSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Viernes lee tus eventos de Google Calendar para responder «¿tengo algo el viernes?» y para el resumen del día'**
  String get settingsCalendarSubtitle;

  /// No description provided for @settingsCalendarDenied.
  ///
  /// In es, this message translates to:
  /// **'Sin permiso de calendario no puedo leer tus eventos'**
  String get settingsCalendarDenied;

  /// No description provided for @settingsBirthdaysSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Agrégalos a tu agenda con aviso previo'**
  String get settingsBirthdaysSubtitle;

  /// No description provided for @settingsDriving.
  ///
  /// In es, this message translates to:
  /// **'Modo conducción'**
  String get settingsDriving;

  /// No description provided for @settingsDrivingHelp.
  ///
  /// In es, this message translates to:
  /// **'Respuestas más cortas y botones grandes para usar Viernes sin mirar mucho la pantalla.'**
  String get settingsDrivingHelp;

  /// No description provided for @drivingMode.
  ///
  /// In es, this message translates to:
  /// **'{mode, select, off{Desactivado} on{Siempre activado} other{Automático: al conectar el carro por Bluetooth o con Android Auto}}'**
  String drivingMode(String mode);

  /// No description provided for @settingsHeadset.
  ///
  /// In es, this message translates to:
  /// **'Botón de los audífonos'**
  String get settingsHeadset;

  /// No description provided for @settingsHeadsetSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Mantén presionado el botón del audífono o del asistente y elige Viernes. Toca para abrir los ajustes del asistente del teléfono.'**
  String get settingsHeadsetSubtitle;

  /// No description provided for @settingsSpeakBriefing.
  ///
  /// In es, this message translates to:
  /// **'Leer el resumen de la mañana'**
  String get settingsSpeakBriefing;

  /// No description provided for @settingsSpeakBriefingSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Al tocar el resumen de la mañana, Viernes te lo dice en voz alta'**
  String get settingsSpeakBriefingSubtitle;

  /// No description provided for @wakeLowBattery.
  ///
  /// In es, this message translates to:
  /// **'Pausar con batería baja'**
  String get wakeLowBattery;

  /// No description provided for @wakeLowBatterySubtitle.
  ///
  /// In es, this message translates to:
  /// **'Con 15 % o menos y sin cargar, deja de escuchar hasta que cargues'**
  String get wakeLowBatterySubtitle;

  /// No description provided for @learningSnooze.
  ///
  /// In es, this message translates to:
  /// **'Sueles posponer {duration}'**
  String learningSnooze(String duration);

  /// No description provided for @learningSnoozeSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Es el tiempo del botón «Posponer» y de «recuérdamelo después»'**
  String get learningSnoozeSubtitle;

  /// No description provided for @learningForget.
  ///
  /// In es, this message translates to:
  /// **'Olvidar'**
  String get learningForget;

  /// No description provided for @batterySection.
  ///
  /// In es, this message translates to:
  /// **'Consumo de la escucha'**
  String get batterySection;

  /// No description provided for @batteryNoData.
  ///
  /// In es, this message translates to:
  /// **'Aún no hay datos'**
  String get batteryNoData;

  /// No description provided for @batteryNoDataSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Activa «Viernes» por voz y vuelve en un rato para ver cuánto gasta.'**
  String get batteryNoDataSubtitle;

  /// No description provided for @batteryMeasuring.
  ///
  /// In es, this message translates to:
  /// **'Midiendo la batería…'**
  String get batteryMeasuring;

  /// No description provided for @batteryPerHour.
  ///
  /// In es, this message translates to:
  /// **'≈ {percent} % de batería por hora mientras escucha (todo el teléfono)'**
  String batteryPerHour(String percent);

  /// No description provided for @batteryListening.
  ///
  /// In es, this message translates to:
  /// **'{hours} h escuchando · {saved} % del tiempo en silencio (ahorro)'**
  String batteryListening(String hours, int saved);

  /// No description provided for @batteryCpu.
  ///
  /// In es, this message translates to:
  /// **'Procesador: {cpu} % · {ms} ms por análisis'**
  String batteryCpu(String cpu, String ms);

  /// No description provided for @batteryReset.
  ///
  /// In es, this message translates to:
  /// **'Reiniciar cifras'**
  String get batteryReset;

  /// No description provided for @listsAssign.
  ///
  /// In es, this message translates to:
  /// **'Asignar'**
  String get listsAssign;

  /// No description provided for @listsAssignTitle.
  ///
  /// In es, this message translates to:
  /// **'¿A quién le toca «{item}»?'**
  String listsAssignTitle(String item);

  /// No description provided for @listsMe.
  ///
  /// In es, this message translates to:
  /// **'Yo'**
  String get listsMe;

  /// No description provided for @listsNobody.
  ///
  /// In es, this message translates to:
  /// **'A nadie'**
  String get listsNobody;

  /// No description provided for @listsForYou.
  ///
  /// In es, this message translates to:
  /// **'Te toca a ti'**
  String get listsForYou;

  /// No description provided for @listsFor.
  ///
  /// In es, this message translates to:
  /// **'Le toca a {name}'**
  String listsFor(String name);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
