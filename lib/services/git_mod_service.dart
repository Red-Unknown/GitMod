import 'dart:io';

import 'package:path/path.dart' as path;

import '../core/command_runner.dart';
import '../core/user_facing_exception.dart';
import '../models/mod_config.dart';
import '../models/mod_snapshot.dart';

abstract interface class GitModService {
  Future<ModSnapshot> connect(ModConfig config);
  Future<ModSnapshot> refresh(ModConfig config);
  Future<ModSnapshot> publish(ModConfig config, String message);
  Future<ModSnapshot> sync(ModConfig config);
}

class GitCliModService implements GitModService {
  GitCliModService({
    CommandRunner? runner,
    this.timeout = const Duration(seconds: 20),
  }) : _runner = runner ?? const ProcessCommandRunner();

  final CommandRunner _runner;
  final Duration timeout;

  static const _gitEnvironment = <String, String>{
    'GIT_TERMINAL_PROMPT': '0',
    'GCM_INTERACTIVE': 'Never',
    'LC_ALL': 'C.UTF-8',
    'LANG': 'C.UTF-8',
  };

  @override
  Future<ModSnapshot> connect(ModConfig config) async {
    _requireComplete(config);
    await _ensureGitAvailable();
    final directory = Directory(config.directoryPath);

    if (config.role == ModRole.creator) {
      if (!await directory.exists()) {
        throw const UserFacingException('作者目录不存在，请重新选择本地仓库目录。');
      }
      await _ensureCreatorRepository(config);
    } else {
      await _ensurePlayerRepository(config, directory);
    }
    return refresh(config);
  }

  @override
  Future<ModSnapshot> refresh(ModConfig config) async {
    _requireComplete(config);
    await _ensureGitAvailable();
    await _requireMatchingRepository(config);
    final localChangedFiles = await _localChangedFiles(config);
    await _gitRequired(<String>[
      'fetch',
      'origin',
    ], workingDirectory: config.directoryPath);
    final remoteUpdate = await _remoteUpdate(config);
    return ModSnapshot(
      config: config,
      isConnected: true,
      hasUpdates: remoteUpdate.hasUpdates,
      hasLocalChanges: localChangedFiles.isNotEmpty,
      localVersion: await _localVersion(config.directoryPath),
      remoteUpdateMessage: remoteUpdate.message,
      pendingUpdateFiles: remoteUpdate.changedFiles,
      localChangedFiles: localChangedFiles,
    );
  }

  @override
  Future<ModSnapshot> publish(ModConfig config, String message) async {
    if (config.role != ModRole.creator) {
      throw const UserFacingException('当前为玩家模式，不能发布更新。');
    }
    final trimmedMessage = message.trim();
    if (trimmedMessage.isEmpty) {
      throw const UserFacingException('请填写本次更新说明后再发布。');
    }
    await _requireMatchingRepository(config);
    await _gitRequired(<String>[
      'fetch',
      'origin',
    ], workingDirectory: config.directoryPath);
    late (int, int) counts;
    try {
      counts = await _aheadBehind(config.directoryPath);
    } on UserFacingException {
      if (!await _remoteIsEmpty(config.directoryPath)) rethrow;
      counts = (await _hasHead(config.directoryPath) ? 1 : 0, 0);
    }
    if (counts.$2 > 0) {
      throw const UserFacingException('远端已有更新，请先同步本地目录后再发布。');
    }
    final hasChanges = await _hasLocalChanges(config);
    if (!hasChanges && counts.$1 == 0) {
      throw const UserFacingException('没有检测到可发布的 Mod 改动。');
    }
    if (hasChanges) {
      await _gitRequired(<String>[
        'add',
        '--all',
        ..._selectedPathspec(config),
      ], workingDirectory: config.directoryPath);
      final commitArguments = <String>['commit', '-m', trimmedMessage];
      if (config.normalizedRepositorySubdirectory.isNotEmpty) {
        commitArguments.insert(1, '--only');
        commitArguments.addAll(_selectedPathspec(config));
      }
      await _gitRequired(
        commitArguments,
        workingDirectory: config.directoryPath,
        context: _GitContext.commit,
      );
    }
    await _gitRequired(<String>[
      'push',
      '-u',
      'origin',
      'HEAD',
    ], workingDirectory: config.directoryPath);
    return refresh(config);
  }

