# ADR 0001 — Decisiones técnicas iniciales

- **Estado:** aceptada
- **Fecha:** 2026-10-02

## Contexto

Viernes es una app Android de recordatorios por voz, de uso personal al inicio y
pensada para publicarse en Google Play. Tendrá una IA propia (palabra de
activación e intérprete) que se entrenará y cambiará con el tiempo.

## Decisiones

| Tema | Elección | Motivo |
|---|---|---|
| Plataforma | Solo Android | Escucha en segundo plano y alertas a pantalla completa solo son viables ahí |
| Estado / DI | Riverpod 3 | Estándar actual, fácil de probar, permite sustituir dependencias |
| Navegación | go_router | Rutas por URL: las notificaciones abrirán rutas concretas |
| Base de datos | Drift (SQLite) | Consultas tipadas, streams reactivos, migraciones versionadas |
| Preferencias | SharedPreferences | Una clave por opción: agregar opciones sin migrar |
| Entidades | Clases inmutables escritas a mano | `freezed` solo tenía versión preliminar compatible |
| Errores | `Result<T>` + `Failure` sellada | La UI siempre maneja el caso de error |
| Repetición | Texto tipo RRULE | Compatible con calendarios externos en el futuro |
| Historial | Tabla de eventos sin clave foránea | Estadísticas confiables aunque se borren recordatorios |
| Palabra de activación | openWakeWord (Fase 4) | Código abierto, entrenable y sin licencia comercial de pago |
| Intérprete | Reglas → modelo TFLite propio | Funciona desde el día 1 y mejora con datos reales |
| Datos para la IA | Solo con consentimiento explícito | Requisito de Google Play y de privacidad |
| Versiones | `dev` (`.dev`) y `prod` | Probar sin tocar los datos reales |
| Calidad | very_good_analysis + CI | Reglas estrictas y verificación en cada cambio |

## Consecuencias

- Las pantallas no dependen de Drift: se puede agregar sincronización en la nube
  con otra implementación de `ReminderRepository`.
- Sin generación de código para las entidades: `copyWith`, `==` y `hashCode` son
  manuales y hay que actualizarlos al agregar campos (lo cubren las pruebas).
