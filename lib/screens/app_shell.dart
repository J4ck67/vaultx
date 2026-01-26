import 'package:flutter/material.dart';
import 'package:vaultx/screens/document_preview_screen.dart';
import 'package:vaultx/screens/profile.dart';
import '../widgets/bottom_nav.dart';
import 'home_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int index = 0;

  final pages = const [
    HomeScreen(),
    Center(child: Text("Vault")),
    Center(child: Text("Scan")),
    Center(child: Text("Activity")),
    ProfileScreen(),
    Center(child: Text("Profile")),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: pages[index],
      bottomNavigationBar: VaultXBottomNav(
        currentIndex: index,
        onTap: (i) => setState(() => index = i),
      ),
    );
  }
}
