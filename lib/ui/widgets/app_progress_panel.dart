import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'app_info_panel.dart';

class AppProgressPanel extends StatelessWidget {
  const AppProgressPanel({
    super.key,
    required this.title,
    required this.message,
    this.progress,
    this.trailingLabel,
  });

  final String title;
  final String message;
  final double? progress;
  final String? trailingLabel;

  @override
  Widget build(BuildContext context) {
    final double? value = progress == null
        ? null
        : progress!.clamp(0.0, 1.0).toDouble();
    return AppInfoPanel(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: AppSpace.sm),
          Row(
            children: [
              Expanded(child: LinearProgressIndicator(value: value)),
              if (trailingLabel != null) ...[
                const SizedBox(width: AppSpace.sm),
                Text(trailingLabel!, style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
