import 'package:flutter/material.dart';

class VaultXBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const VaultXBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const _items = [
    _NavItem(Icons.home_rounded, "Home"),
    _NavItem(Icons.folder_rounded, "Vault"),
    _NavItem(Icons.add_circle_outline, "Add"),
    _NavItem(Icons.bar_chart_rounded, "Stats"),
    _NavItem(Icons.person_rounded, "Profile"),
  ];

  static const amber = Color(0xFFFDD53F);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(_items.length, (index) {
          final selected = index == currentIndex;

          return Expanded(
            child: InkWell(
              onTap: () => onTap(index),
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedScale(
                    scale: selected ? 1.15 : 1.0,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutBack,
                    child: Icon(
                      _items[index].icon,
                      size: 26,
                      color: selected ? Colors.black : Colors.black45,
                    ),
                  ),

                  const SizedBox(height: 4),

                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight:
                      selected ? FontWeight.w600 : FontWeight.w500,
                      color:
                      selected ? Colors.black : Colors.black45,
                    ),
                    child: Text(_items[index].label),
                  ),

                  const SizedBox(height: 6),

                  /// Animated indicator (WhatsApp style)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    height: 3,
                    width: selected ? 22 : 0,
                    decoration: BoxDecoration(
                      color: amber,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

/*──────────────── NAV ITEM MODEL ────────────────*/

class _NavItem {
  final IconData icon;
  final String label;

  const _NavItem(this.icon, this.label);
}
