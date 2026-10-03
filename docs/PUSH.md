# Avisos push y fotos en la nube

Viernes 0.10.0 usa dos servicios de Firebase que **requieren el plan Blaze**
(pago por uso). Con el uso de una familia el costo es prácticamente cero:
Cloud Functions incluye 2 millones de ejecuciones gratis al mes y Storage
5 GB.

| Qué | Para qué |
|---|---|
| **Cloud Functions** (`functions/index.js`) | Avisar al instante cuando te envían un recordatorio, cuando completan lo que enviaste, cuando te asignan algo en una lista o te invitan a una. |
| **Cloud Storage** (`firebase/storage.rules`) | Respaldar las fotos y notas de voz de los recordatorios. |

Sin esto la app funciona igual: lo compartido llega al abrir Viernes y los
adjuntos quedan solo en el teléfono.

## 1. Activar Blaze (lo haces tú)

1. <https://console.firebase.google.com/project/viernes-ramdsoft/usage/details?authuser=2>
2. **Modificar plan → Blaze** y elige una cuenta de facturación.
3. Recomendado: **Alertas de presupuesto** de 1 USD en Google Cloud →
   Facturación → Presupuestos y alertas.

## 2. Activar Storage

Firebase → **Storage → Comenzar** → modo producción → ubicación
`us-east1`.

## 3. Desplegar funciones y reglas

Desde la carpeta del proyecto (la primera vez inicia sesión con la cuenta de
RamdSoft):

```bash
npx firebase-tools login
```

```bash
npx firebase-tools deploy --only functions,firestore:rules,storage
```

Las funciones van en `us-east1` (misma región que Firestore).

## Cómo funciona

- Cada teléfono con sesión guarda su dirección push en `push_tokens/{token}`
  junto con su correo. Al cerrar sesión se borra.
- Las funciones envían **mensajes de datos** de alta prioridad. Con la app
  cerrada, Viernes los atiende en segundo plano
  (`lib/features/push/push_service.dart`): un recordatorio recibido se agrega
  a la agenda con sus alarmas y se marca «en su agenda».
- Direcciones de teléfonos que ya no existen se borran solas.
- Los adjuntos se guardan en `users/{uid}/attachments/{id}.jpg|m4a`; sus datos
  en Firestore `users/{uid}/attachments/{id}`. Solo el dueño puede leerlos.

## Ver registros

```bash
npx firebase-tools functions:log
```
