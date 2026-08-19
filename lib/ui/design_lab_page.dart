import 'package:flutter/material.dart';

import 'theme/app_tokens.dart';
import 'widgets/app_action_button.dart';
import 'widgets/app_activity_log.dart';
import 'widgets/app_feedback_panel.dart';
import 'widgets/app_field_row.dart';
import 'widgets/app_info_panel.dart';
import 'widgets/app_progress_panel.dart';
import 'widgets/app_sidebar.dart';
import 'widgets/app_status_badge.dart';

class DesignLabPage extends StatefulWidget {
  const DesignLabPage({super.key});

  @override
  State<DesignLabPage> createState() => _DesignLabPageState();
}

class _DesignLabPageState extends State<DesignLabPage> {
  var _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final showSidebar = constraints.maxWidth >= 720;
          return Row(
            children: [
              if (showSidebar)
                AppSidebar(
                  items: const [
                    AppSidebarItem(
                      label: '我的 Mod',
                      icon: Icons.videogame_asset_outlined,
                    ),
                    AppSidebarItem(label: '仓库连接', icon: Icons.hub_outlined),
                    AppSidebarItem(label: '同步记录', icon: Icons.history_outlined),
                    AppSidebarItem(label: '设置', icon: Icons.settings_outlined),
                  ],
                  selectedIndex: _selectedIndex,
                  onSelected: (index) => setState(() => _selectedIndex = index),
                ),
              Expanded(
                child: SafeArea(
                  child: ListView(
                    padding: EdgeInsets.all(
                      showSidebar ? AppSpace.lg : AppSpace.md,
                    ),
                    children: [
                      Text(
                        '组件预览',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: AppSpace.xs),
                      Text(
                        '深色桌面工作台基础组件',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: AppSpace.lg),
                      _Section(
                        title: '状态徽标',
                        child: const Wrap(
                          spacing: AppSpace.xs,
                          runSpacing: AppSpace.xs,
                          children: [
                            AppStatusBadge(
                              label: '连接正常',
                              tone: AppStatusTone.normal,
                            ),
                            AppStatusBadge(
                              label: '同步完成',
                              tone: AppStatusTone.success,
                            ),
                            AppStatusBadge(
                              label: '发现更新',
                              tone: AppStatusTone.warning,
                            ),
                            AppStatusBadge(
                              label: '无法连接仓库',
                              tone: AppStatusTone.error,
                            ),
                          ],
                        ),
                      ),
                      _Section(
                        title: '操作按钮',
                        child: Wrap(
                          spacing: AppSpace.sm,
                          runSpacing: AppSpace.sm,
                          children: [
                            AppActionButton(
                              label: '同步更新',
                              icon: Icons.sync,
                              onPressed: () {},
                            ),
                            AppActionButton(
                              label: '正在同步',
                              isLoading: true,
                              onPressed: () {},
                            ),
                            const AppActionButton(
                              label: '暂不可用',
                              icon: Icons.lock_outline,
                            ),
                            AppActionButton(
                              label: '打开本地仓库目录',
                              icon: Icons.folder_open_outlined,
                              onPressed: () {},
                              style: AppActionButtonStyle.secondary,
                            ),
                          ],
                        ),
                      ),
                      _Section(
                        title: '信息与字段',
                        child: AppInfoPanel(
                          title: '仓库信息',
                          trailing: const AppStatusBadge(
                            label: '已连接',
                            tone: AppStatusTone.success,
                          ),
                          child: Column(
                            children: const [
                              AppFieldRow(
                                label: '仓库地址',
                                child: Text(
                                  'https://github.com/example/a-very-long-repository-name-for-narrow-layout-check.git',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              SizedBox(height: AppSpace.md),
                              AppFieldRow(
                                label: '仓库内 Mod 目录（可选）',
                                helper: '例如：测试/PEAK_mod；留空会同步整个仓库。',
                                child: TextField(
                                  controller: null,
                                  decoration: InputDecoration(
                                    hintText: '测试/PEAK_mod',
                                  ),
                                ),
                              ),
                              SizedBox(height: AppSpace.md),
                              AppFieldRow(
                                label: '本地仓库目录',
                                helper: '请选择本地仓库根目录，应用会保留仓库层级。',
                                child: TextField(
                                  controller: null,
                                  decoration: InputDecoration(
                                    hintText: 'D:\\Games\\Example\\Repository',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      _Section(
                        title: '进度与反馈',
                        child: Column(
                          children: [
                            const AppProgressPanel(
                              title: '同步进度',
                              message: '正在写入更新文件，请不要退出应用。',
                              progress: 0.68,
                              trailingLabel: '68%',
                            ),
                            const SizedBox(height: AppSpace.sm),
                            const AppProgressPanel(
                              title: '准备发布',
                              message: '正在检查本地文件变更。',
                            ),
                            const SizedBox(height: AppSpace.sm),
                            const AppFeedbackPanel(
                              title: '发现可同步更新',
                              message: '作者已发布新的 Mod 内容，请确认后同步。',
                              tone: AppFeedbackTone.warning,
                            ),
                            const SizedBox(height: AppSpace.sm),
                            AppFeedbackPanel(
                              title: '还没有连接 Mod 仓库',
                              message: '连接后即可检查并同步朋友发布的更新。',
                              tone: AppFeedbackTone.empty,
                              actionLabel: '连接并初始化',
                              onAction: () {},
                            ),
                            const SizedBox(height: AppSpace.sm),
                            const AppFeedbackPanel(
                              title: '同步完成',
                              message: 'Mod 文件已更新到最新内容。',
                              tone: AppFeedbackTone.success,
                            ),
                            const SizedBox(height: AppSpace.sm),
                            AppFeedbackPanel(
                              title: '无法连接仓库',
                              message: '请检查地址、网络或访问权限后重试。',
                              tone: AppFeedbackTone.error,
                              actionLabel: '重试',
                              onAction: () {},
                            ),
                          ],
                        ),
                      ),
                      _Section(
                        title: '活动记录',
                        child: const AppActivityLog(
                          entries: [
                            AppActivityEntry(
                              title: '同步完成',
                              detail: '已更新 5 个文件，当前内容已是最新。',
                              time: '今天 15:30',
                              tone: AppStatusTone.success,
                            ),
                            AppActivityEntry(
                              title: '发现更新',
                              detail: '作者发布了新的 Mod 内容。',
                              time: '昨天 20:10',
                              tone: AppStatusTone.warning,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpace.sm),
          child,
        ],
      ),
    );
  }
}
