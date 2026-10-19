import 'package:app_task/utils/time_range.dart';
import 'package:flutter_test/flutter_test.dart';

int m(String hhmm) => TimeRange.toMinutes(hhmm)!;

void main() {
  const trabalho = TimeRange(
    start: '08:00',
    end: '15:00',
    breakStart: '12:00',
    breakEnd: '13:00',
  );

  group('toMinutes', () {
    test('converte e rejeita inválidos', () {
      expect(TimeRange.toMinutes('08:30'), 510);
      expect(TimeRange.toMinutes(null), isNull);
      expect(TimeRange.toMinutes(''), isNull);
      expect(TimeRange.toMinutes('8h'), isNull);
      expect(TimeRange.toMinutes('25:00'), isNull);
    });
  });

  group('validate', () {
    test('período com pausa válido', () {
      expect(trabalho.validate(), isNull);
      expect(const TimeRange(start: '05:50').validate(), isNull);
      expect(const TimeRange().validate(), isNull);
    });

    test('fim sem início', () {
      expect(
        const TimeRange(end: '15:00').validate(),
        'Defina o início antes do fim.',
      );
    });

    test('fim não posterior ao início', () {
      expect(
        const TimeRange(start: '08:00', end: '08:00').validate(),
        'O fim deve ser depois do início.',
      );
      expect(
        const TimeRange(start: '08:00', end: '07:00').validate(),
        'O fim deve ser depois do início.',
      );
    });

    test('pausa sem fim', () {
      expect(
        const TimeRange(start: '08:00', breakStart: '12:00', breakEnd: '13:00')
            .validate(),
        'Pausa exige horário de fim.',
      );
    });

    test('pausa incompleta', () {
      expect(
        const TimeRange(start: '08:00', end: '15:00', breakStart: '12:00')
            .validate(),
        'Defina início e fim da pausa.',
      );
    });

    test('pausa fora do período ou invertida', () {
      const msg = 'A pausa deve ficar dentro do período.';
      expect(
        const TimeRange(
          start: '08:00',
          end: '11:00',
          breakStart: '12:00',
          breakEnd: '13:00',
        ).validate(),
        msg,
      );
      expect(
        const TimeRange(
          start: '08:00',
          end: '15:00',
          breakStart: '13:00',
          breakEnd: '12:00',
        ).validate(),
        msg,
      );
      expect(
        const TimeRange(
          start: '08:00',
          end: '15:00',
          breakStart: '07:00',
          breakEnd: '09:00',
        ).validate(),
        msg,
      );
    });
  });

  group('statusAt', () {
    test('limites exatos', () {
      expect(trabalho.statusAt(m('07:59')), TimeStatus.none);
      expect(trabalho.statusAt(m('08:00')), TimeStatus.now);
      expect(trabalho.statusAt(m('12:00')), TimeStatus.paused);
      expect(trabalho.statusAt(m('12:59')), TimeStatus.paused);
      expect(trabalho.statusAt(m('13:00')), TimeStatus.now);
      expect(trabalho.statusAt(m('14:59')), TimeStatus.now);
      expect(trabalho.statusAt(m('15:00')), TimeStatus.none);
    });

    test('sem fim nunca é agora', () {
      expect(
        const TimeRange(start: '05:50').statusAt(m('05:50')),
        TimeStatus.none,
      );
    });
  });

  group('conflictsWith', () {
    test('ponto fora do período não conflita', () {
      expect(
        trabalho.conflictsWith(const TimeRange(start: '05:50')),
        isFalse,
      );
    });

    test('ponto dentro da pausa não conflita', () {
      expect(
        trabalho.conflictsWith(const TimeRange(start: '12:00')),
        isFalse,
      );
    });

    test('ponto dentro da parte ativa conflita (nos dois sentidos)', () {
      const treino = TimeRange(start: '14:00');
      expect(trabalho.conflictsWith(treino), isTrue);
      expect(treino.conflictsWith(trabalho), isTrue);
    });

    test('intervalo inteiro dentro da pausa não conflita', () {
      expect(
        trabalho.conflictsWith(
          const TimeRange(start: '12:15', end: '12:45'),
        ),
        isFalse,
      );
    });

    test('intervalo que invade a parte ativa conflita', () {
      expect(
        trabalho.conflictsWith(
          const TimeRange(start: '11:30', end: '12:30'),
        ),
        isTrue,
      );
    });

    test('intervalos encostados não conflitam', () {
      expect(
        trabalho.conflictsWith(const TimeRange(start: '15:00', end: '16:00')),
        isFalse,
      );
    });

    test('dois pontos e tarefa sem início não conflitam', () {
      expect(
        const TimeRange(start: '08:00')
            .conflictsWith(const TimeRange(start: '08:00')),
        isFalse,
      );
      expect(trabalho.conflictsWith(const TimeRange()), isFalse);
    });
  });
}
