import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../utils/validators.dart';

enum UsernameStatus { idle, checking, available, taken, error }

/// Text field that checks (after the user stops typing for 0.5s) whether the
/// username is free, and shows the result live. Place it inside a [Form]:
/// its validator also blocks submission while taken / still checking.
class UsernameField extends StatefulWidget {
  const UsernameField({super.key, required this.controller});

  final TextEditingController controller;

  @override
  State<UsernameField> createState() => _UsernameFieldState();
}

class _UsernameFieldState extends State<UsernameField> {
  static const Color _ok = Color(0xFF2E9E6B);

  Timer? _debounce;
  UsernameStatus _status = UsernameStatus.idle;
  int _requestId = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _requestId++; // invalidates any check that is still in flight

    if (Validators.username(value) != null) {
      setState(() => _status = UsernameStatus.idle);
      return;
    }

    setState(() => _status = UsernameStatus.checking);
    _debounce = Timer(const Duration(milliseconds: 500), () => _check(value));
  }

  Future<void> _check(String value) async {
    final id = ++_requestId;
    try {
      final available = await AuthService.instance.isUsernameAvailable(value);
      if (!mounted || id != _requestId) return;
      setState(() => _status =
          available ? UsernameStatus.available : UsernameStatus.taken);
    } catch (_) {
      if (!mounted || id != _requestId) return;
      setState(() => _status = UsernameStatus.error);
    }
  }

  String? _validate(String? value) {
    final base = Validators.username(value);
    if (base != null) return base;
    return switch (_status) {
      UsernameStatus.taken => 'Username is already taken',
      UsernameStatus.checking => 'Checking availability... please wait',
      UsernameStatus.error => 'Could not check username. Check your internet.',
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final Widget? suffix = switch (_status) {
      UsernameStatus.checking => const Padding(
          padding: EdgeInsets.all(14),
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      UsernameStatus.available =>
        const Icon(Icons.check_circle_rounded, color: _ok),
      UsernameStatus.taken =>
        const Icon(Icons.cancel_rounded, color: AppColors.error),
      _ => null,
    };

    final String? helper = switch (_status) {
      UsernameStatus.checking => 'Checking availability...',
      UsernameStatus.available => 'Username is available',
      UsernameStatus.taken => 'Username is already taken',
      UsernameStatus.error => 'Could not check username',
      _ => null,
    };
    final Color helperColor = switch (_status) {
      UsernameStatus.available => _ok,
      UsernameStatus.taken || UsernameStatus.error => AppColors.error,
      _ => AppColors.textMuted,
    };

    return TextFormField(
      controller: widget.controller,
      onChanged: _onChanged,
      validator: _validate,
      autocorrect: false,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_]')),
        LengthLimitingTextInputFormatter(20),
      ],
      decoration: InputDecoration(
        labelText: 'Username',
        prefixIcon:
            const Icon(Icons.alternate_email, color: AppColors.textMuted),
        suffixIcon: suffix,
        helperText: helper,
        helperStyle: TextStyle(color: helperColor, fontSize: 12),
      ),
    );
  }
}
