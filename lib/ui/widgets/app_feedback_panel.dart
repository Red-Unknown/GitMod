import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'app_action_button.dart';
import 'app_info_panel.dart';

enum AppFeedbackTone { empty, success, warning, error }

class AppFeedbackPanel extends StatelessWidget {
  const AppFeedbackPanel({
    super.key,
    required this.title,
    required this.message,
    required this.tone,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final AppFeedbackTone tone;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (tone) {
      AppFeedbackTone.empty => (Icons.inbox_outlined, AppColors.textSecondary),
      AppFeedbackTone.success => (Icons.check_circle_outline, AppColors.success),
      AppFeedbackTone.warning => (Icons.warning_amber_rounded, AppColors.warning),
      AppFeedbackTone.error => (Icons.error_outline, AppColors.danger),
    };
    return AppInfoPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: AppSpace.sm),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpace.xxs),
          Text(message, style: Theme.of(context).textTheme.bodySmall),
          if (actionLabel != null) ...[
            const SizedBox(height: AppSpace.md),
            AppActionButton(
              label: actionLabel!,
              icon: Icons.refresh,
              onPressed: onAction,
              style: AppActionButtonStyle.secondary,
            ),
          ],
        ],
      ),
    );
  }
}
