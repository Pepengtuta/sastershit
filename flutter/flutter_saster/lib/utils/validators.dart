/// Shared form validators.
class Validators {
  /// Usernames must be readable and unambiguous: letters, numbers, dot,
  /// underscore, and hyphen only (3-50 chars, no spaces or other symbols).
  /// Mirrors the server-side rule in app/includes/functions.php and
  /// api/user_audit.php.
  static final RegExp usernamePattern = RegExp(r'^[A-Za-z0-9._-]{3,50}$');

  static String? username(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Required';
    if (!usernamePattern.hasMatch(v)) {
      return 'Use 3-50 letters, numbers, dots, underscores, or hyphens (no spaces).';
    }
    return null;
  }
}
