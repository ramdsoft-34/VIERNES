/// Busca un valor de enum por su `name`; devuelve [fallback] si no existe
/// (p. ej. un valor guardado por una versión más nueva de la app).
T enumByName<T extends Enum>(List<T> values, String name, T fallback) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  return fallback;
}
