import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

class AppFieldRow extends StatelessWidget {
  const AppFieldRow({
    super.key,
    required this.label,
    required this.child,
    this.helper,
  });

  final String label;
  final Widget child;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 520;
        final labelWidget = SizedBox(
          width: isCompact ? null : 104,
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        );
        final field = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            child,
            if (helper != null) ...[
              const SizedBox(height: AppSpace.xxs),
              Text(helper!, style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        );
        return isCompact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [labelWidget, const SizedBox(height: AppSpace.xs), field],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [labelWidget, const SizedBox(width: AppSpace.sm), Expanded(child: field)],
              );
      },
    );
  }
}
