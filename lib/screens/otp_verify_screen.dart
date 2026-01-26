import 'dart:async';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class OtpVerifyScreen extends StatefulWidget {
  final String phoneNumber;

  const OtpVerifyScreen({
    super.key,
    required this.phoneNumber,
  });

  @override
  State<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends State<OtpVerifyScreen>
    with SingleTickerProviderStateMixin {
  final List<TextEditingController> _controllers =
  List.generate(6, (_) => TextEditingController());

  final List<FocusNode> _focusNodes =
  List.generate(6, (_) => FocusNode());

  /*──────── SHAKE ANIMATION ────────*/
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  /*──────── RESEND TIMER ────────*/
  static const int _cooldown = 60;
  int _secondsLeft = _cooldown;
  Timer? _timer;

  bool loading = false;

  @override
  void initState() {
    super.initState();

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -10), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10, end: 10), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10, end: -6), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -6, end: 6), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 6, end: 0), weight: 1),
    ]).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut),
    );

    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _shakeController.dispose();
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    super.dispose();
  }

  /*──────── TIMER ────────*/
  void _startTimer() {
    _secondsLeft = _cooldown;
    _timer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft == 0) {
        t.cancel();
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  /*──────── VERIFY OTP ────────*/
  Future<void> _verifyOtp() async {
    final otp = _controllers.map((e) => e.text).join();

    if (otp.length != 6) {
      _shakeController.forward(from: 0);
      _snack("Invalid OTP");
      return;
    }

    setState(() => loading = true);

    try {
      await AuthService.instance.verifyOtp(smsCode: otp);

      if (!mounted) return;
      Navigator.popUntil(context, (r) => r.isFirst);
    } catch (e) {
      _shakeController.forward(from: 0);
      _snack("OTP verification failed");
    } finally {
      setState(() => loading = false);
    }
  }

  /*──────── RESEND OTP ────────*/
  Future<void> _resendOtp() async {
    if (_secondsLeft > 0) return;

    _startTimer();

    await AuthService.instance.sendOtp(
      phoneNumber: widget.phoneNumber,
      onCodeSent: (_) {},
      onError: (e) => _snack(e),
    );
  }

  /*──────── UI HELPERS ────────*/
  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.black,
          content: Text(msg, style: const TextStyle(color: Colors.white)),
        ),
      );
  }

  Widget _otpBox(int i) {
    return SizedBox(
      width: 48,
      child: TextField(
        controller: _controllers[i],
        focusNode: _focusNodes[i],
        keyboardType: TextInputType.number,
        maxLength: 1,
        textAlign: TextAlign.center,
        decoration: const InputDecoration(counterText: ""),
        onChanged: (v) {
          if (v.isNotEmpty && i < 5) {
            _focusNodes[i + 1].requestFocus();
          } else if (v.isEmpty && i > 0) {
            _focusNodes[i - 1].requestFocus();
          }
        },
      ),
    );
  }

  /*──────── BUILD ────────*/
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
              ),
              const SizedBox(height: 20),
              const Text(
                "Enter OTP",
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text("Sent to ${widget.phoneNumber}"),
              const SizedBox(height: 32),

              AnimatedBuilder(
                animation: _shakeAnimation,
                builder: (_, child) => Transform.translate(
                  offset: Offset(_shakeAnimation.value, 0),
                  child: child,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(6, _otpBox),
                ),
              ),

              const Spacer(),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: _secondsLeft == 0 ? _resendOtp : null,
                    child: Text(
                      _secondsLeft == 0
                          ? "Resend OTP"
                          : "Resend in $_secondsLeft s",
                      style: TextStyle(
                        fontSize: 12,
                        color: _secondsLeft == 0
                            ? Colors.black
                            : Colors.black45,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: loading ? null : _verifyOtp,
                    child: CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.black,
                      child: loading
                          ? const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      )
                          : const Icon(Icons.arrow_forward,
                          color: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
