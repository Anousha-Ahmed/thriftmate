import 'package:flutter/material.dart';

import '../screens/home_screen.dart';
import '../services/auth_service.dart';

/// Where a user lands after login. The shell changes with the mode:
/// buyers get Discover/Browse, sellers get Shop/Listings.
Widget homeForRole(String role) =>
    HomeScreen(role: role == 'seller' ? 'seller' : 'buyer');

/// One account, two modes (like OLX: the same person can sell and buy).
/// Saves the chosen mode and reopens the shell.
Future<void> switchMode(BuildContext context, String newRole) async {
  final user = AuthService.instance.currentUser;
  if (user == null) return;
  try {
    await AuthService.instance.setRole(user.uid, newRole);
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not switch mode. Try again.')),
      );
    }
    return;
  }
  if (!context.mounted) return;
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => homeForRole(newRole)),
    (route) => false,
  );
}
