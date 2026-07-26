import 'package:flutter/material.dart';
import '../../constants/app_constants.dart';
import '../../theme/theme_extensions.dart';

/// 円形のアクションボタンウィジェット
class ActionButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final IconData icon;
  final Color backgroundColor;

  /// [backgroundColor] の上に載せるアイコンの色。
  /// 呼び出し側が `onError` / `onSecondary` などのセマンティックな色を渡す
  final Color foregroundColor;
  final String? label;

  const ActionButton({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;
    final colors = context.colors;

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
              // 無効時は M3 の disabled トークン（onSurface 12% / 38%）に合わせる
              color: isEnabled
                  ? backgroundColor
                  : colors.onSurface.withValues(alpha: 0.12),
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
              color: isEnabled
                  ? foregroundColor
                  : colors.onSurface.withValues(alpha: 0.38),
              size: AppConstants.iconSizeMedium,
            ),
          ),
        ),
      ),
    );

    return label == null ? button : Tooltip(message: label!, child: button);
  }
}
