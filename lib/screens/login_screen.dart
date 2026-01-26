import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:vaultx/screens/onboarding_screen.dart';
import 'package:vaultx/screens/otp_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:vaultx/services/auth_service.dart';


import '../core/snacksbar.dart';


class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFDD53F), // amber top
              Color(0xFFFFFFFF), // white bottom
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// BACK BUTTON
                IconButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const OnboardingScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.arrow_back),
                ),

                const Spacer(),

                /// APP BRANDING
                Row(
                  children: const [
                    Text(
                      "Vault",
                      style: TextStyle(
                        fontSize: 54,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber,
                      ),
                    ),
                    Text(
                      "X",
                      style: TextStyle(
                        fontSize: 54,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                const Text(
                  "Organize bills and\nget timely reminders.",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                    color: Colors.black,
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  "Please sign in to continue",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                ),

                const Spacer(),



                const SizedBox(height: 12),

                /// GOOGLE (with logo)
                _LoginButton(
                  label: "Continue with Google",
                  imageAsset: 'assets/icon/google.png',
                  background: Colors.white,
                  textColor: Colors.black,
                  border: true,
                  onTap: () async {
                    try {
                      final user = await AuthService.instance.signInWithGoogle();


                      if (user == null) {
                        showAnimatedSnackBar(
                          context,
                          message: "Login cancelled",
                          icon: Icons.close,
                        );return;
                      }await FirebaseFirestore.instance
                          .collection('test')
                          .add({
                        'status': 'firestore enabled',
                        'uid': user.uid,
                        'timestamp': FieldValue.serverTimestamp(),
                      });
                    } catch (e) {
                      showAnimatedSnackBar(
                        context,
                        message: "Google login failed",
                        icon: Icons.error_outline,
                      );
                    }
                  },


                ),


                const SizedBox(height: 12),

                /// PHONE (with phone icon image)
                _LoginButton(
                  label: "Use mobile number",
                  imageAsset: 'assets/icon/phone.png',
                  background: Colors.white,
                  textColor: Colors.black,
                  border: true,
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const PhoneInputScreen()));
                  },
                ),


                const SizedBox(height: 24),

                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "New to VaultX? ",
                        style: TextStyle(color: Colors.black54),
                      ),
                      GestureDetector(
                        onTap: () {
                          // 👉 Navigate to Signup screen (create later)
                          showAnimatedSnackBar(
                            context,
                            message: "Signup coming soon",
                            icon: Icons.person_add_alt_1,
                          );
                        },
                        child: const Text(
                          "Create an account",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                /// TERMS
                const Text(
                  textAlign: TextAlign.center,
                  "By signing up, you agree to our Terms."
                      "See how we use your data in our Privacy Policy.",

                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ------------------------------------------------
/// LOGIN BUTTON (Reusable)
/// ------------------------------------------------
class _LoginButton extends StatelessWidget {
  final String label;
  final String? imageAsset; // 👈 NEW
  final IconData? icon;
  final Color background;
  final Color textColor;
  final bool border;
  final VoidCallback onTap;

  const _LoginButton({
    required this.label,
    this.imageAsset,
    this.icon,
    required this.background,
    required this.textColor,
    this.border = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: border
                ? const BorderSide(color: Colors.black12)
                : BorderSide.none,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (imageAsset != null)
              Image.asset(
                imageAsset!,
                height: 22,
              )
            else if (icon != null)
              Icon(icon, color: textColor),

            const SizedBox(width: 12),

            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
void _showError(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      content: Text(message),
    ),
  );
}


