# ADR 0002 — Cuentas con Google y sincronización en la nube

- **Estado:** aceptada
- **Fecha:** 2026-10-02

## Contexto

Los usuarios deben poder iniciar sesión rápido con Google y conservar su
historial al cambiar de teléfono o reinstalar la app. La app ya funciona sin
internet sobre una base local (Drift) y eso no debe cambiar.

## Decisiones

| Tema | Elección | Motivo |
|---|---|---|
| Autenticación | Firebase Auth + `google_sign_in` 7 (Credential Manager) | Inicio con un toque, sesión persistente, gratis, sin servidor propio |
| Nube | Cloud Firestore | Reglas por usuario, plan gratuito suficiente, SDK oficial para Flutter |
| Fuente de verdad | La base local | Alarmas, voz y widget funcionan sin internet; la nube es respaldo y puente |
| Caché de Firestore | Desactivada | Evita una segunda copia en el teléfono y restos al cerrar sesión |
| Cambios pendientes | Columna `dirty` + tabla `sync_tombstones` | También marca lo escrito desde la notificación (otro proceso) |
| Descarga | Por cursor `serverUpdatedAt` | Solo baja lo nuevo; con margen y aplicación idempotente |
| Conflictos | Sin cambios locales manda la nube; con cambios, el más reciente | Simple y predecible para una sola persona con varios teléfonos |
| Datos sin cuenta | Se unen a la cuenta al iniciar sesión | No se pierde nada por empezar sin cuenta |
| Cerrar sesión | Sube lo pendiente y borra los datos locales | Privacidad si otra persona usa el teléfono |
| Eliminar cuenta | Reautenticación + borrado en nube y teléfono | Requisito de Google Play |
| Configuración | Solo `google-services.json`; plugin de Gradle condicional | Sin el archivo la app compila y funciona sin cuentas |

## Consecuencias

- Las frases de entrenamiento de la IA no se suben (privacidad). Si se suben en
  el futuro, será con consentimiento aparte.
- Para publicar hay que registrar los SHA-1 de las claves de publicación y de
  Play App Signing (ver `docs/CUENTAS.md`).
- Firebase obliga a usar el plugin de Kotlin (KGP) en algunos plugins; Flutter ya
  advierte que en el futuro exigirá Kotlin integrado.