  @override
  Future<ModSnapshot> sync(ModConfig config) async {
    if (config.role != ModRole.player) {
      throw const UserFacingException('当前为作者模式，请使用发布更新。');
    }
    await _requireMatchingRepository(config);
    if (await _hasAnyLocalChanges(config.directoryPath)) {
      throw const UserFacingException('检测到本地改动，已停止同步以保护你的文件。请先处理本地改动。');
    }
    await _gitRequired(<String>[
      'fetch',
      'origin',
    ], workingDirectory: config.directoryPath);
    await _gitRequired(
      <String>['pull', '--ff-only'],
      workingDirectory: config.directoryPath,
      context: _GitContext.sync,
    );
    return refresh(config);
  }

  Future<void> _ensureGitAvailable() async {
    final result = await _gitRequired(<String>['--version']);
    if (result.exitCode != 0) {
      throw const UserFacingException('未检测到可用的 Git，请安装 Git 后重试。');
    }
  }

  Future<void> _ensureCreatorRepository(ModConfig config) async {
    final gitDirectory = Directory(
      '${config.directoryPath}${Platform.pathSeparator}.git',
    );
    if (!await gitDirectory.exists()) {
      final refs = await _gitRequired(<String>[
        'ls-remote',
        config.repositoryUrl,
      ]);
      if (refs.stdout.trim().isNotEmpty) {
        throw const UserFacingException('远端已有内容，请先选择已绑定该远端的本地仓库目录。');
      }
      await _gitRequired(<String>[
        'init',
      ], workingDirectory: config.directoryPath);
      await _gitRequired(<String>[
        'remote',
        'add',
        'origin',
        config.repositoryUrl,
      ], workingDirectory: config.directoryPath);
      return;
    }
    await _requireMatchingRepository(config);
  }

  Future<void> _ensurePlayerRepository(
    ModConfig config,
    Directory directory,
  ) async {
    if (!await directory.exists()) {
      await _gitRequired(<String>[
        'clone',
        config.repositoryUrl,
        config.directoryPath,
      ]);
      return;
    }
    if (await _isEmptyDirectory(directory)) {
      await _gitRequired(<String>[
        'clone',
        config.repositoryUrl,
        config.directoryPath,
      ]);
      return;
    }
    await _requireMatchingRepository(config);
  }

  Future<void> _requireMatchingRepository(ModConfig config) async {
    final directory = Directory(config.directoryPath);
    if (!await directory.exists()) {
      throw const UserFacingException('本地仓库目录不存在，请重新连接。');
    }
    final repository = await _rawGit(<String>[
      'rev-parse',
      '--is-inside-work-tree',
    ], workingDirectory: config.directoryPath);
    if (repository.exitCode != 0 || repository.stdout.trim() != 'true') {
      throw const UserFacingException('所选目录不是已连接的本地仓库，请重新连接。');
    }
    final repositoryRoot = await _rawGit(<String>[
      'rev-parse',
      '--show-toplevel',
    ], workingDirectory: config.directoryPath);
    if (repositoryRoot.exitCode != 0 ||
        !_sameDirectory(repositoryRoot.stdout.trim(), config.directoryPath)) {
      throw const UserFacingException('请选择 Git 仓库的根目录，而不是仓库内的子文件夹。');
    }
    final remote = await _rawGit(<String>[
      'remote',
      'get-url',
      'origin',
    ], workingDirectory: config.directoryPath);
    if (remote.exitCode != 0 ||
        remote.stdout.trim() != config.repositoryUrl.trim()) {
      throw const UserFacingException('本地仓库与填写的地址不一致，请确认仓库地址。');
    }
    final selectedDirectory = Directory(_selectedDirectoryPath(config));
    if (!await selectedDirectory.exists()) {
      throw const UserFacingException('指定的仓库内 Mod 目录不存在，请检查目录名称。');
    }
  }

  Future<bool> _hasLocalChanges(ModConfig config) async {
    return (await _localChangedFiles(config)).isNotEmpty;
  }

  Future<bool> _hasAnyLocalChanges(String directory) async {
    final result = await _gitRequired(<String>[
      '-c',
      'core.quotePath=false',
      'status',
      '--porcelain=v1',
      '-z',
    ], workingDirectory: directory);
    return result.stdout.isNotEmpty;
  }

  Future<List<String>> _localChangedFiles(ModConfig config) async {
    final result = await _gitRequired(<String>[
      '-c',
      'core.quotePath=false',
      'status',
      '--porcelain=v1',
      '-z',
      '--untracked-files=all',
      ..._selectedPathspec(config),
    ], workingDirectory: config.directoryPath);
    final tokens = result.stdout.split('\u0000');
    final paths = <String>[];
    for (var index = 0; index < tokens.length; index++) {
      final entry = tokens[index];
      if (entry.isEmpty) continue;
      final status = entry.length >= 2 ? entry.substring(0, 2) : '';
      final path = entry.length > 3 ? entry.substring(3) : entry;
      if (path.isNotEmpty) paths.add(_relativeSelectedPath(config, path));
      if (status.contains('R') || status.contains('C')) {
        if (index + 1 < tokens.length && tokens[index + 1].isNotEmpty) {
          paths.add(_relativeSelectedPath(config, tokens[++index]));
        }
      }
    }
    return paths.toSet().toList(growable: false);
  }

