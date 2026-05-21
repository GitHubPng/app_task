class Validators {
  /// Returns error message or null if valid
  static String? validateTitle(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Título obrigatório.';
    }
    return null;
  }

  /// Returns true if the date string (yyyy-MM-dd) is before today
  static bool isDateInPast(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final today = DateTime.now();
      final todayOnly = DateTime(today.year, today.month, today.day);
      return date.isBefore(todayOnly);
    } catch (_) {
      return false;
    }
  }

  /// Formats a yyyy-MM-dd string to dd/MM/yyyy for display
  static String formatDateDisplay(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day.toString().padLeft(2, '0')}/'
          '${date.month.toString().padLeft(2, '0')}/'
          '${date.year}';
    } catch (_) {
      return dateStr;
    }
  }
}
