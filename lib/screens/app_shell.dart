import 'package:flutter/material.dart';
import 'package:vaultx/screens/profile.dart';
import 'package:vaultx/screens/stats_screen.dart';
import 'package:vaultx/screens/vault_screen.dart';
import '../widgets/bottom_nav.dart';
import 'home_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int index = 0;

  // 🔴 MATCHES THE 4 BUTTONS IN THE NAV BAR
  final pages = const [
    HomeScreen(),
    VaultScreen(),
    StatsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, // Required for the floating glass effect
      backgroundColor: Colors.white,

      body: IndexedStack(
        index: index,
        children: pages,
      ),

      bottomNavigationBar: VaultXBottomNav(
        currentIndex: index,
        // 🔴 NORMAL TAB SWITCHING (No more intercepting)
        onTap: (i) => setState(() => index = i),
      ),
    );
  }
}