import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vaultx/screens/app_shell.dart';
import 'package:vaultx/services/notification_service.dart';


import 'firebase_options.dart';
import 'screens/onboarding_screen.dart';
import 'screens/login_screen.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Local Push Notifications Server
  await NotificationService().init();

  final prefs = await SharedPreferences.getInstance();
  final seenOnboarding = prefs.getBool('seenOnboarding') ?? false;

  runApp(SmartVaultApp(seenOnboarding: seenOnboarding));
}class SmartVaultApp extends StatelessWidget {
  final bool seenOnboarding;
  const SmartVaultApp({super.key, required this.seenOnboarding});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          // ✅ Logged in
          if (snapshot.hasData) {
            return const AppShell();
          }

          // ❌ Not logged in
          return seenOnboarding
              ? const LoginScreen()
              : const OnboardingScreen();

        },
      ),
    );
  }
}
