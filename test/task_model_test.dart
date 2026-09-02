import 'package:app_task/models/task.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Task effective getters', () {
    test('usa override quando presente', () {
      final task = Task(
        title: 'Treino',
        description: 'treino normal',
        time: '15:00',
        createdAt: '2026-01-01',
        occurrenceTitleOverride: 'Treino pesado',
        occurrenceDescriptionOverride: 'foco em força',
        occurrenceTimeOverride: '17:00',
      );

      expect(task.effectiveTitle, 'Treino pesado');
      expect(task.effectiveDescription, 'foco em força');
      expect(task.effectiveTime, '17:00');
    });

    test('fallback para regra quando override ausente', () {
      final task = Task(
        title: 'Treino',
        description: 'treino normal',
        time: '15:00',
        createdAt: '2026-01-01',
      );

      expect(task.effectiveTitle, 'Treino');
      expect(task.effectiveDescription, 'treino normal');
      expect(task.effectiveTime, '15:00');
    });
  });
}
