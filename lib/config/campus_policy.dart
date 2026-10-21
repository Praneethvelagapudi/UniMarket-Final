/// Campus policy supplied by the project owner. Input validation only.
class CampusPolicy {
  static const domain = 'cb.students.edu';
  static final rollPattern = RegExp(r'^CB\.SC\.U4[A-Z]+[0-9]+$');
  static String normalizeRoll(String value) => value.trim().toUpperCase();
  static String normalizeEmail(String value) => value.trim().toLowerCase();
  static String? rollError(String? value) {
    if (!rollPattern.hasMatch(normalizeRoll(value ?? ''))) {
      return 'Use your campus roll number, e.g. CB.SC.U4CSE24157.';
    }
    return null;
  }

  static String? emailError(String? value, {String? roll}) {
    final parts = normalizeEmail(value ?? '').split('@');
    if (parts.length != 2 ||
        parts[1] != domain ||
        !rollPattern.hasMatch(parts[0].toUpperCase())) {
      return 'Use your roll-number email ending in @$domain.';
    }
    if (roll != null && parts[0] != normalizeRoll(roll).toLowerCase()) {
      return 'The email prefix must match your roll number.';
    }
    return null;
  }

  static String department(String roll) =>
      RegExp(r'U4([A-Z]+)').firstMatch(normalizeRoll(roll))?.group(1) ?? '';
}
