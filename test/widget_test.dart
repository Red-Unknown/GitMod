import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gitmod/controllers/git_mod_controller.dart';
import 'package:gitmod/core/directory_picker.dart';
import 'package:gitmod/core/user_facing_exception.dart';
import 'package:gitmod/models/mod_config.dart';
import 'package:gitmod/models/mod_snapshot.dart';
import 'package:gitmod/services/app_config_store.dart';
import 'package:gitmod/services/git_mod_service.dart';
import 'package:gitmod/ui/design_lab_page.dart';
import 'package:gitmod/ui/git_mod_app.dart';

void main() {
  testWidgets('首次打开显示连接表单并可选择作者', (tester) async {
    final controller = _controller();
    await tester.pumpWidget(GitModApp(controller: controller));

    expect(find.text('连接仓库'), findsOneWidget);
    expect(find.text('连接并初始化'), findsOneWidget);
    expect(find.text('仓库内 Mod 目录（可选）'), findsOneWidget);
    expect(find.text('例如：测试/PEAK_mod；留空会同步整个仓库。'), findsOneWidget);
    await tester.tap(find.text('我是作者'));
    await tester.pump();
    expect(controller.role, ModRole.creator);
  });

  testWidgets('首次启动时左侧导航可以切换到其他页面', (tester) async {
    final controller = _controller();
    await tester.pumpWidget(GitModApp(controller: controller));

    await tester.tap(find.text('活动记录'));
    await tester.pump();
    expect(find.text('查看本次运行期间的发布和同步结果。'), findsOneWidget);
    expect(find.text('连接并初始化'), findsNothing);

    await tester.tap(find.text('设置'));
    await tester.pump();
    expect(find.text('管理当前设备上的 Mod 连接信息。'), findsOneWidget);
  });

  testWidgets('连接后显示仓库内 Mod 的实际路径和设置摘要', (tester) async {
    final controller = _controller();
    await controller.setName('测试 Mod');
    await controller.setDirectory(r'C:\Mods\Repository');
    await controller.setRepositoryUrl('https://example.com/mod.git');
    await controller.setRepositorySubdirectory('测试/PEAK_mod');
    await controller.connect();
    await tester.pumpWidget(GitModApp(controller: controller));

    expect(find.text(r'C:\Mods\Repository\测试\PEAK_mod'), findsOneWidget);

    await tester.tap(find.text('设置'));
    await tester.pump();
    expect(find.text('仓库内 Mod 目录：测试/PEAK_mod'), findsOneWidget);
    expect(find.text(r'本地仓库目录：C:\Mods\Repository'), findsOneWidget);
  });

  testWidgets('Design Lab 展示仓库内 Mod 目录字段', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: DesignLabPage()));

    expect(find.text('仓库内 Mod 目录（可选）'), findsOneWidget);
    expect(find.text('例如：测试/PEAK_mod；留空会同步整个仓库。'), findsOneWidget);
    expect(find.text('本地仓库目录'), findsOneWidget);
  });

  testWidgets('连接失败显示中文原因并提供重试', (tester) async {
    final controller = _controller(failConnect: true);
    await controller.setName('测试 Mod');
    await controller.setDirectory(r'C:\Mods\Test');
    await controller.setRepositoryUrl('https://example.com/mod.git');
    await tester.pumpWidget(GitModApp(controller: controller));
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pump();
    await tester.tap(find.text('连接并初始化'));
    await tester.pumpAndSettle();

    expect(find.text('操作未完成'), findsOneWidget);
    expect(find.text('仓库暂时不可用，请稍后重试。'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
  });

  testWidgets('重置和切换角色会清空连接表单', (tester) async {
    final controller = _controller();
    await tester.pumpWidget(GitModApp(controller: controller));

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '旧 Mod');
    await tester.enterText(fields.at(1), 'https://example.com/old.git');
    await tester.enterText(fields.at(2), r'测试\PEAK_mod');
    await tester.enterText(fields.at(3), r'C:\Mods\Old');
    await tester.pump();

    await tester.tap(find.text('我是作者'));
    await tester.pumpAndSettle();
    expect(controller.role, ModRole.creator);
    expect(controller.name, isEmpty);
    expect(controller.repositoryUrl, isEmpty);
    expect(controller.repositorySubdirectory, isEmpty);
    expect(controller.directory, isEmpty);
    expect(find.text('旧 Mod'), findsNothing);

    await tester.enterText(fields.at(0), '待清除 Mod');
    await tester.pump();
    await controller.reset();
    await tester.pumpAndSettle();
    expect(find.text('待清除 Mod'), findsNothing);
    expect(controller.name, isEmpty);
    expect(controller.repositoryUrl, isEmpty);
    expect(controller.repositorySubdirectory, isEmpty);
    expect(controller.directory, isEmpty);
  });
}

GitModController _controller({bool failConnect = false}) {
  return GitModController(
    configStore: _MemoryConfigStore(),
    gitService: _FakeService(failConnect: failConnect),
    directoryPicker: const _NoopPicker(),
  );
}

class _MemoryConfigStore implements AppConfigStore {
  ModConfig? value;

  @override
  Future<void> clear() async => value = null;

  @override
  Future<ModConfig?> load() async => value;

  @override
  Future<void> save(ModConfig config) async => value = config;
}

class _NoopPicker implements DirectoryPicker {
  const _NoopPicker();

  @override
  Future<String?> pickDirectory() async => null;
}

class _FakeService implements GitModService {
  _FakeService({required this.failConnect});

  final bool failConnect;

  ModSnapshot _snapshot(ModConfig config) => ModSnapshot(
    config: config,
    isConnected: true,
    hasUpdates: false,
    hasLocalChanges: true,
    localVersion: '尚未发布',
    remoteUpdateMessage: null,
    pendingUpdateFiles: const <String>[],
    localChangedFiles: const <String>['plugins/example.dll'],
  );

  @override
  Future<ModSnapshot> connect(ModConfig config) async {
    if (failConnect) {
      throw const UserFacingException('仓库暂时不可用，请稍后重试。');
    }
    return _snapshot(config);
  }

  @override
  Future<ModSnapshot> refresh(ModConfig config) async => _snapshot(config);

  @override
  Future<ModSnapshot> publish(ModConfig config, String message) async =>
      _snapshot(config);

  @override
  Future<ModSnapshot> sync(ModConfig config) async => _snapshot(config);
}
