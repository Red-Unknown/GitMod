import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gitmod/controllers/git_mod_controller.dart';
import 'package:gitmod/core/directory_picker.dart';
import 'package:gitmod/core/user_facing_exception.dart';
import 'package:gitmod/models/mod_config.dart';
import 'package:gitmod/models/mod_snapshot.dart';
import 'package:gitmod/models/operation_stage.dart';
import 'package:gitmod/services/app_config_store.dart';
import 'package:gitmod/services/git_mod_service.dart';

void main() {
  test('连接失败后可重试，UI 只收到中文恢复信息', () async {
    final service = _FakeGitService()..failConnectOnce = true;
    final controller = GitModController(
      configStore: _MemoryStore(),
      gitService: service,
      directoryPicker: const _FakeDirectoryPicker('/mods/example'),
    );
    await controller.setName('示例 Mod');
    await controller.setRepositoryUrl('https://example.test/mod.git');
    await controller.pickDirectory();

    await controller.connect();
    expect(controller.busy, isFalse);
    expect(controller.error, '无法连接仓库，请检查网络后重试。');
    expect(controller.activity.first.success, isFalse);

    await controller.retry();
    expect(controller.error, isNull);
    expect(controller.snapshot!.isConnected, isTrue);
    expect(controller.activity.first.success, isTrue);
  });

  test('配置变更会持久化，重置会清空配置', () async {
    final store = _MemoryStore();
    final controller = GitModController(
      configStore: store,
      gitService: _FakeGitService(),
      directoryPicker: const _FakeDirectoryPicker(null),
    );
    await controller.setRole(ModRole.creator);
    await controller.setName('发布用 Mod');
    expect(store.value!.role, ModRole.creator);
    expect(store.value!.name, '发布用 Mod');

    await controller.reset();
    expect(store.value, isNull);
    expect(controller.name, isEmpty);
  });

  test('发布说明为空会被拒绝，发布结束后阶段复位', () async {
    final service = _FakeGitService();
    final controller = GitModController(
      configStore: _MemoryStore(),
      gitService: service,
      directoryPicker: const _FakeDirectoryPicker('/mods/example'),
    );
    await controller.setName('示例 Mod');
    await controller.setRepositoryUrl('https://example.test/mod.git');
    await controller.pickDirectory();

    await controller.publish('  ');
    expect(controller.error, '请填写本次更新说明后再发布。');
    expect(service.publishedMessages, isEmpty);

    final completion = Completer<ModSnapshot>();
    service.publishCompleter = completion;
    final publishing = controller.publish('修复加载问题');
    expect(controller.busy, isTrue);
    expect(controller.operationStage, OperationStage.publishing);
    completion.complete(
      service.snapshotFor(
        controller.role,
        controller.name,
        controller.directory,
        controller.repositoryUrl,
      ),
    );
    await publishing;
    expect(service.publishedMessages, <String>['修复加载问题']);
    expect(controller.operationStage, OperationStage.idle);
  });
}

class _MemoryStore implements AppConfigStore {
  ModConfig? value;

  @override
  Future<void> clear() async => value = null;

  @override
  Future<ModConfig?> load() async => value;

  @override
  Future<void> save(ModConfig config) async => value = config;
}

class _FakeDirectoryPicker implements DirectoryPicker {
  const _FakeDirectoryPicker(this.value);

  final String? value;

  @override
  Future<String?> pickDirectory() async => value;
}

class _FakeGitService implements GitModService {
  bool failConnectOnce = false;
  final List<String> publishedMessages = <String>[];
  Completer<ModSnapshot>? publishCompleter;

  @override
  Future<ModSnapshot> connect(ModConfig config) async {
    if (failConnectOnce) {
      failConnectOnce = false;
      throw const UserFacingException('无法连接仓库，请检查网络后重试。');
    }
    return _snapshot(config);
  }

  @override
  Future<ModSnapshot> publish(ModConfig config, String message) async {
    publishedMessages.add(message);
    final completion = publishCompleter;
    if (completion != null) return completion.future;
    return _snapshot(config);
  }

  @override
  Future<ModSnapshot> refresh(ModConfig config) async => _snapshot(config);

  @override
  Future<ModSnapshot> sync(ModConfig config) async => _snapshot(config);

  ModSnapshot snapshotFor(
    ModRole role,
    String name,
    String directory,
    String repositoryUrl,
  ) => _snapshot(
    ModConfig(
      role: role,
      name: name,
      directoryPath: directory,
      repositoryUrl: repositoryUrl,
    ),
  );

  ModSnapshot _snapshot(ModConfig config) => ModSnapshot(
    config: config,
    isConnected: true,
    hasUpdates: false,
    hasLocalChanges: false,
    localVersion: '尚未发布',
    remoteUpdateMessage: null,
    pendingUpdateFiles: const <String>[],
    localChangedFiles: const <String>[],
  );
}
