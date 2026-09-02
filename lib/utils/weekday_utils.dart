/// Helpers de dia da semana (1=Segunda ... 7=Domingo), alinhado a DateTime.weekday.
class WeekdayUtils {
  static const List<String> shortLabels = [
    'Seg',
    'Ter',
    'Qua',
    'Qui',
    'Sex',
    'Sáb',
    'Dom',
  ];

  static const List<String> fullLabels = [
    'Segunda',
    'Terça',
    'Quarta',
    'Quinta',
    'Sexta',
    'Sábado',
    'Domingo',
  ];

  static String shortLabel(int weekday) {
    if (weekday < 1 || weekday > 7) return '';
    return shortLabels[weekday - 1];
  }

  static String fullLabel(int weekday) {
    if (weekday < 1 || weekday > 7) return '';
    return fullLabels[weekday - 1];
  }

  /// Segunda-feira (início da semana) da semana que contém [date].
  static DateTime weekStart(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }

  /// Desloca [weekStart] em [weeks] semanas (negativo = anterior).
  static DateTime addWeeks(DateTime weekStart, int weeks) {
    final normalized = DateTime(weekStart.year, weekStart.month, weekStart.day);
    return normalized.add(Duration(days: weeks * 7));
  }

  /// Data do [weekday] (1=Seg ... 7=Dom) dentro da semana que começa em [weekStart].
  static DateTime dateInWeek(DateTime weekStart, int weekday) {
    final start = DateTime(weekStart.year, weekStart.month, weekStart.day);
    return start.add(Duration(days: weekday - DateTime.monday));
  }

  /// Data (só dia) do [weekday] na semana de [reference].
  /// Preferir [dateInWeek] quando [reference] já for o weekStart.
  static DateTime dateForWeekday(int weekday, {DateTime? reference}) {
    final ref = reference ?? DateTime.now();
    return dateInWeek(weekStart(ref), weekday);
  }

  /// Formata DateTime como YYYY-MM-DD.
  static String toDateString(DateTime date) {
    return '${date.year}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  /// Formata intervalo da semana: "31/08 - 06/09".
  static String formatWeekRange(DateTime weekStart) {
    final end = weekStart.add(const Duration(days: 6));
    return '${_dayMonth(weekStart)} - ${_dayMonth(end)}';
  }

  static String _dayMonth(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}';
  }

  /// Número do dia para exibição no seletor (ex.: "31").
  static String dayNumber(DateTime date) {
    return date.day.toString().padLeft(2, '0');
  }

  /// Data de hoje em YYYY-MM-DD.
  static String todayString() => toDateString(DateTime.now());

  /// Converte lista de dias em string "1,3,5".
  static String daysToStorage(List<int> days) {
    final sorted = [...days]..sort();
    return sorted.join(',');
  }

  /// Converte "1,3,5" em lista ordenada.
  static List<int> daysFromStorage(String? raw) {
    if (raw == null || raw.trim().isEmpty) return [];
    return raw
        .split(',')
        .map((e) => int.tryParse(e.trim()))
        .whereType<int>()
        .toList()
      ..sort();
  }
}