  Future<_RemoteUpdate> _remoteUpdate(ModConfig config) async {
    final counts = await _aheadBehind(config.directoryPath);
    if (counts.$2 == 0) return const _RemoteUpdate.none();
    final comparisonRef = await _comparisonRef(config.directoryPath);
    if (comparisonRef == null) return const _RemoteUpdate.none();
    final message = await _gitRequired(<String>[
      'log',
      '-1',
      '--format=%s',
      'HEAD..$comparisonRef',
      ..._selectedPathspec(config),
    ], workingDirectory: config.directoryPath);
    final files = await _gitRequired(<String>[
      '-c',
      'core.quotePath=false',
      'diff',
      '--name-only',
      'HEAD..$comparisonRef',
      ..._selectedPathspec(config),
    ], workingDirectory: config.directoryPath);
    final changedFiles = files.stdout
        .split('\n')
        .map((file) => file.trim())
        .where((file) => file.isNotEmpty)
        .map((file) => _relativeSelectedPath(config, file))
        .toList(growable: false);
    return _RemoteUpdate(
      message: changedFiles.isEmpty
          ? '仓库有更新，但当前 Mod 目录没有文件变化'
          : message.stdout.trim().isEmpty
          ? '远端有新的 Mod 更新'
          : message.stdout.trim(),
      changedFiles: changedFiles,
    );
  }

  Future<bool> _remoteIsEmpty(String directory) async {
    final result = await _rawGit(<String>[
      'ls-remote',
      '--refs',
      'origin',
    ], workingDirectory: directory);
    return result.exitCode == 0 && result.stdout.trim().isEmpty;
  }

  Future<bool> _hasHead(String directory) async {
    final result = await _rawGit(<String>[
      'rev-parse',
      '--verify',
      'HEAD',
    ], workingDirectory: directory);
    return result.exitCode == 0 && result.stdout.trim().isNotEmpty;
  }

  Future<(int, int)> _aheadBehind(String directory) async {
    final comparisonRef = await _comparisonRef(directory);
    if (comparisonRef == null) return (0, 0);
    final result = await _gitRequired(<String>[
      'rev-list',
      '--left-right',
      '--count',
      'HEAD...$comparisonRef',
    ], workingDirectory: directory);
    final parts = result.stdout.trim().split(RegExp(r'\s+'));
    if (parts.length != 2) {
      throw const UserFacingException('无法检查远端更新，请重试。');
    }
    return (int.tryParse(parts[0]) ?? 0, int.tryParse(parts[1]) ?? 0);
  }

  Future<String?> _comparisonRef(String directory) async {
    final upstream = await _rawGit(<String>[
      'rev-parse',
      '--verify',
      '@{upstream}',
    ], workingDirectory: directory);
    if (upstream.exitCode == 0 && upstream.stdout.trim().isNotEmpty) {
      return '@{upstream}';
    }
    final head = await _rawGit(<String>[
      'rev-parse',
      '--verify',
      'HEAD',
    ], workingDirectory: directory);
    if (head.exitCode != 0) return null;
    final branch = await _gitRequired(<String>[
      'branch',
      '--show-current',
    ], workingDirectory: directory);
    final branchName = branch.stdout.trim();
    if (branchName.isEmpty) {
      throw const UserFacingException('无法确定当前分支，请重新连接仓库后重试。');
    }
    final originRef = 'origin/$branchName';
    final remoteBranch = await _rawGit(<String>[
      'rev-parse',
      '--verify',
      originRef,
    ], workingDirectory: directory);
    if (remoteBranch.exitCode != 0) {
      throw const UserFacingException('无法确定远端跟踪分支，请先检查仓库连接后重试。');
    }
    return originRef;
  }

