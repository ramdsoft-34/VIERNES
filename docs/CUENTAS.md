# Cuentas con Google: configuración

Viernes usa **Firebase Authentication** (inicio de sesión con Google) y **Cloud
Firestore** (respaldo de recordatorios, historial y preferencias).

Sin configurar nada, la app compila y funciona **sin cuentas**. En Ajustes →
Cuenta aparece «Cuentas no disponibles en esta versión».

Para activar las cuentas solo se necesita **un archivo**, `google-services.json`.
No hay claves que copiar dentro del código.

## Datos del proyecto

| Dato | Valor |
|---|---|
| Proyecto de Google Cloud | **Viernes** (`viernes-ramdsoft`, n.º 381498931833) |
| Cuenta de Google | la de RamdSoft (`authuser=2` en el navegador) |
| Paquete de producción | `com.ramdsoft.viernes` |
| Paquete de desarrollo | `com.ramdsoft.viernes.dev` |
| SHA-1 de la clave de firma actual (debug) | `2C:9D:CD:B5:6B:A5:E3:CB:2E:B7:77:E3:70:36:0B:E4:AD:F7:29:18` |
| SHA-256 (por si lo pide) | `B4:53:82:F7:50:56:D7:8A:4E:CA:3B:55:2F:0E:6C:BB:72:AA:C8:4A:15:A0:7E:AB:4E:DD:66:E0:A9:A4:49:67` |

> El SHA-1 es la «huella» de la clave con la que se firma el APK. Google solo
> deja iniciar sesión a apps con una huella registrada. Hoy los APK se firman
> con la clave debug de este computador. Cuando se cree la clave de
> publicación (Fase 7) hay que **agregar su SHA-1** y el de Play App Signing.

## Paso 1 — Agregar Firebase al proyecto

1. Abre <https://console.firebase.google.com/?authuser=2> con la cuenta de
   RamdSoft.
2. Elige **Crear un proyecto**. Abajo, toca **«Agregar Firebase a un proyecto
   de Google Cloud»** y selecciona **Viernes (viernes-ramdsoft)**.
3. Acepta las condiciones. Google Analytics es opcional; puedes desactivarlo.
4. Usa el plan **Spark (gratis)**: alcanza de sobra para uso personal.

## Paso 2 — Activar el inicio de sesión con Google

1. En el menú: **Compilación → Authentication → Comenzar**.
2. En **Método de acceso**, elige **Google** → **Habilitar**.
3. Escribe el nombre público «Viernes» y elige tu correo de asistencia.
4. Toca **Guardar**.

## Paso 3 — Crear la base de datos (Firestore)

1. **Compilación → Firestore Database → Crear base de datos**.
2. Edición **Standard**. Ubicación **`us-east1` (Carolina del Sur)**, la más
   cercana a Colombia. *No se puede cambiar después.*
3. Elige **modo de producción** y toca Crear.
4. En la pestaña **Reglas**, borra lo que hay y pega el contenido de
   [`firebase/firestore.rules`](../firebase/firestore.rules). Luego toca
   **Publicar**. Estas reglas hacen que cada usuario solo pueda ver lo suyo.

## Paso 4 — Registrar la app Android (las dos versiones)

1. Toca ⚙️ **Configuración del proyecto** → **General** → **Tus apps** → ícono
   de **Android**.
2. Completa:
   - Nombre del paquete: `com.ramdsoft.viernes`
   - Sobrenombre: `Viernes`
   - SHA-1: `2C:9D:CD:B5:6B:A5:E3:CB:2E:B7:77:E3:70:36:0B:E4:AD:F7:29:18`
3. Toca **Registrar app**. Puedes saltar los pasos del SDK (ya están hechos en
   el código).
4. Repite con la versión de desarrollo:
   - Nombre del paquete: `com.ramdsoft.viernes.dev`
   - Sobrenombre: `Viernes Dev`
   - El mismo SHA-1.

> Son obligatorias las dos. Con el archivo puesto, Gradle exige que
> `google-services.json` incluya los dos paquetes.

## Paso 5 — Descargar el archivo y ponerlo en el proyecto

