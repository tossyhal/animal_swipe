import 'package:flutter/material.dart';
import '../../constants/app_constants.dart';

/// 円形のアクションボタンウィジェット
class ActionButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final IconData icon;
  final Color backgroundColor;
  final String? label;

  const ActionButton({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.backgroundColor,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;

    final button = Semantics(
      button: true,
      enabled: isEnabled,
      label: label,
      child: Material(
        elevation: isEnabled ? AppConstants.elevationMedium : 0,
        color: Colors.transparent,
        shadowColor: backgroundColor.withValues(
          alpha: AppConstants.opacityVeryLow,
        ),
        borderRadius: BorderRadius.circular(AppConstants.buttonRadius),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppConstants.buttonRadius),
          child: Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: isEnabled ? backgroundColor : Colors.grey.shade400,
              shape: BoxShape.circle,
              boxShadow: isEnabled
                  ? [
                      BoxShadow(
                        color: backgroundColor.withValues(
                          alpha: AppConstants.opacityLow,
                        ),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
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
      ),
    );

    return label == null ? button : Tooltip(message: label!, child: button);
  }
}
