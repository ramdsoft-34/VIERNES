# Viernes

Asistente personal de recordatorios por voz para Android. Di **"Viernes"**, cuéntale
qué necesitas recordar y te hará seguimiento hasta que confirmes que lo hiciste.

> Paquete: `com.ramdsoft.viernes` · RamdSoft

## Estado

| Fase | Contenido | Estado |
|---|---|---|
| 1 | Arquitectura, base de datos, 5 pantallas, recordatorios manuales | ✅ |
| 2 | Intérprete de frases en español + dictado + confirmación hablada | ✅ |
| 3 | Alarmas exactas, alerta a pantalla completa, insistencia | ✅ |
| 4 | Palabra de activación "Viernes" en segundo plano | ✅ |
| 5 | Resúmenes, widget, categorías automáticas | ✅ |
| 6 | Recolección de datos e IA propia v1 (aprendizaje en el teléfono) | ✅ |
| 6.5 | Cuentas con Google y respaldo en la nube | ✅ (falta google-services.json) |
| 7 | Publicación en Google Play | ⏳ |

## Requisitos

- Flutter 3.44 (Dart 3.12)
- Android SDK con Java 17
- Android 8.0 (API 26) o superior en el teléfono

## Primeros pasos

```bash
flutter pub get
dart run build_runner build
flutter run --flavor dev -t lib/main_dev.dart
```

En VS Code usa las configuraciones **Viernes (dev)** o **Viernes (prod)**.

### Versiones

| Versión | ID | Nombre | Uso |
|---|---|---|---|
| `dev` | `com.ramdsoft.viernes.dev` | Viernes Dev | Desarrollo y pruebas |
| `prod` | `com.ramdsoft.viernes` | Viernes | Uso real y Play Store |

Se pueden tener las dos instaladas a la vez; cada una con sus propios datos.

## Comandos útiles

```bash
flutter analyze                         # análisis estático (debe quedar en 0)
flutter test                            # pruebas
dart format lib test                    # formato
dart run build_runner build             # regenerar código de Drift
flutter build apk --flavor prod -t lib/main_prod.dart --release
flutter build appbundle --flavor prod -t lib/main_prod.dart   # para Play Store
```

## Documentación

- [Arquitectura](docs/ARQUITECTURA.md)
- [Decisiones técnicas (ADR)](docs/adr/)
- [Cuentas con Google (configuración)](docs/CUENTAS.md)
- [Publicación y firma](docs/PUBLICACION.md)
- [Registro de cambios](CHANGELOG.md)
