import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'config/stripe_config.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  if (stripeConfigured) {
    // A bad publishable key should not stop the whole app from starting.
    try {
      Stripe.publishableKey = kStripePublishableKey;
      await Stripe.instance.applySettings();
    } catch (_) {}
  }
  // Debug builds can talk to the local Functions emulator instead of a
  // deployed backend, so card checkout can be demoed without the Blaze plan.
  if (const bool.fromEnvironment('USE_FUNCTIONS_EMULATOR')) {
    FirebaseFunctions.instance.useFunctionsEmulator(
      const String.fromEnvironment(
        'FUNCTIONS_EMULATOR_HOST',
        defaultValue: 'localhost',
      ),
      5001,
    );
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ThriftMate',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const SplashScreen(),
    );
  }
}
