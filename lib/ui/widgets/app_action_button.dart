import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

enum AppActionButtonStyle { primary, secondary }

class AppActionButton extends StatelessWidget {
  const AppActionButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.style = AppActionButtonStyle.primary,
    this.isLoading = false,
    this.expand = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final AppActionButtonStyle style;
  final bool isLoading;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isLoading;
    final foreground = style == AppActionButtonStyle.primary
        ? AppColors.textPrimary
        : AppColors.textPrimary;
    final background = style == AppActionButtonStyle.primary
        ? AppColors.primary
        : AppColors.surfaceMuted;

    final button = TextButton.icon(
      onPressed: enabled ? onPressed : null,
      icon: isLoading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : icon == null
              ? const SizedBox.shrink()
              : Icon(icon, size: 18),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      style: TextButton.styleFrom(
        foregroundColor: foreground,
        backgroundColor: background,
        disabledForegroundColor: AppColors.textSecondary,
        disabledBackgroundColor: AppColors.surfaceMuted.withValues(alpha: 0.55),
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.medium),
        side: style == AppActionButtonStyle.secondary
            ? const BorderSide(color: AppColors.border)
            : BorderSide.none,
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}
