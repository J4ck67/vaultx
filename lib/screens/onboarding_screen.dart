import 'dart:async';
import 'package:flutter/material.dart';
import 'login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int index = 0;
  Timer? _timer;

  static const amber = Color(0xFFFDD53F);

  final pages = const [
    _OnboardData(
      title: "Store Bills Securely",
      subtitle:
      "Keep all your bills, receipts, and documents safely in one place.",
      icon: Icons.lock_outline,
    ),
    _OnboardData(
      title: "Smart Reminders",
      subtitle:
      "Never miss a payment. Get timely reminders before due dates.",
      icon: Icons.notifications_active_outlined,
    ),
    _OnboardData(
      title: "Scan & Upload",
      subtitle:
      "Scan bills using camera or upload PDFs directly from your phone.",
      icon: Icons.document_scanner_outlined,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _startAutoSlide();
  }

  void _startAutoSlide() {
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (index < pages.length - 1) {
        _controller.nextPage(
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
        );
      } else {
        _timer?.cancel();
      }
    });
  }

  void _finish() {
    _timer?.cancel();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.amber, Colors.white],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [


              /// SKIP
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _finish,
                  child: const Text(
                    "Skip",
                    style: TextStyle(color: Colors.black),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: const [
                      Text(
                        "Vault",
                        style: TextStyle(
                          fontSize: 54,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      Text(
                        "X",
                        style: TextStyle(
                          fontSize: 54,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),



              /// PAGE VIEW
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: pages.length,
                  onPageChanged: (i) => setState(() => index = i),
                  itemBuilder: (_, i) => _AnimatedOnboardPage(
                    data: pages[i],
                    active: index == i,
                  ),
                ),
              ),

              /// INDICATORS
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  pages.length,
                      (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    height: 6,
                    width: index == i ? 26 : 6,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              /// CTA
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _finish,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      index == pages.length - 1
                          ? "Get Started"
                          : "Continue",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

/*──────────────────────────────────────────────*/
/* ANIMATED PAGE */
/*──────────────────────────────────────────────*/

class _AnimatedOnboardPage extends StatelessWidget {
  final _OnboardData data;
  final bool active;

  const _AnimatedOnboardPage({
    required this.data,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 500),
        opacity: active ? 1 : 0,
        child: AnimatedSlide(
          duration: const Duration(milliseconds: 500),
          offset: active ? Offset.zero : const Offset(0, 0.1),
          curve: Curves.easeOutCubic,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                scale: active ? 1 : 0.85,
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOutBack,
                child: Container(
                  height: 110,
                  width: 110,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Icon(
                    data.icon,
                    size: 56,
                    color: Colors.white,
                  ),
                ),
              ),

              const SizedBox(height: 32),

              Text(
                data.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              Text(
                data.subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  color: Colors.black54,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/*──────────────────────────────────────────────*/
/* MODEL */
/*──────────────────────────────────────────────*/

class _OnboardData {
  final String title;
  final String subtitle;
  final IconData icon;

  const _OnboardData({
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}