  Future<String> _localVersion(String directory) async {
    final tag = await _rawGit(<String>[
      'describe',
      '--tags',
      '--abbrev=0',
    ], workingDirectory: directory);
    if (tag.exitCode == 0 && tag.stdout.trim().isNotEmpty) {
      return '标签 ${tag.stdout.trim()}';
    }
    final summary = await _rawGit(<String>[
      'log',
      '-1',
      '--format=%cs%x09%s',
    ], workingDirectory: directory);
    if (summary.exitCode != 0 || summary.stdout.trim().isEmpty) {
      return '尚未发布';
    }
    final parts = summary.stdout.trim().split('\t');
    if (parts.length == 2 && parts[1].isNotEmpty) {
      return '${parts[0]} · ${parts[1]}';
    }
    return parts.first;
  }

  Future<bool> _isEmptyDirectory(Directory directory) async {
    await for (final _ in directory.list(followLinks: false)) {
      return false;
    }
    return true;
  }

  void _requireComplete(ModConfig config) {
    if (!config.isComplete) {
      throw const UserFacingException('请填写 Mod 名称、目录和仓库地址后再继续。');
    }
    final error = config.repositorySubdirectoryError;
    if (error != null) throw UserFacingException(error);
  }

  String _selectedDirectoryPath(ModConfig config) {
    final subdirectory = config.normalizedRepositorySubdirectory;
    if (subdirectory.isEmpty) return config.directoryPath;
    return path.joinAll(<String>[
      config.directoryPath,
      ...subdirectory.split('/'),
    ]);
  }

  List<String> _selectedPathspec(ModConfig config) {
    final subdirectory = config.normalizedRepositorySubdirectory;
    if (subdirectory.isEmpty) return const <String>[];
    return <String>['--', subdirectory];
  }

  String _relativeSelectedPath(ModConfig config, String value) {
    final normalized = value.replaceAll('\\', '/');
    final subdirectory = config.normalizedRepositorySubdirectory;
    if (subdirectory.isEmpty) return normalized;
    if (normalized == subdirectory) return '';
    final prefix = '$subdirectory/';
    if (normalized.startsWith(prefix)) {
      return normalized.substring(prefix.length);
    }
    return normalized;
  }

  bool _sameDirectory(String first, String second) {
    final normalizedFirst = path.normalize(path.absolute(first));
    final normalizedSecond = path.normalize(path.absolute(second));
    if (Platform.isWindows) {
      return normalizedFirst.toLowerCase() == normalizedSecond.toLowerCase();
    }
    return normalizedFirst == normalizedSecond;
  }

  Future<CommandResult> _gitRequired(
    List<String> arguments, {
    String? workingDirectory,
    _GitContext context = _GitContext.general,
  }) async {
    try {
      final result = await _rawGit(
        arguments,
        workingDirectory: workingDirectory,
      );
      if (result.exitCode != 0) {
        throw UserFacingException(_messageForFailure(context, result));
      }
      return result;
    } on CommandTimeoutException {
      throw const UserFacingException('操作超时，请检查网络或仓库地址后重试。');
    } on ProcessException {
      throw const UserFacingException('未检测到可用的 Git，请安装 Git 后重试。');
    }
  }

  Future<CommandResult> _rawGit(
    List<String> arguments, {
    String? workingDirectory,
  }) {
    return _runner.run(
      'git',
      arguments,
      workingDirectory: workingDirectory,
      environment: _gitEnvironment,
      timeout: timeout,
    );
  }

  String _messageForFailure(_GitContext context, CommandResult result) {
    final detail = '${result.stdout}\n${result.stderr}'.toLowerCase();
    if (detail.contains('authentication') ||
        detail.contains('permission denied')) {
      return '无法访问仓库，请检查登录凭据和仓库权限后重试。';
    }
    if (detail.contains('not found') || detail.contains('does not appear')) {
      return '无法找到仓库，请检查仓库地址后重试。';
    }
    if (context == _GitContext.commit &&
        (detail.contains('user.email') || detail.contains('user.name'))) {
      return 'Git 尚未设置提交身份，请先在 Git 中配置姓名和邮箱。';
    }
    if (context == _GitContext.sync &&
        detail.contains('not possible to fast-forward')) {
      return '无法安全同步，因为本地历史与远端不一致。请重新初始化目录。';
    }
    return switch (context) {
      _GitContext.commit => '无法创建发布记录，请检查 Git 提交身份后重试。',
      _GitContext.sync => '同步未完成，请检查网络和本地目录后重试。',
      _GitContext.general => '连接仓库失败，请检查网络、地址和 Git 配置后重试。',
    };
  }
}

enum _GitContext { general, commit, sync }

class _RemoteUpdate {
  const _RemoteUpdate({required this.message, required this.changedFiles});

  const _RemoteUpdate.none() : message = null, changedFiles = const <String>[];

  final String? message;
  final List<String> changedFiles;

  bool get hasUpdates => message != null;
}
