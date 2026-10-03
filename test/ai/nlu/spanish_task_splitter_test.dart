import 'package:flutter_test/flutter_test.dart';
import 'package:viernes/ai/nlu/es/spanish_task_splitter.dart';

void main() {
  test('separa tareas que empiezan con verbo', () {
    expect(SpanishTaskSplitter.split('Pagar la luz y llamar a mi mamá'), [
      'Pagar la luz',
      'Llamar a mi mamá',
    ]);
    expect(
      SpanishTaskSplitter.split(
        'comprar pan, sacar la basura y luego regar las matas',
      ),
      ['Comprar pan', 'Sacar la basura', 'Regar las matas'],
    );
    expect(SpanishTaskSplitter.split('Llamar a Juan y mandarle el informe'), [
      'Llamar a Juan',
      'Mandarle el informe',
    ]);
  });

  test('no parte una sola tarea', () {
    expect(SpanishTaskSplitter.split('Comprar pan y leche'), [
      'Comprar pan y leche',
    ]);
    expect(SpanishTaskSplitter.split('Reunión con Juan y Camila'), [
      'Reunión con Juan y Camila',
    ]);
    expect(SpanishTaskSplitter.split('Ir al bar y al lugar de siempre'), [
      'Ir al bar y al lugar de siempre',
    ]);
    expect(SpanishTaskSplitter.split(''), isEmpty);
  });
}
