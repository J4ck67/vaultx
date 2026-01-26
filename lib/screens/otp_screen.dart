import 'package:flutter/material.dart';
import 'package:country_code_picker/country_code_picker.dart';
import '../services/auth_service.dart';
import 'otp_verify_screen.dart';

class PhoneInputScreen extends StatefulWidget {
  const PhoneInputScreen({super.key});

  @override
  State<PhoneInputScreen> createState() => _PhoneInputScreenState();
}

class _PhoneInputScreenState extends State<PhoneInputScreen> {
  final phoneController = TextEditingController();
  String dialCode = '+91';
  bool loading = false;

  @override
  void dispose() {
    phoneController.dispose();
    super.dispose();
  }

  /*──────────────── SEND OTP ────────────────*/
  Future<void> _goToOtp() async {
    if (phoneController.text.trim().isEmpty) {
      _snack("Please enter your mobile number");
      return;
    }

    final phone = '$dialCode${phoneController.text.trim()}';
    setState(() => loading = true);

    await AuthService.instance.sendOtp(
      phoneNumber: phone,

      onCodeSent: (verificationId) {
        setState(() => loading = false);

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OtpVerifyScreen(
              phoneNumber: phone,
            ),
          ),
        );
      },

      onError: (error) {
        setState(() => loading = false);
        _snack(error);
      },
    );
  }

  /*──────────────── SNACKBAR ────────────────*/
  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
  }

  /*──────────────── UI ────────────────*/
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Color(0xFFFDD53F)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                ),

                const SizedBox(height: 20),

                Row(
                  children: const [
                    Text(
                      "Vault",
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber,
                      ),
                    ),
                    Text(
                      "X",
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                const Text(
                  "Can we get your number?",
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                const Text(
                  "We’ll send you a one-time password to verify.",
                  style: TextStyle(color: Colors.black54),
                ),

                const SizedBox(height: 32),

                Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.black),
                      ),
                      child: CountryCodePicker(
                        initialSelection: 'IN',
                        favorite: const ['+91', 'IN'],
                        onChanged: (c) =>
                        dialCode = c.dialCode ?? '+91',
                      ),
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child: TextField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          hintText: "Mobile number",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const Spacer(),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        "We never share your number.\nBy continuing, you agree to our policies.",
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                    GestureDetector(
                      onTap: loading ? null : _goToOtp,
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: const BoxDecoration(
                          color: Colors.black,
                          shape: BoxShape.circle,
                        ),
                        child: loading
                            ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                            : const Icon(
                          Icons.arrow_forward,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
