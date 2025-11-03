import 'package:flutter/material.dart';
import '../../constants/app_constants.dart';

/// 円形のアクションボタンウィジェット
class ActionButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final IconData icon;
  final Color backgroundColor;

  const ActionButton({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;

    return Material(
      elevation: isEnabled ? AppConstants.elevationMedium : 0,
      color: Colors.transparent,
      shadowColor: backgroundColor.withValues(alpha: AppConstants.opacityVeryLow),
      borderRadius: BorderRadius.circular(AppConstants.buttonRadius),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppConstants.buttonRadius),
        child: Container(
          width: AppConstants.buttonHeight,
          height: AppConstants.buttonHeight,
          decoration: BoxDecoration(
            color: isEnabled ? backgroundColor : Colors.grey.shade300,
            shape: BoxShape.circle,
            boxShadow: isEnabled
                ? [
                    BoxShadow(
                      color: backgroundColor
                          .withValues(alpha: AppConstants.opacityLow),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: AppConstants.iconSizeMedium,
          ),
        ),
      ),
    );
  }
}
