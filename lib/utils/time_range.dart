/// Estado de uma tarefa em um instante do dia.
enum TimeStatus { none, now, paused }

/// Horário de uma tarefa: início, fim opcional e uma pausa opcional,
/// todos "HH:mm" no mesmo dia.
class TimeRange {
  final String? start;
  final String? end;
  final String? breakStart;
  final String? breakEnd;

  const TimeRange({this.start, this.end, this.breakStart, this.breakEnd});

  bool get hasEnd => toMinutes(end) != null;

  /// "HH:mm" → minutos desde 00:00; nulo, vazio ou inválido → null.
  static int? toMinutes(String? hhmm) {
    if (hhmm == null) return null;
    final match = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(hhmm);
    if (match == null) return null;
    final h = int.parse(match.group(1)!);
    final m = int.parse(match.group(2)!);
    if (h > 23 || m > 59) return null;
    return h * 60 + m;
  }

  /// Mensagem de erro (pt-BR) ou null se válido.
  String? validate() {
    final s = toMinutes(start);
    final e = toMinutes(end);
    final bs = toMinutes(breakStart);
    final be = toMinutes(breakEnd);

    if (e != null && s == null) return 'Defina o início antes do fim.';
    if (s != null && e != null && e <= s) {
      return 'O fim deve ser depois do início.';
    }
    if (bs == null && be == null) return null;
    if (e == null) return 'Pausa exige horário de fim.';
    if (bs == null || be == null) return 'Defina início e fim da pausa.';
    if (!(s! <= bs && bs < be && be <= e)) {
      return 'A pausa deve ficar dentro do período.';
    }
    return null;
  }

  TimeStatus statusAt(int minuteOfDay) {
    final s = toMinutes(start);
    final e = toMinutes(end);
    if (s == null || e == null) return TimeStatus.none;
    if (minuteOfDay < s || minuteOfDay >= e) return TimeStatus.none;
    final bs = toMinutes(breakStart);
    final be = toMinutes(breakEnd);
    if (bs != null && be != null && minuteOfDay >= bs && minuteOfDay < be) {
      return TimeStatus.paused;
    }
    return TimeStatus.now;
  }

  bool conflictsWith(TimeRange other) {
    final a = _activeSegments();
    final b = other._activeSegments();
    if (a == null || b == null) return false;

    final aPoint = toMinutes(start)!;
    final bPoint = toMinutes(other.start)!;
    // Ponto (tarefa sem fim) conflita se cai na parte ativa do outro.
    if (a.isEmpty && b.isEmpty) return false;
    if (a.isEmpty) return _contains(b, aPoint);
    if (b.isEmpty) return _contains(a, bPoint);

    for (final x in a) {
      for (final y in b) {
        if (x.$1 < y.$2 && y.$1 < x.$2) return true;
      }
    }
    return false;
  }

  /// Segmentos [início, fim) fora da pausa; [] para ponto; null sem início.
  List<(int, int)>? _activeSegments() {
    final s = toMinutes(start);
    if (s == null) return null;
    final e = toMinutes(end);
    if (e == null) return const [];
    final bs = toMinutes(breakStart);
    final be = toMinutes(breakEnd);
    if (bs == null || be == null) return [(s, e)];
    return [if (s < bs) (s, bs), if (be < e) (be, e)];
  }

  static bool _contains(List<(int, int)> segments, int point) =>
      segments.any((seg) => seg.$1 <= point && point < seg.$2);
}
