import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 144});

  final double size;

  @override
  Widget build(BuildContext context) => Center(
    child: ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.18),
      child: Image.asset(
        'assets/branding/logo.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        semanticLabel: 'REISUB Meeting',
      ),
    ),
  );
}
