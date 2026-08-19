import 'package:flutter/material.dart';

import '../controllers/git_mod_controller.dart';
import '../models/activity_item.dart';
import '../models/mod_config.dart';
import 'theme/app_theme.dart';
import 'theme/app_tokens.dart';
import 'widgets/app_action_button.dart';
import 'widgets/app_activity_log.dart';
import 'widgets/app_feedback_panel.dart';
import 'widgets/app_field_row.dart';
import 'widgets/app_info_panel.dart';
import 'widgets/app_progress_panel.dart';
import 'widgets/app_sidebar.dart';
import 'widgets/app_status_badge.dart';

class GitModApp extends StatelessWidget {
  const GitModApp({super.key, required this.controller});

  final GitModController controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GitMod',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: GitModWorkbench(controller: controller),
    );
  }
}

class GitModWorkbench extends StatefulWidget {
  const GitModWorkbench({super.key, required this.controller});

  final GitModController controller;

  @override
  State<GitModWorkbench> createState() => _GitModWorkbenchState();
}

class _GitModWorkbenchState extends State<GitModWorkbench> {
  var _pageIndex = 0;
  final _publishMessageController = TextEditingController();

  @override
  void dispose() {
    _publishMessageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;
        final isFirstSetup = controller.snapshot == null;
        return LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 760;
            final content = _buildPage(controller, isFirstSetup);
            return Scaffold(
              body: SafeArea(
                child: Column(
                  children: [
                    if (compact)
                      _CompactHeader(
                        onOpenConnection: () => setState(() => _pageIndex = 1),
                      ),
                    Expanded(
                      child: Row(
                        children: [
                          if (!compact)
                            AppSidebar(
                              title: controller.role == ModRole.creator
                                  ? '作者工作台'
                                  : '玩家工作台',
                              items: const [
                                AppSidebarItem(
                                  label: '我的 Mod',
                                  icon: Icons.videogame_asset_outlined,
                                ),
                                AppSidebarItem(
                                  label: '仓库连接',
                                  icon: Icons.hub_outlined,
                                ),
                                AppSidebarItem(
                                  label: '活动记录',
                                  icon: Icons.history_outlined,
                                ),
                                AppSidebarItem(
                                  label: '设置',
                                  icon: Icons.settings_outlined,
                                ),
                              ],
                              selectedIndex: _pageIndex,
                              onSelected: (value) =>
                                  setState(() => _pageIndex = value),
                            ),
                          Expanded(
                            child: ListView(
                              padding: EdgeInsets.all(
                                compact ? AppSpace.md : AppSpace.lg,
                              ),
                              children: [
                                if (controller.busy) ...[
                                  AppProgressPanel(
                                    title: controller.operationStage.label,
                                    message: controller.status,
                                  ),
                                  const SizedBox(height: AppSpace.md),
                                ],
                                content,
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (compact)
                      NavigationBar(
                        selectedIndex: _pageIndex,
                        onDestinationSelected: (value) =>
                            setState(() => _pageIndex = value),
                        destinations: const [
                          NavigationDestination(
                            icon: Icon(Icons.videogame_asset_outlined),
                            label: '我的 Mod',
                          ),
                          NavigationDestination(
                            icon: Icon(Icons.hub_outlined),
                            label: '连接',
                          ),
                          NavigationDestination(
                            icon: Icon(Icons.history_outlined),
                            label: '记录',
                          ),
                          NavigationDestination(
                            icon: Icon(Icons.settings_outlined),
                            label: '设置',
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPage(GitModController controller, bool isFirstSetup) {
    if (_pageIndex == 1 || (isFirstSetup && _pageIndex == 0)) {
      return _ConnectionPage(controller: controller);
    }
    return switch (_pageIndex) {
      0 => _DashboardPage(
        controller: controller,
        publishMessageController: _publishMessageController,
      ),
      2 => _ActivityPage(controller: controller),
      _ => _SettingsPage(controller: controller),
    };
  }
}

class _CompactHeader extends StatelessWidget {
  const _CompactHeader({required this.onOpenConnection});

  final VoidCallback onOpenConnection;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.md,
        AppSpace.sm,
        AppSpace.md,
        0,
      ),
      child: Row(
        children: [
          const Icon(Icons.sports_esports, color: AppColors.primary),
          const SizedBox(width: AppSpace.xs),
          Text('GitMod', style: Theme.of(context).textTheme.titleLarge),
          const Spacer(),
          IconButton(
            tooltip: '仓库连接',
            onPressed: onOpenConnection,
            icon: const Icon(Icons.hub_outlined),
          ),
        ],
      ),
    );
  }
}

class _PageTitle extends StatelessWidget {
  const _PageTitle({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: AppSpace.xxs),
          Text(description, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _ConnectionPage extends StatefulWidget {
  const _ConnectionPage({required this.controller});

  final GitModController controller;

  @override
  State<_ConnectionPage> createState() => _ConnectionPageState();
}

class _ConnectionPageState extends State<_ConnectionPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _repositoryController;
  late final TextEditingController _repositorySubdirectoryController;
  late final TextEditingController _directoryController;
  late String _lastName;
  late String _lastRepository;
  late String _lastRepositorySubdirectory;
  late String _lastDirectory;

  GitModController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _lastName = controller.name;
    _lastRepository = controller.repositoryUrl;
    _lastRepositorySubdirectory = controller.repositorySubdirectory;
    _lastDirectory = controller.directory;
    _nameController = TextEditingController(text: _lastName);
    _repositoryController = TextEditingController(text: _lastRepository);
    _repositorySubdirectoryController = TextEditingController(
      text: _lastRepositorySubdirectory,
    );
    _directoryController = TextEditingController(text: _lastDirectory);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _repositoryController.dispose();
    _repositorySubdirectoryController.dispose();
    _directoryController.dispose();
    super.dispose();
  }

  void _syncFields() {
    _syncField(
      _nameController,
      _lastName,
      controller.name,
      (value) => _lastName = value,
    );
    _syncField(
      _repositoryController,
      _lastRepository,
      controller.repositoryUrl,
      (value) => _lastRepository = value,
    );
    _syncField(
      _repositorySubdirectoryController,
      _lastRepositorySubdirectory,
      controller.repositorySubdirectory,
      (value) => _lastRepositorySubdirectory = value,
    );
    _syncField(
      _directoryController,
      _lastDirectory,
      controller.directory,
      (value) => _lastDirectory = value,
    );
  }

  void _syncField(
    TextEditingController field,
    String lastValue,
    String currentValue,
    ValueChanged<String> remember,
  ) {
    if (lastValue == currentValue || field.text == currentValue) return;
    field.value = field.value.copyWith(
      text: currentValue,
      selection: TextSelection.collapsed(offset: currentValue.length),
      composing: TextRange.empty,
    );
    remember(currentValue);
  }

  Future<void> _selectRole(ModRole role) async {
    if (controller.busy || controller.role == role) return;
    await controller.setRole(role);
    await controller.setName('');
    await controller.setRepositoryUrl('');
    await controller.setRepositorySubdirectory('');
    await controller.setDirectory('');
  }

  @override
  Widget build(BuildContext context) {
    _syncFields();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _PageTitle(title: '连接仓库', description: '连接本地仓库目录和已有仓库。'),
        AppInfoPanel(
          title: '使用方式',
          child: Wrap(
            spacing: AppSpace.sm,
            runSpacing: AppSpace.sm,
            children: [
              ChoiceChip(
                label: const Text('我是作者'),
                selected: controller.role == ModRole.creator,
                onSelected: controller.busy
                    ? null
                    : (_) => _selectRole(ModRole.creator),
              ),
              ChoiceChip(
                label: const Text('我是玩家'),
                selected: controller.role == ModRole.player,
                onSelected: controller.busy
                    ? null
                    : (_) => _selectRole(ModRole.player),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.md),
        AppInfoPanel(
          title: controller.role == ModRole.creator ? '发布来源' : '安装位置',
          child: Column(
            children: [
              AppFieldRow(
                label: 'Mod 名称',
                child: TextFormField(
                  controller: _nameController,
                  enabled: !controller.busy,
                  onChanged: (value) {
                    _lastName = value;
                    controller.setName(value);
                  },
                  decoration: const InputDecoration(hintText: '例如：朋友联机 Mod'),
                ),
              ),
              const SizedBox(height: AppSpace.md),
              AppFieldRow(
                label: '仓库地址',
                helper: '使用已有的 GitHub 或其他 Git 远端地址。',
                child: TextFormField(
                  controller: _repositoryController,
                  enabled: !controller.busy,
                  onChanged: (value) {
                    _lastRepository = value;
                    controller.setRepositoryUrl(value);
                  },
                  decoration: const InputDecoration(
                    hintText: 'https://github.com/用户名/mod.git',
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.md),
              AppFieldRow(
                label: '仓库内 Mod 目录（可选）',
                helper: '例如：测试/PEAK_mod；留空会同步整个仓库。',
                child: TextFormField(
                  controller: _repositorySubdirectoryController,
                  enabled: !controller.busy,
                  onChanged: (value) {
                    _lastRepositorySubdirectory = value;
                    controller.setRepositorySubdirectory(value);
                  },
                  decoration: const InputDecoration(hintText: '测试/PEAK_mod'),
                ),
              ),
              const SizedBox(height: AppSpace.md),
              AppFieldRow(
                label: '本地仓库目录',
                helper: controller.role == ModRole.creator
                    ? '请选择作者本地的仓库根目录。'
                    : '请选择空目录或不存在的本地仓库目录，应用会保留仓库层级。',
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _directoryController,
                        enabled: !controller.busy,
                        onChanged: (value) {
                          _lastDirectory = value;
                          controller.setDirectory(value);
                        },
                        decoration: const InputDecoration(
                          hintText: 'D:\\Games\\Example\\Repository',
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpace.xs),
                    IconButton(
                      tooltip: '选择本地仓库目录',
                      onPressed: controller.busy
                          ? null
                          : controller.pickDirectory,
                      icon: const Icon(Icons.folder_open_outlined),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpace.lg),
              Align(
                alignment: Alignment.centerRight,
                child: AppActionButton(
                  label: '连接并初始化',
                  icon: Icons.link,
                  isLoading: controller.busy,
                  onPressed: controller.busy ? null : controller.connect,
                ),
              ),
            ],
          ),
        ),
        if (controller.error != null) ...[
          const SizedBox(height: AppSpace.md),
          _ErrorPanel(controller: controller),
        ],
      ],
    );
  }
}

class _DashboardPage extends StatelessWidget {
  const _DashboardPage({
    required this.controller,
    required this.publishMessageController,
  });

  final GitModController controller;
  final TextEditingController publishMessageController;

  @override
  Widget build(BuildContext context) {
    final snapshot = controller.snapshot;
    if (snapshot == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PageTitle(title: '我的 Mod', description: '查看连接状态并完成下一步操作。'),
          AppFeedbackPanel(
            title: controller.error == null ? '尚未连接 Mod 仓库' : '当前无法继续',
            message: controller.status,
            tone: controller.error == null
                ? AppFeedbackTone.empty
                : AppFeedbackTone.error,
            actionLabel: controller.error == null ? '连接仓库' : '重试',
            onAction: controller.error == null ? null : controller.retry,
          ),
        ],
      );
    }
    final statusTone = controller.error != null
        ? AppStatusTone.error
        : snapshot.hasLocalChanges || snapshot.hasUpdates
        ? AppStatusTone.warning
        : AppStatusTone.success;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PageTitle(
          title: controller.name,
          description: controller.role == ModRole.creator
              ? '发布 Mod 更新给玩家。'
              : '同步作者发布的 Mod 更新。',
        ),
        AppInfoPanel(
          title: '当前状态',
          trailing: AppStatusBadge(label: controller.status, tone: statusTone),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('当前内容', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpace.xs),
              Text(
                snapshot.localVersion,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpace.sm),
              Text(
                controller.modDirectory,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.md),
        if (controller.role == ModRole.creator)
          _CreatorActions(
            controller: controller,
            messageController: publishMessageController,
          )
        else
          _PlayerActions(controller: controller),
        if (controller.error != null) ...[
          const SizedBox(height: AppSpace.md),
          _ErrorPanel(controller: controller),
        ],
      ],
    );
  }
}

class _CreatorActions extends StatelessWidget {
  const _CreatorActions({
    required this.controller,
    required this.messageController,
  });

  final GitModController controller;
  final TextEditingController messageController;

  @override
  Widget build(BuildContext context) {
    final snapshot = controller.snapshot!;
    return AppInfoPanel(
      title: snapshot.hasLocalChanges ? '待发布改动' : '发布更新',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            snapshot.hasLocalChanges
                ? '检测到 ${snapshot.changedFileCount} 个本地改动。'
                : '目前没有待发布的文件改动。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (snapshot.hasLocalChanges) ...[
            const SizedBox(height: AppSpace.sm),
            _FileList(files: snapshot.localChangedFiles),
            const SizedBox(height: AppSpace.md),
            TextField(
              controller: messageController,
              enabled: !controller.busy,
              maxLength: 120,
              decoration: const InputDecoration(
                labelText: '本次更新说明',
                hintText: '例如：修复 Boss 阶段异常',
              ),
            ),
            const SizedBox(height: AppSpace.sm),
            Align(
              alignment: Alignment.centerRight,
              child: AppActionButton(
                label: '发布更新',
                icon: Icons.publish_outlined,
                isLoading: controller.busy,
                onPressed: controller.busy
                    ? null
                    : () => controller.publish(messageController.text),
              ),
            ),
          ] else
            const SizedBox(height: AppSpace.sm),
          if (!snapshot.hasLocalChanges)
            AppActionButton(
              label: '检查改动',
              icon: Icons.refresh,
              style: AppActionButtonStyle.secondary,
              onPressed: controller.busy ? null : controller.refresh,
            ),
        ],
      ),
    );
  }
}

class _PlayerActions extends StatelessWidget {
  const _PlayerActions({required this.controller});

  final GitModController controller;

  @override
  Widget build(BuildContext context) {
    final snapshot = controller.snapshot!;
    if (snapshot.hasLocalChanges) {
      return AppFeedbackPanel(
        title: '检测到本地改动',
        message: '为保护你的文件，已暂停同步。请先处理本地改动。',
        tone: AppFeedbackTone.warning,
      );
    }
    if (snapshot.hasUpdates) {
      return AppInfoPanel(
        title: '发现可同步更新',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              snapshot.remoteUpdateMessage ?? '作者发布了新的 Mod 内容。',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpace.sm),
            _FileList(files: snapshot.pendingUpdateFiles),
            const SizedBox(height: AppSpace.md),
            Align(
              alignment: Alignment.centerRight,
              child: AppActionButton(
                label: '同步更新',
                icon: Icons.sync,
                isLoading: controller.busy,
                onPressed: controller.busy ? null : controller.sync,
              ),
            ),
          ],
        ),
      );
    }
    return AppFeedbackPanel(
      title: '已是最新状态',
      message: '当前 Mod 内容已经和作者发布的版本一致。',
      tone: AppFeedbackTone.success,
      actionLabel: '检查更新',
      onAction: controller.busy ? null : controller.refresh,
    );
  }
}

class _FileList extends StatelessWidget {
  const _FileList({required this.files});

  final List<String> files;

  @override
  Widget build(BuildContext context) {
    if (files.isEmpty) {
      return Text('没有可显示的文件。', style: Theme.of(context).textTheme.bodySmall);
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 152),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: files.length,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpace.xxs),
          child: Text(
            files[index],
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.controller});

  final GitModController controller;

  @override
  Widget build(BuildContext context) {
    return AppFeedbackPanel(
      title: '操作未完成',
      message: controller.error!,
      tone: AppFeedbackTone.error,
      actionLabel: '重试',
      onAction: controller.busy ? null : controller.retry,
    );
  }
}

class _ActivityPage extends StatelessWidget {
  const _ActivityPage({required this.controller});

  final GitModController controller;

  @override
  Widget build(BuildContext context) {
    final entries = controller.activity
        .map(_activityEntry)
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _PageTitle(title: '活动记录', description: '查看本次运行期间的发布和同步结果。'),
        AppActivityLog(entries: entries),
      ],
    );
  }

  AppActivityEntry _activityEntry(ActivityItem item) {
    final time = item.occurredAt;
    return AppActivityEntry(
      title: item.title,
      detail: item.detail,
      time:
          '${time.month}月${time.day}日 ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
      tone: item.success ? AppStatusTone.success : AppStatusTone.error,
    );
  }
}

class _SettingsPage extends StatelessWidget {
  const _SettingsPage({required this.controller});

  final GitModController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _PageTitle(title: '设置', description: '管理当前设备上的 Mod 连接信息。'),
        AppInfoPanel(
          title: '当前配置',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                controller.repositoryUrl.isEmpty
                    ? '尚未连接仓库'
                    : controller.repositoryUrl,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpace.xs),
              Text(
                controller.repositorySubdirectory.isEmpty
                    ? '仓库内 Mod 目录：整个仓库'
                    : '仓库内 Mod 目录：${controller.repositorySubdirectory}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpace.xs),
              Text(
                '本地仓库目录：${controller.directory.isEmpty ? '尚未选择' : controller.directory}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpace.lg),
              AppActionButton(
                label: '清除当前连接',
                icon: Icons.delete_outline,
                style: AppActionButtonStyle.secondary,
                onPressed: controller.busy ? null : controller.reset,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
