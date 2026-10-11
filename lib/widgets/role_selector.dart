import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum UserRole { buyer, seller }

extension UserRoleX on UserRole {
  /// Value stored in Firestore.
  String get value => this == UserRole.buyer ? 'buyer' : 'seller';
}

class RoleSelector extends StatelessWidget {
  const RoleSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final UserRole selected;
  final ValueChanged<UserRole> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _option(UserRole.buyer, Icons.shopping_bag_outlined, 'Buy'),
        const SizedBox(width: 12),
        _option(UserRole.seller, Icons.storefront_outlined, 'Sell'),
      ],
    );
  }

  Widget _option(UserRole role, IconData icon, String label) {
    final bool isSelected = selected == role;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(role),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.1)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
              width: isSelected ? 1.6 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon,
                  color: isSelected ? AppColors.primary : AppColors.textMuted,
                  size: 24),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isSelected ? AppColors.primary : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
