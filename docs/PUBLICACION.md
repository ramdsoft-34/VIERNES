# Publicación y firma

## 1. Crear la clave de publicación (una sola vez)

```bash
keytool -genkey -v -keystore %USERPROFILE%\viernes-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias viernes
```

⚠️ Guarda el archivo `.jks` y sus contraseñas en un lugar seguro, con copia de
respaldo. Si se pierden, no podrás publicar actualizaciones.

## 2. Configurar `android/key.properties`

Este archivo **no se sube a git** (ya está en `.gitignore`).

```properties
storePassword=<contraseña del almacén>
keyPassword=<contraseña de la clave>
keyAlias=viernes
storeFile=C:/Users/<usuario>/viernes-upload.jks
```

Si el archivo no existe, la compilación `release` usa la clave de depuración. Sirve
para probar, no para Play Store.

## 3. Compilar para Play Store

```bash
flutter build appbundle --flavor prod -t lib/main_prod.dart
```

Resultado: `build/app/outputs/bundle/prodRelease/app-prod-release.aab`

## 4. Requisitos de Google Play (Fase 7)

- [ ] Política de privacidad publicada (URL pública).
- [ ] Formulario **Seguridad de los datos**: datos solo en el dispositivo; frases
      para la IA únicamente con consentimiento.
- [ ] Declaración de permisos sensibles:
  - `USE_EXACT_ALARM` / `SCHEDULE_EXACT_ALARM`: app de recordatorios.
  - `USE_FULL_SCREEN_INTENT`: alertas tipo alarma.
  - `FOREGROUND_SERVICE_MICROPHONE`: escucha de la palabra "Viernes".
  - Video de demostración del uso del micrófono en segundo plano.
- [ ] Ficha: ícono 512 px, gráfico destacado 1024×500, capturas y descripción.
- [ ] Prueba interna → prueba cerrada (requisito para cuentas personales nuevas)
      → producción.
