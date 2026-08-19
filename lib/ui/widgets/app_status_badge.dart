import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

enum AppStatusTone { normal, success, warning, error }

class AppStatusBadge extends StatelessWidget {
  const AppStatusBadge({super.key, required this.label, required this.tone});

  final String label;
  final AppStatusTone tone;

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      AppStatusTone.normal => AppColors.primary,
      AppStatusTone.success => AppColors.success,
      AppStatusTone.warning => AppColors.warning,
      AppStatusTone.error => AppColors.danger,
    };

    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.xs,
        vertical: AppSpace.xxs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: AppRadii.medium,
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, color: color, size: 7),
          const SizedBox(width: AppSpace.xs),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
