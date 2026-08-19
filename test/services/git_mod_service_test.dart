import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gitmod/core/command_runner.dart';
import 'package:gitmod/core/user_facing_exception.dart';
import 'package:gitmod/models/mod_config.dart';
import 'package:gitmod/services/git_mod_service.dart';

void main() {
  late bool gitAvailable;

  setUpAll(() async {
    try {
      gitAvailable =
          (await Process.run('git', <String>['--version'])).exitCode == 0;
    } on ProcessException {
      gitAvailable = false;
    }
  });

  test('作者发布后，玩家可克隆、检查并快进同步', () async {
    if (!gitAvailable) markTestSkipped('当前环境未安装 Git。');
    final root = await Directory.systemTemp.createTemp('gitmod-e2e-');
    addTearDown(() => root.delete(recursive: true));
    final remote = Directory('${root.path}${Platform.pathSeparator}remote.git');
    final creator = Directory('${root.path}${Platform.pathSeparator}creator');
    final player = Directory('${root.path}${Platform.pathSeparator}player');
    await creator.create();
    await File(
      '${creator.path}${Platform.pathSeparator}mod.txt',
    ).writeAsString('第一版', encoding: utf8);
    await _git(root.path, <String>['init', '--bare', remote.path]);
    final service = GitCliModService(timeout: const Duration(seconds: 10));
    final creatorConfig = ModConfig(
      role: ModRole.creator,
      name: '测试 Mod',
      directoryPath: creator.path,
      repositoryUrl: remote.path,
    );

    final connected = await service.connect(creatorConfig);
    expect(connected.localChangedFiles, <String>['mod.txt']);
    await _git(creator.path, <String>['config', 'user.name', 'GitMod Test']);
    await _git(creator.path, <String>[
      'config',
      'user.email',
      'gitmod@example.test',
    ]);
    await service.publish(creatorConfig, '首次发布说明');

    final playerConfig = ModConfig(
      role: ModRole.player,
      name: '测试 Mod',
      directoryPath: player.path,
      repositoryUrl: remote.path,
    );
    final initial = await service.connect(playerConfig);
    expect(initial.hasUpdates, isFalse);
    expect(initial.localVersion, contains('首次发布说明'));
    expect(
      await File(
        '${player.path}${Platform.pathSeparator}mod.txt',
      ).readAsString(),
      '第一版',
    );

    await File(
      '${creator.path}${Platform.pathSeparator}mod.txt',
    ).writeAsString('第二版', encoding: utf8);
    await service.publish(creatorConfig, '第二版更新说明');
    final update = await service.refresh(playerConfig);
    expect(update.hasUpdates, isTrue);
    expect(update.remoteUpdateMessage, '第二版更新说明');
    expect(update.pendingUpdateFiles, contains('mod.txt'));
    expect(update.changedFileCount, greaterThanOrEqualTo(1));

    await service.sync(playerConfig);
    expect(
      await File(
        '${player.path}${Platform.pathSeparator}mod.txt',
      ).readAsString(),
      '第二版',
    );
  });

  test('指定仓库内 Mod 子目录时只发布并展示该目录', () async {
    if (!gitAvailable) markTestSkipped('当前环境未安装 Git。');
    final root = await Directory.systemTemp.createTemp('gitmod-subdir-');
    addTearDown(() => root.delete(recursive: true));
    final remote = Directory('${root.path}${Platform.pathSeparator}remote.git');
    final creator = Directory('${root.path}${Platform.pathSeparator}creator');
    final player = Directory('${root.path}${Platform.pathSeparator}player');
    final modDirectory = Directory(
      '${creator.path}${Platform.pathSeparator}测试${Platform.pathSeparator}PEAK_mod',
    );
    await modDirectory.create(recursive: true);
    await File(
      '${modDirectory.path}${Platform.pathSeparator}mod.txt',
    ).writeAsString('第一版', encoding: utf8);
    await File(
      '${creator.path}${Platform.pathSeparator}仅本地.txt',
    ).writeAsString('不应发布', encoding: utf8);
    await _git(root.path, <String>['init', '--bare', remote.path]);
    final service = GitCliModService(timeout: const Duration(seconds: 10));
    final creatorConfig = ModConfig(
      role: ModRole.creator,
      name: '测试 Mod',
      directoryPath: creator.path,
      repositoryUrl: remote.path,
      repositorySubdirectory: '测试/PEAK_mod',
    );

    final connected = await service.connect(creatorConfig);
    expect(connected.localChangedFiles, <String>['mod.txt']);
    await _git(creator.path, <String>['config', 'user.name', 'GitMod Test']);
    await _git(creator.path, <String>[
      'config',
      'user.email',
      'gitmod@example.test',
    ]);
    final initial = await service.publish(creatorConfig, '子目录首次发布');
    expect(initial.localChangedFiles, isEmpty);

    final playerConfig = ModConfig(
      role: ModRole.player,
      name: '测试 Mod',
      directoryPath: player.path,
      repositoryUrl: remote.path,
      repositorySubdirectory: r'测试\PEAK_mod',
    );
    await service.connect(playerConfig);
    expect(
      await File(
        '${player.path}${Platform.pathSeparator}测试${Platform.pathSeparator}PEAK_mod${Platform.pathSeparator}mod.txt',
      ).readAsString(),
      '第一版',
    );
    expect(
      await File('${player.path}${Platform.pathSeparator}仅本地.txt').exists(),
      isFalse,
    );

    await File(
      '${modDirectory.path}${Platform.pathSeparator}mod.txt',
    ).writeAsString('第二版', encoding: utf8);
    await File(
      '${creator.path}${Platform.pathSeparator}仅本地.txt',
    ).writeAsString('仍不应发布', encoding: utf8);
    await service.publish(creatorConfig, '子目录第二版');

    final update = await service.refresh(playerConfig);
    expect(update.hasUpdates, isTrue);
    expect(update.remoteUpdateMessage, '子目录第二版');
    expect(update.pendingUpdateFiles, <String>['mod.txt']);
    await service.sync(playerConfig);
    expect(
      await File(
        '${player.path}${Platform.pathSeparator}测试${Platform.pathSeparator}PEAK_mod${Platform.pathSeparator}mod.txt',
      ).readAsString(),
      '第二版',
    );
    expect(
      await File('${player.path}${Platform.pathSeparator}仅本地.txt').exists(),
      isFalse,
    );
  });

  test('仓库其他目录有远端提交时仍提示可同步但不列出无关文件', () async {
    if (!gitAvailable) markTestSkipped('当前环境未安装 Git。');
    final root = await Directory.systemTemp.createTemp('gitmod-subdir-remote-');
    addTearDown(() => root.delete(recursive: true));
    final remote = Directory('${root.path}${Platform.pathSeparator}remote.git');
    final creator = Directory('${root.path}${Platform.pathSeparator}creator');
    final other = Directory('${root.path}${Platform.pathSeparator}other');
    final player = Directory('${root.path}${Platform.pathSeparator}player');
    final modDirectory = Directory(
      '${creator.path}${Platform.pathSeparator}测试${Platform.pathSeparator}PEAK_mod',
    );
    await modDirectory.create(recursive: true);
    await File(
      '${modDirectory.path}${Platform.pathSeparator}mod.txt',
    ).writeAsString('第一版', encoding: utf8);
    await _git(root.path, <String>['init', '--bare', remote.path]);
    final service = GitCliModService(timeout: const Duration(seconds: 10));
    final creatorConfig = ModConfig(
      role: ModRole.creator,
      name: '测试 Mod',
      directoryPath: creator.path,
      repositoryUrl: remote.path,
      repositorySubdirectory: '测试/PEAK_mod',
    );
    await service.connect(creatorConfig);
    await _git(creator.path, <String>['config', 'user.name', 'GitMod Test']);
    await _git(creator.path, <String>[
      'config',
      'user.email',
      'gitmod@example.test',
    ]);
    await service.publish(creatorConfig, '子目录首次发布');

    final playerConfig = ModConfig(
      role: ModRole.player,
      name: '测试 Mod',
      directoryPath: player.path,
      repositoryUrl: remote.path,
      repositorySubdirectory: '测试/PEAK_mod',
    );
    await service.connect(playerConfig);
    await _git(root.path, <String>['clone', remote.path, other.path]);
    await _git(other.path, <String>['config', 'user.name', 'Other Test']);
    await _git(other.path, <String>[
      'config',
      'user.email',
      'other@example.test',
    ]);
    await File(
      '${other.path}${Platform.pathSeparator}仓库说明.txt',
    ).writeAsString('仅仓库级更新', encoding: utf8);
    await _git(other.path, <String>['add', '--all']);
    await _git(other.path, <String>['commit', '-m', '仓库级更新']);
    await _git(other.path, <String>['push']);

    final update = await service.refresh(playerConfig);
    expect(update.hasUpdates, isTrue);
    expect(update.remoteUpdateMessage, '仓库有更新，但当前 Mod 目录没有文件变化');
    expect(update.pendingUpdateFiles, isEmpty);
    await service.sync(playerConfig);
    expect(
      await File('${player.path}${Platform.pathSeparator}仓库说明.txt').exists(),
      isTrue,
    );
  });

  test('仓库内 Mod 目录路径会拒绝越界和 Git 元数据路径', () async {
    expect(ModConfig.validateRepositorySubdirectory('测试/PEAK_mod'), isNull);
    expect(ModConfig.validateRepositorySubdirectory(''), isNull);
    expect(ModConfig.validateRepositorySubdirectory('/'), isNotNull);
    expect(ModConfig.validateRepositorySubdirectory('../PEAK_mod'), isNotNull);
    expect(ModConfig.validateRepositorySubdirectory(r'C:\PEAK_mod'), isNotNull);
    expect(ModConfig.validateRepositorySubdirectory('.git/config'), isNotNull);
  });

  test('指定的仓库内 Mod 目录不存在时连接会给出明确提示', () async {
    if (!gitAvailable) markTestSkipped('当前环境未安装 Git。');
    final root = await Directory.systemTemp.createTemp(
      'gitmod-subdir-missing-',
    );
    addTearDown(() => root.delete(recursive: true));
    final remote = Directory('${root.path}${Platform.pathSeparator}remote.git');
    final creator = Directory('${root.path}${Platform.pathSeparator}creator');
    await creator.create();
    await _git(root.path, <String>['init', '--bare', remote.path]);
    final config = ModConfig(
      role: ModRole.creator,
      name: '测试 Mod',
      directoryPath: creator.path,
      repositoryUrl: remote.path,
      repositorySubdirectory: '测试/不存在',
    );

    await expectLater(
      GitCliModService(timeout: const Duration(seconds: 10)).connect(config),
      throwsA(
        isA<UserFacingException>().having(
          (error) => error.message,
          'message',
          contains('指定的仓库内 Mod 目录不存在'),
        ),
      ),
    );
  });

  test('玩家本地有改动时同步会被保护性阻止', () async {
    if (!gitAvailable) markTestSkipped('当前环境未安装 Git。');
    final root = await Directory.systemTemp.createTemp('gitmod-local-change-');
    addTearDown(() => root.delete(recursive: true));
    final remote = Directory('${root.path}${Platform.pathSeparator}remote.git');
    final creator = Directory('${root.path}${Platform.pathSeparator}creator');
    final player = Directory('${root.path}${Platform.pathSeparator}player');
    await creator.create();
    await File(
      '${creator.path}${Platform.pathSeparator}mod.txt',
    ).writeAsString('初始', encoding: utf8);
    await _git(root.path, <String>['init', '--bare', remote.path]);
    final service = GitCliModService(timeout: const Duration(seconds: 10));
    final creatorConfig = ModConfig(
      role: ModRole.creator,
      name: 'Mod',
      directoryPath: creator.path,
      repositoryUrl: remote.path,
    );
    await service.connect(creatorConfig);
    await _git(creator.path, <String>['config', 'user.name', 'GitMod Test']);
    await _git(creator.path, <String>[
      'config',
      'user.email',
      'gitmod@example.test',
    ]);
    await service.publish(creatorConfig, '首次发布说明');
    final playerConfig = ModConfig(
      role: ModRole.player,
      name: 'Mod',
      directoryPath: player.path,
      repositoryUrl: remote.path,
    );
    await service.connect(playerConfig);
    await File(
      '${player.path}${Platform.pathSeparator}mod.txt',
    ).rename('${player.path}${Platform.pathSeparator}renamed file.txt');
    final localChanges = await service.refresh(playerConfig);
    expect(localChanges.localChangedFiles, contains('renamed file.txt'));

    await expectLater(
      service.sync(playerConfig),
      throwsA(
        isA<UserFacingException>().having(
          (error) => error.message,
          'message',
          contains('本地改动'),
        ),
      ),
    );
  });

  test('玩家同步会保护仓库其他目录的未处理改动', () async {
    if (!gitAvailable) markTestSkipped('当前环境未安装 Git。');
    final root = await Directory.systemTemp.createTemp('gitmod-subdir-dirty-');
    addTearDown(() => root.delete(recursive: true));
    final remote = Directory('${root.path}${Platform.pathSeparator}remote.git');
    final creator = Directory('${root.path}${Platform.pathSeparator}creator');
    final player = Directory('${root.path}${Platform.pathSeparator}player');
    final creatorMod = Directory(
      '${creator.path}${Platform.pathSeparator}测试${Platform.pathSeparator}PEAK_mod',
    );
    await creatorMod.create(recursive: true);
    await File(
      '${creatorMod.path}${Platform.pathSeparator}mod.txt',
    ).writeAsString('初始', encoding: utf8);
    await _git(root.path, <String>['init', '--bare', remote.path]);
    final service = GitCliModService(timeout: const Duration(seconds: 10));
    final creatorConfig = ModConfig(
      role: ModRole.creator,
      name: '测试 Mod',
      directoryPath: creator.path,
      repositoryUrl: remote.path,
      repositorySubdirectory: '测试/PEAK_mod',
    );
    await service.connect(creatorConfig);
    await _git(creator.path, <String>['config', 'user.name', 'GitMod Test']);
    await _git(creator.path, <String>[
      'config',
      'user.email',
      'gitmod@example.test',
    ]);
    await service.publish(creatorConfig, '首次发布');

    final playerConfig = ModConfig(
      role: ModRole.player,
      name: '测试 Mod',
      directoryPath: player.path,
      repositoryUrl: remote.path,
      repositorySubdirectory: '测试/PEAK_mod',
    );
    await service.connect(playerConfig);
    await File(
      '${creatorMod.path}${Platform.pathSeparator}mod.txt',
    ).writeAsString('远端更新', encoding: utf8);
    await service.publish(creatorConfig, '发布更新');
    await File(
      '${player.path}${Platform.pathSeparator}仓库说明.txt',
    ).writeAsString('不要覆盖', encoding: utf8);

    await expectLater(
      service.sync(playerConfig),
      throwsA(
        isA<UserFacingException>().having(
          (error) => error.message,
          'message',
          contains('本地改动'),
        ),
      ),
    );
  });

  test('仓库内 Mod 目录不能代替本地仓库根目录', () async {
    if (!gitAvailable) markTestSkipped('当前环境未安装 Git。');
    final root = await Directory.systemTemp.createTemp('gitmod-root-only-');
    addTearDown(() => root.delete(recursive: true));
    final remote = Directory('${root.path}${Platform.pathSeparator}remote.git');
    final creator = Directory('${root.path}${Platform.pathSeparator}creator');
    final player = Directory('${root.path}${Platform.pathSeparator}player');
    await creator.create();
    await File(
      '${creator.path}${Platform.pathSeparator}mod.txt',
    ).writeAsString('初始', encoding: utf8);
    await _git(root.path, <String>['init', '--bare', remote.path]);
    final service = GitCliModService(timeout: const Duration(seconds: 10));
    final creatorConfig = ModConfig(
      role: ModRole.creator,
      name: '测试 Mod',
      directoryPath: creator.path,
      repositoryUrl: remote.path,
    );
    await service.connect(creatorConfig);
    await _git(creator.path, <String>['config', 'user.name', 'GitMod Test']);
    await _git(creator.path, <String>[
      'config',
      'user.email',
      'gitmod@example.test',
    ]);
    await service.publish(creatorConfig, '首次发布');
    await service.connect(
      ModConfig(
        role: ModRole.player,
        name: '测试 Mod',
        directoryPath: player.path,
        repositoryUrl: remote.path,
      ),
    );
    final nestedDirectory = Directory(
      '${player.path}${Platform.pathSeparator}测试',
    );
    await nestedDirectory.create();
    await File(
      '${nestedDirectory.path}${Platform.pathSeparator}keep.txt',
    ).writeAsString('保留为外层仓库子目录', encoding: utf8);

    await expectLater(
      service.connect(
        ModConfig(
          role: ModRole.player,
          name: '测试 Mod',
          directoryPath: nestedDirectory.path,
          repositoryUrl: remote.path,
        ),
      ),
      throwsA(
        isA<UserFacingException>().having(
          (error) => error.message,
          'message',
          contains('仓库的根目录'),
        ),
      ),
    );
  });

  test('远端领先时会阻止作者覆盖发布', () async {
    if (!gitAvailable) markTestSkipped('当前环境未安装 Git。');
    final root = await Directory.systemTemp.createTemp('gitmod-remote-ahead-');
    addTearDown(() => root.delete(recursive: true));
    final remote = Directory('${root.path}${Platform.pathSeparator}remote.git');
    final creator = Directory('${root.path}${Platform.pathSeparator}creator');
    final other = Directory('${root.path}${Platform.pathSeparator}other');
    await creator.create();
    await File(
      '${creator.path}${Platform.pathSeparator}mod.txt',
    ).writeAsString('初始', encoding: utf8);
    await _git(root.path, <String>['init', '--bare', remote.path]);
    final service = GitCliModService(timeout: const Duration(seconds: 10));
    final config = ModConfig(
      role: ModRole.creator,
      name: 'Mod',
      directoryPath: creator.path,
      repositoryUrl: remote.path,
    );
    await service.connect(config);
    await _git(creator.path, <String>['config', 'user.name', 'GitMod Test']);
    await _git(creator.path, <String>[
      'config',
      'user.email',
      'gitmod@example.test',
    ]);
    await service.publish(config, '首次发布说明');
    await _git(root.path, <String>['clone', remote.path, other.path]);
    await _git(other.path, <String>['config', 'user.name', 'Other Test']);
    await _git(other.path, <String>[
      'config',
      'user.email',
      'other@example.test',
    ]);
    await File(
      '${other.path}${Platform.pathSeparator}mod.txt',
    ).writeAsString('远端更新', encoding: utf8);
    await _git(other.path, <String>['add', '--all']);
    await _git(other.path, <String>['commit', '-m', '远端更新']);
    await _git(other.path, <String>['push']);
    await File(
      '${creator.path}${Platform.pathSeparator}mod.txt',
    ).writeAsString('作者本地更新', encoding: utf8);

    await expectLater(
      service.publish(config, '作者本地更新'),
      throwsA(
        isA<UserFacingException>().having(
          (error) => error.message,
          'message',
          contains('远端已有更新'),
        ),
      ),
    );
  });

  test('发布说明为空时服务会在调用 Git 前拒绝操作', () async {
    final service = GitCliModService();
    const config = ModConfig(
      role: ModRole.creator,
      name: 'Mod',
      directoryPath: 'C:/unused',
      repositoryUrl: 'https://example.test/mod.git',
    );

    await expectLater(
      service.publish(config, '  '),
      throwsA(
        isA<UserFacingException>().having(
          (error) => error.message,
          'message',
          '请填写本次更新说明后再发布。',
        ),
      ),
    );
  });

  test('作者不会把只有 tag 的远端当成空仓库初始化', () async {
    if (!gitAvailable) markTestSkipped('当前环境未安装 Git。');
    final root = await Directory.systemTemp.createTemp('gitmod-tag-only-');
    addTearDown(() => root.delete(recursive: true));
    final remote = Directory('${root.path}${Platform.pathSeparator}remote.git');
    final source = Directory('${root.path}${Platform.pathSeparator}source');
    final creator = Directory('${root.path}${Platform.pathSeparator}creator');
    await source.create();
    await creator.create();
    await _git(root.path, <String>['init', '--bare', remote.path]);
    await _git(source.path, <String>['init']);
    await _git(source.path, <String>['config', 'user.name', 'Tag Test']);
    await _git(source.path, <String>[
      'config',
      'user.email',
      'tag@example.test',
    ]);
    await File(
      '${source.path}${Platform.pathSeparator}tagged.txt',
    ).writeAsString('tag');
    await _git(source.path, <String>['add', '--all']);
    await _git(source.path, <String>['commit', '-m', 'tag only']);
    await _git(source.path, <String>['tag', 'v0.1']);
    await _git(source.path, <String>['push', remote.path, 'refs/tags/v0.1']);
    await File(
      '${creator.path}${Platform.pathSeparator}local.txt',
    ).writeAsString('local');
    final service = GitCliModService(timeout: const Duration(seconds: 10));
    final config = ModConfig(
      role: ModRole.creator,
      name: 'Mod',
      directoryPath: creator.path,
      repositoryUrl: remote.path,
    );

    await expectLater(
      service.connect(config),
      throwsA(
        isA<UserFacingException>().having(
          (error) => error.message,
          'message',
          contains('远端已有内容'),
        ),
      ),
    );
  });

  test('已有提交但没有远端跟踪分支时不会静默判定为最新', () async {
    if (!gitAvailable) markTestSkipped('当前环境未安装 Git。');
    final root = await Directory.systemTemp.createTemp('gitmod-no-upstream-');
    addTearDown(() => root.delete(recursive: true));
    final remote = Directory('${root.path}${Platform.pathSeparator}remote.git');
    final creator = Directory('${root.path}${Platform.pathSeparator}creator');
    await creator.create();
    await _git(root.path, <String>['init', '--bare', remote.path]);
    await _git(creator.path, <String>['init']);
    await _git(creator.path, <String>['config', 'user.name', 'Branch Test']);
    await _git(creator.path, <String>[
      'config',
      'user.email',
      'branch@example.test',
    ]);
    await File(
      '${creator.path}${Platform.pathSeparator}local.txt',
    ).writeAsString('local');
    await _git(creator.path, <String>['add', '--all']);
    await _git(creator.path, <String>['commit', '-m', 'local']);
    await _git(creator.path, <String>['remote', 'add', 'origin', remote.path]);
    final service = GitCliModService(timeout: const Duration(seconds: 10));
    final config = ModConfig(
      role: ModRole.creator,
      name: 'Mod',
      directoryPath: creator.path,
      repositoryUrl: remote.path,
    );

    await expectLater(
      service.refresh(config),
      throwsA(
        isA<UserFacingException>().having(
          (error) => error.message,
          'message',
          contains('远端跟踪分支'),
        ),
      ),
    );
  });

  test('首次 push 失败后重试会继续推送本地领先提交', () async {
    if (!gitAvailable) markTestSkipped('当前环境未安装 Git。');
    final root = await Directory.systemTemp.createTemp('gitmod-push-retry-');
    addTearDown(() => root.delete(recursive: true));
    final remote = Directory('${root.path}${Platform.pathSeparator}remote.git');
    final creator = Directory('${root.path}${Platform.pathSeparator}creator');
    final checkout = Directory('${root.path}${Platform.pathSeparator}checkout');
    await creator.create();
    await _git(root.path, <String>['init', '--bare', remote.path]);
    await File(
      '${creator.path}${Platform.pathSeparator}mod.txt',
    ).writeAsString('首版');
    final runner = _FailFirstPushRunner();
    final service = GitCliModService(
      runner: runner,
      timeout: const Duration(seconds: 10),
    );
    final config = ModConfig(
      role: ModRole.creator,
      name: 'Mod',
      directoryPath: creator.path,
      repositoryUrl: remote.path,
    );
    await service.connect(config);
    await _git(creator.path, <String>['config', 'user.name', 'Retry Test']);
    await _git(creator.path, <String>[
      'config',
      'user.email',
      'retry@example.test',
    ]);

    await expectLater(
      service.publish(config, '首次发布'),
      throwsA(isA<UserFacingException>()),
    );
    expect(
      await File(
        '${creator.path}${Platform.pathSeparator}mod.txt',
      ).readAsString(),
      '首版',
    );

    await service.publish(config, '首次发布重试');
    await _git(root.path, <String>['clone', remote.path, checkout.path]);
    expect(
      await File(
        '${checkout.path}${Platform.pathSeparator}mod.txt',
      ).readAsString(),
      '首版',
    );
  });
}

class _FailFirstPushRunner implements CommandRunner {
  const _FailFirstPushRunner();

  static bool _hasFailed = false;

  @override
  Future<CommandResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    required Map<String, String> environment,
    required Duration timeout,
  }) async {
    if (arguments.isNotEmpty && arguments.first == 'push' && !_hasFailed) {
      _hasFailed = true;
      return const CommandResult(
        exitCode: 1,
        stdout: '',
        stderr: 'temporary push failure',
      );
    }
    return const ProcessCommandRunner().run(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      environment: environment,
      timeout: timeout,
    );
  }
}

Future<void> _git(String workingDirectory, List<String> arguments) async {
  final result = await Process.run(
    'git',
    arguments,
    workingDirectory: workingDirectory,
  );
  if (result.exitCode != 0) {
    throw StateError('Git 测试准备失败：${result.stderr}');
  }
}
