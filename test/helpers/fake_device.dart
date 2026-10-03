import 'package:viernes/core/platform/device_data.dart';

/// Teléfono simulado: calendario, contactos y carro.
class FakeDeviceData implements DeviceData {
  FakeDeviceData({
    this.events = const [],
    this.contactBirthdays = const [],
    this.calendarAllowed = true,
    this.contactsAllowed = true,
    this.driving = false,
  });

  List<CalendarEvent> events;
  List<ContactBirthday> contactBirthdays;
  bool calendarAllowed;
  bool contactsAllowed;
  bool driving;
  int assistantSettingsOpened = 0;

  @override
  Future<bool> hasCalendarPermission() async => calendarAllowed;

  @override
  Future<bool> requestCalendarPermission() async => calendarAllowed;

  @override
  Future<List<CalendarEvent>> calendarEvents(
    DateTime from,
    DateTime to,
  ) async => [
    for (final e in events)
      if (e.start.isBefore(to) && e.end.isAfter(from)) e,
  ];

  @override
  Future<bool> hasContactsPermission() async => contactsAllowed;

  @override
  Future<bool> requestContactsPermission() async => contactsAllowed;

  @override
  Future<List<ContactBirthday>> birthdays() async => contactBirthdays;

  @override
  Future<bool> isDriving() async => driving;

  @override
  Future<bool> requestBluetoothPermission() async => true;

  @override
  Future<void> openAssistantSettings() async => assistantSettingsOpened++;
}
