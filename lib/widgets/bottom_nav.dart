import 'dart:ui';
import 'package:flutter/material.dart';

class VaultXBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const VaultXBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  // 🔴 REMOVED THE "ADD" BUTTON. NOW IT HAS 5 ITEMS.
  static const _items = [
    _NavItem(Icons.home_rounded, "Home"),
    _NavItem(Icons.folder_rounded, "Vault"),
    _NavItem(Icons.health_and_safety_rounded, "Policy"),
    _NavItem(Icons.bar_chart_rounded, "Stats"),
    _NavItem(Icons.person_rounded, "Profile"),
  ];

  static const amber = Color(0xFFFDD53F);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xE61C1C1E),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 0.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(_items.length, (index) {
                final selected = index == currentIndex;
                final itemColor = selected ? amber : Colors.white54;

                return Expanded(
                  child: GestureDetector(
                    onTap: () => onTap(index),
                    behavior: HitTestBehavior.opaque,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutCubic,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: selected ? amber.withOpacity(0.15) : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: AnimatedScale(
                            scale: selected ? 1.15 : 1.0,
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOutBack,
                            child: Icon(
                              _items[index].icon,
                              size: 26,
                              color: itemColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                            color: itemColor,
                          ),
                          child: Text(_items[index].label),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;

  const _NavItem(this.icon, this.label);
}