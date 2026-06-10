/// Shared form validators for the auth flow. Returned strings are shown
/// inline under the field; `null` means the value is valid.
class Validators {
  Validators._();

  // Pragmatic email pattern: local@domain.tld with no spaces.
  static final RegExp _emailRegExp = RegExp(
    r"^[\w.!#$%&'*+/=?^`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$",
  );

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Please enter your email';
    if (!_emailRegExp.hasMatch(v)) return 'Please enter a valid email address';
    return null;
  }

  /// Sign-in only needs a non-empty password (don't reveal length rules to
  /// existing accounts). Use [newPassword] for sign-up.
  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Please enter your password';
    return null;
  }

  /// Stronger rules for newly created passwords.
  static String? newPassword(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Please enter a password';
    if (v.length < 6) return 'Password must be at least 6 characters';
    if (!v.contains(RegExp(r'[A-Za-z]')) || !v.contains(RegExp(r'[0-9]'))) {
      return 'Use at least one letter and one number';
    }
    return null;
  }

  static String? confirmPassword(String? value, String original) {
    if (value == null || value.isEmpty) return 'Please confirm your password';
    if (value != original) return 'Passwords do not match';
    return null;
  }
}
