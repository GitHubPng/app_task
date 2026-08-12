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

  /// Data (só dia) do [weekday] na semana corrente relativa a [reference].
  static DateTime dateForWeekday(int weekday, {DateTime? reference}) {
    final now = reference ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return today.add(Duration(days: weekday - today.weekday));
  }

  /// Formata DateTime como YYYY-MM-DD.
  static String toDateString(DateTime date) {
    return '${date.year}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
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
