import 'package:flutter/material.dart';
import '../../constants/app_constants.dart';

/// グラデーション背景ウィジェット
class GradientBackground extends StatelessWidget {
  final Widget child;

  const GradientBackground({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Theme.of(context)
                .colorScheme
                .primary
                .withValues(alpha: AppConstants.opacityMedium),
            Theme.of(context).colorScheme.primaryContainer,
          ],
        ),
      ),
      child: child,
    );
  }
}
