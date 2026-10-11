import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/validators.dart';

/// Shows a 3-segment Low / Medium / High bar and a live checklist of the
/// password rules. Rebuild it whenever the password text changes.
class PasswordStrengthIndicator extends StatelessWidget {
  const PasswordStrengthIndicator({super.key, required this.password});

  final String password;

  static const Color _good = Color(0xFF2E9E6B);

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox.shrink();

    final check = PasswordCheck.of(password);
    final strength = check.strength;

    final Color color = switch (strength) {
      PasswordStrength.low => AppColors.error,
      PasswordStrength.medium => AppColors.primary,
      PasswordStrength.high => _good,
    };
    final String label = switch (strength) {
      PasswordStrength.low => 'Low',
      PasswordStrength.medium => 'Medium',
      PasswordStrength.high => 'High',
    };
    final int filled = strength.index + 1;

    return Padding(
      padding: const EdgeInsets.only(top: 10, left: 2, right: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (int i = 0; i < 3; i++)
                Expanded(
                  child: Container(
                    height: 5,
                    margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
                    decoration: BoxDecoration(
                      color: i < filled ? color : AppColors.border,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _rule('At least 8 characters', check.hasLength),
          _rule('A number (0-9)', check.hasDigit),
          _rule('A special character (! @ # & ...)', check.hasSpecial),
          _rule('Upper & lower case letters (for High)', check.hasMixedCase),
        ],
      ),
    );
  }

  Widget _rule(String text, bool ok) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            size: 15,
            color: ok ? _good : AppColors.textMuted,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: ok ? AppColors.textDark : AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
