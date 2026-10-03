// Expresiones regulares armadas por partes.
// ignore_for_file: missing_whitespace_between_adjacent_strings

import 'package:viernes/ai/nlu/es/spanish_text.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_enums.dart';

/// Clasifica la tarea en una categoría por palabras clave.
///
/// Es la línea base del clasificador; el modelo propio (Fase 6) lo
/// reemplazará aprendiendo de las categorías que el usuario corrige.
abstract final class CategoryClassifier {
  // El orden importa: la primera categoría que coincide gana
  // ("cita médica" es salud aunque "cita" sea personal).
  static final _rules = <(ReminderCategory, RegExp)>[
    (
      ReminderCategory.health,
      _words(
        'medic|doctor|doctora|pastilla|medicament|odontolog|dentista|'
        'ejercicio|gimnasio|gym|vacuna|terapia|hospital|clinica|eps|'
        'examenes de sangre|laboratorio|vitamina|presion|insulina|'
        'psicolog|nutricion|fisioterap|optometr|cita medica|control',
      ),
    ),
    (
      ReminderCategory.finance,
      _words(
        'pagar|pago|factura|arriendo|alquiler|banco|tarjeta|cuota|'
        'impuesto|recibo|transferi|consignar|prestamo|credito|nomina|'
        'declaracion de renta|servicios publicos|cobrar|deuda',
      ),
    ),
    (
      ReminderCategory.study,
      _words(
        'examen|parcial|quiz|tarea|clase|estudi|universidad|tesis|'
        'colegio|exposicion|profesor|curso|taller|semestre|matricula|'
        'leer el capitulo|trabajo de grado|monografia|asesoria',
      ),
    ),
    (
      ReminderCategory.work,
      _words(
        'reunion|informe|jefe|oficina|cliente|correo|email|trabaj|'
        'proyecto|presentacion|junta|contrato|propuesta|cotizacion|'
        'entrega|entregar|llamada con|comite|reporte|sprint|deploy',
      ),
    ),
    (
      ReminderCategory.home,
      _words(
        'basura|lavar|limpiar|cocinar|mercado|plantas|regar|ropa|casa|'
        'aseo|barrer|trapear|compras|supermercado|mascota|perro|gato|'
        'veterinari|planchar|nevera|reciclaje',
      ),
    ),
    (
      ReminderCategory.personal,
      _words(
        'cumpleanos|llamar|mama|papa|amig|familia|regalo|abuel|herman|'
        'novi|esposa|esposo|hij|visitar|cita|aniversario|tio|tia|prim',
      ),
    ),
  ];

  static RegExp _words(String alternatives) => RegExp('\\b(?:$alternatives)');

  static ReminderCategory classify(String title) {
    final folded = SpanishText.fold(title);
    for (final (category, pattern) in _rules) {
      if (pattern.hasMatch(folded)) return category;
    }
    return ReminderCategory.other;
  }
}
