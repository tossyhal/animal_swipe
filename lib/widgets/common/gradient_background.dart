import 'package:flutter/material.dart';

/// グラデーション背景ウィジェット
class GradientBackground extends StatelessWidget {
  final Widget child;

  const GradientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primary,
            Color.lerp(
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.secondary,
              0.28,
            )!,
          ],
        ),
      ),
      child: child,
    );
  }
}
