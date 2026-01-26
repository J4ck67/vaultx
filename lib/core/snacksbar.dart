import 'package:flutter/material.dart';

void showAnimatedSnackBar(
    BuildContext context, {
      required String message,
      IconData icon = Icons.info_outline,
    }) {
  final snackBar = SnackBar(
    behavior: SnackBarBehavior.floating,
    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    backgroundColor: Colors.black,
    elevation: 10,
    duration: const Duration(milliseconds: 1800),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
    content: Row(
      children: [
        Icon(icon, color: Colors.white),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ],
    ),
    animation: CurvedAnimation(
      parent: kAlwaysCompleteAnimation,
      curve: Curves.easeOutCubic,
    ),
  );

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(snackBar);
}
