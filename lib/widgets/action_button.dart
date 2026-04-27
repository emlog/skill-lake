import 'package:flutter/material.dart';

/// 一个精致的小型操作按钮，具有圆角背景和悬停效果。
/// 常用于顶部操作栏或卡片中的辅助操作。
class ActionButton extends StatelessWidget {
  const ActionButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.isDanger = false,
    this.isDisabled = false,
    this.size = 36,
    this.iconSize = 18,
    this.borderRadius = 10,
    this.iconColor,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool isDanger;
  final bool isDisabled;
  final double size;
  final double iconSize;
  final double borderRadius;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final ColorScheme color = Theme.of(context).colorScheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final Color bgColor = isDisabled
        ? (isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.05))
        : (isDark
            ? Colors.white.withValues(alpha: 0.08)
            : color.surfaceContainerLow);

    final Color effectiveIconColor = isDisabled
        ? color.onSurface.withValues(alpha: 0.3)
        : (iconColor ?? (isDanger ? color.error : color.onSurfaceVariant));

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: IconButton(
        onPressed: isDisabled ? null : onPressed,
        tooltip: tooltip,
        iconSize: iconSize,
        padding: EdgeInsets.zero,
        splashRadius: size / 2,
        icon: Icon(
          icon,
          color: effectiveIconColor,
        ),
      ),
    );
  }
}
