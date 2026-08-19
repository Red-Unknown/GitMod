import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'app_info_panel.dart';
import 'app_status_badge.dart';

class AppActivityEntry {
  const AppActivityEntry({
    required this.title,
    required this.detail,
    required this.time,
    required this.tone,
  });

  final String title;
  final String detail;
  final String time;
  final AppStatusTone tone;
}

class AppActivityLog extends StatelessWidget {
  const AppActivityLog({super.key, required this.entries, this.title = '最近活动'});

  final String title;
  final List<AppActivityEntry> entries;

  @override
  Widget build(BuildContext context) {
    return AppInfoPanel(
      title: title,
      child: entries.isEmpty
          ? Text('还没有操作记录', style: Theme.of(context).textTheme.bodySmall)
          : ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: entries.length,
              separatorBuilder: (_, _) => const Divider(height: AppSpace.lg),
              itemBuilder: (context, index) {
                final entry = entries[index];
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppStatusBadge(label: entry.title, tone: entry.tone),
                    const SizedBox(width: AppSpace.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(entry.detail, style: Theme.of(context).textTheme.bodySmall),
                          const SizedBox(height: AppSpace.xxs),
                          Text(entry.time, style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}
