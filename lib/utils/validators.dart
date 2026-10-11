enum PasswordStrength { low, medium, high }

/// Breaks a password into the individual rules we check.
class PasswordCheck {
  const PasswordCheck._({
    required this.hasLength,
    required this.hasUpper,
    required this.hasLower,
    required this.hasDigit,
    required this.hasSpecial,
  });

  factory PasswordCheck.of(String p) => PasswordCheck._(
        hasLength: p.length >= 8,
        hasUpper: RegExp(r'[A-Z]').hasMatch(p),
        hasLower: RegExp(r'[a-z]').hasMatch(p),
        hasDigit: RegExp(r'[0-9]').hasMatch(p),
        // any character that is not a letter, digit or whitespace
        hasSpecial: RegExp(r'[^A-Za-z0-9\s]').hasMatch(p),
      );

  final bool hasLength;
  final bool hasUpper;
  final bool hasLower;
  final bool hasDigit;
  final bool hasSpecial;

  bool get hasMixedCase => hasUpper && hasLower;

  /// Minimum needed to be ACCEPTED: 8+ chars, a number and a special character.
  bool get meetsMinimum => hasLength && hasDigit && hasSpecial;

  /// Low    -> does not meet the minimum (rejected)
  /// Medium -> meets the minimum (accepted)
  /// High   -> meets the minimum AND has upper + lower case letters
  PasswordStrength get strength {
    if (!meetsMinimum) return PasswordStrength.low;
    return hasMixedCase ? PasswordStrength.high : PasswordStrength.medium;
  }
}

class Validators {
  static final RegExp _emailRegex =
      RegExp(r'^[\w.\-+]+@([\w\-]+\.)+[\w\-]{2,}$');
  static final RegExp _usernameRegex = RegExp(r'^[a-zA-Z0-9_]+$');

  static String? name(String? v) {
    if (v == null || v.trim().isEmpty) return 'Name is required';
    if (v.trim().length < 3) return 'Name must be at least 3 characters';
    return null;
  }

  static String? username(String? v) {
    if (v == null || v.trim().isEmpty) return 'Username is required';
    final u = v.trim();
    if (u.length < 3) return 'Username must be at least 3 characters';
    if (u.length > 20) return 'Username can be at most 20 characters';
    if (!_usernameRegex.hasMatch(u)) {
      return 'Only letters, numbers and underscore allowed';
    }
    return null;
  }

  static String? email(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email is required';
    if (!_emailRegex.hasMatch(v.trim())) return 'Enter a valid email address';
    return null;
  }

  /// Used on SIGN UP (enforces the full password policy).
  static String? newPassword(String? v) {
    if (v == null || v.isEmpty) return 'Password is required';
    final c = PasswordCheck.of(v);
    if (!c.hasLength) return 'Use at least 8 characters';
    if (!c.hasDigit) return 'Add at least one number';
    if (!c.hasSpecial) return 'Add at least one special character (! @ # & ...)';
    return null;
  }

  /// Used on LOGIN (only checks it is not empty; the server checks the rest).
  static String? loginPassword(String? v) {
    if (v == null || v.isEmpty) return 'Password is required';
    return null;
  }

  static String? confirmPassword(String? v, String original) {
    if (v == null || v.isEmpty) return 'Please confirm your password';
    if (v != original) return 'Passwords do not match';
    return null;
  }
}