1. Después de registrar las dos apps, ve a **Configuración del proyecto →
   General**. En cualquiera de las dos apps toca **google-services.json**
   para descargarlo. El archivo ya trae las dos apps.
2. Cópialo **exactamente** aquí:

   ```text
   C:\Users\melod\Documents\viernes\android\app\google-services.json
   ```

3. Listo. No hay que tocar el código. El archivo trae:
   - La clave de API de Android (`api_key`).
   - El ID de cliente web (`client_type: 3`), con el que la app pide el token
     de Google. El plugin lo lee solo del recurso `default_web_client_id`.

   Abre el archivo y verifica que haya un bloque `oauth_client` con
   `"client_type": 3`. Si no aparece, revisa que el Paso 2 esté guardado y
   vuelve a descargar el archivo.

## Paso 6 — Compilar y probar

```bash
flutter build apk --flavor prod -t lib/main_prod.dart --release --target-platform android-arm64
```

Al abrir la app por primera vez aparece la bienvenida con **«Continuar con
Google»**. También puedes iniciar sesión desde Ajustes → Cuenta.

## Problemas comunes

| Síntoma | Causa y solución |
|---|---|
| «El inicio de sesión con Google aún no está configurado» | Falta el archivo, o el SHA-1 no coincide con la clave que firmó el APK. Revisa el Paso 4. |
| La ventana de Google se cierra sola o da «error 10 / DEVELOPER_ERROR» | El SHA-1 o el nombre del paquete no coinciden. Agrégalos en la consola, descarga el archivo otra vez y recompila. |
| «Google no permitió el acceso con esta cuenta» | En Google Cloud → **Google Auth Platform → Público**, la app está en modo «Prueba» y la cuenta no está en la lista de usuarios de prueba. Agrégala o pasa la app a «En producción». Para correo y perfil no se necesita verificación. |
| Sincroniza pero no aparecen datos | Las reglas no están publicadas (Paso 3.4). En Firestore → Uso aparecerán lecturas denegadas. |
| La compilación falla con «No matching client found for package name» | El archivo no incluye las dos apps (Paso 4.4). |

## Cómo funciona (resumen técnico)

- **Sesión**: Firebase Auth la guarda en el teléfono; sigue abierta aunque se
  cierre la app o se reinicie el teléfono.
- **Primero sin internet**: la base local (Drift) sigue siendo la fuente de
  verdad. Cada cambio queda marcado `dirty` y unos segundos después se sube.
  Los borrados se guardan en `sync_tombstones` para propagarlos.
- **Descarga**: al abrir la app, al volver a ella, al iniciar sesión y desde
  «Sincronizar ahora». Solo baja lo que cambió desde la última vez (cursor por
  `serverUpdatedAt`).
- **Conflictos**: si el dato local no tiene cambios pendientes, manda la nube.
  Si los tiene, gana el cambio más reciente.
- **Asociación de la cuenta**: lo que había sin cuenta se une a la cuenta al
  iniciar sesión. Si el teléfono tenía datos de *otra* cuenta, se reemplazan.
- **Cerrar sesión**: sube lo pendiente y borra los datos del teléfono. Los
  avisos dejan de sonar. Si no hay internet, avisa antes de perder cambios.
- **Eliminar cuenta**: pide confirmar con Google y borra todo, en la nube y en
  el teléfono. Google Play exige esta opción.
- **No se sube**: las frases de entrenamiento de la IA (siguen solo en el
  teléfono) ni el ajuste «Activación por voz», que depende del teléfono.

Estructura en Firestore:

```text
users/{uid}                    perfil, cliente y preferencias (settings)
users/{uid}/reminders/{id}     recordatorios (deleted: true si se borró)
users/{uid}/events/{syncId}    historial (deleted: true si se deshizo)
```

## Para más adelante

- **Otros métodos de acceso** (correo, Apple): son nuevos métodos en
  `AuthRepository` y un botón más en la bienvenida.
- **Respaldo de las frases de la IA**: es otra colección bajo `users/{uid}`,
  siempre con consentimiento.
- **Play Store (Fase 7)**: agregar los SHA-1 de la clave de publicación y de
  Play App Signing, y declarar en «Seguridad de los datos» el correo, el
  nombre y el contenido de la app guardado en la nube.
