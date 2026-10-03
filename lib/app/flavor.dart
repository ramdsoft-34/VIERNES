/// Versión de la app. Cada una se instala por separado en el teléfono
/// (`com.ramdsoft.viernes.dev` y `com.ramdsoft.viernes`), con su propia base
/// de datos.
enum AppFlavor {
  dev,
  prod;

  bool get isDev => this == AppFlavor.dev;
}
