import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

import '../core/directory_picker.dart';
import '../core/user_facing_exception.dart';
import '../models/activity_item.dart';
import '../models/mod_config.dart';
import '../models/mod_snapshot.dart';
import '../models/operation_stage.dart';
import '../services/app_config_store.dart';
import '../services/git_mod_service.dart';

class GitModController extends ChangeNotifier {
  GitModController({
    required AppConfigStore configStore,
    required GitModService gitService,
    required DirectoryPicker directoryPicker,
  }) : _configStore = configStore,
       _gitService = gitService,
       _directoryPicker = directoryPicker;

  final AppConfigStore _configStore;
  final GitModService _gitService;
  final DirectoryPicker _directoryPicker;
  final List<ActivityItem> _activity = <ActivityItem>[];

  ModConfig _config = const ModConfig.empty();
  ModSnapshot? _snapshot;
  bool _busy = false;
  String _status = '请先连接 Mod 仓库';
  String? _error;
  OperationStage _operationStage = OperationStage.idle;
  Future<void> Function()? _retryAction;

  ModRole get role => _config.role;
  String get name => _config.name;
  String get directory => _config.directoryPath;
  String get repositoryUrl => _config.repositoryUrl;
  String get repositorySubdirectory => _config.repositorySubdirectory;
  String get modDirectory {
    final subdirectory = _config.normalizedRepositorySubdirectory;
    if (subdirectory.isEmpty) return _config.directoryPath;
    return path.normalize(path.join(_config.directoryPath, subdirectory));
  }

  bool get busy => _busy;
  String get status => _status;
  String? get error => _error;
  OperationStage get operationStage => _operationStage;
  ModSnapshot? get snapshot => _snapshot;
  UnmodifiableListView<ActivityItem> get activity =>
      UnmodifiableListView(_activity);

  Future<void> load() async {
    await _run('读取本地配置', OperationStage.checking, () async {
      final saved = await _configStore.load();
      if (saved == null) {
        _status = '请填写 Mod 信息后连接仓库';
        return;
      }
      _config = saved;
      if (!saved.isComplete) {
        _status = '请补全 Mod 信息后连接仓库';
        return;
      }
      _snapshot = await _gitService.refresh(saved);
      _status = _snapshot!.statusText;
    }, recordSuccess: false);
  }

  Future<void> setRole(ModRole role) =>
      _setConfig(_config.copyWith(role: role));

  Future<void> setName(String name) => _setConfig(_config.copyWith(name: name));

  Future<void> setDirectory(String directory) =>
      _setConfig(_config.copyWith(directoryPath: directory));

  Future<void> setRepositoryUrl(String repositoryUrl) =>
      _setConfig(_config.copyWith(repositoryUrl: repositoryUrl));

  Future<void> setRepositorySubdirectory(String repositorySubdirectory) =>
      _setConfig(
        _config.copyWith(repositorySubdirectory: repositorySubdirectory),
      );

  Future<void> pickDirectory() async {
    if (_busy) return;
    try {
      final directory = await _directoryPicker.pickDirectory();
      if (directory != null) await setDirectory(directory);
    } on UserFacingException catch (exception) {
      _fail('选择目录', exception.message, pickDirectory);
      notifyListeners();
    } catch (_) {
      _fail('选择目录', '无法选择目录，请重试。', pickDirectory);
      notifyListeners();
    }
  }

  Future<void> connect() => _run('连接仓库', OperationStage.connecting, () async {
    _snapshot = await _gitService.connect(_config);
    await _configStore.save(_config);
    _status = _snapshot!.statusText;
  });

  Future<void> refresh() => _run('检查更新', OperationStage.checking, () async {
    _snapshot = await _gitService.refresh(_config);
    _status = _snapshot!.statusText;
  });

  Future<void> publish(String message) {
    if (message.trim().isEmpty) {
      _fail('发布更新', '请填写本次更新说明后再发布。', () => publish(message));
      notifyListeners();
      return Future<void>.value();
    }
    return _run('发布更新', OperationStage.publishing, () async {
      _snapshot = await _gitService.publish(_config, message);
      _status = '发布完成，${_snapshot!.statusText}';
    });
  }

  Future<void> sync() => _run('同步更新', OperationStage.syncing, () async {
    _snapshot = await _gitService.sync(_config);
    _status = '同步完成，${_snapshot!.statusText}';
  });

  Future<void> retry() async {
    final action = _retryAction;
    if (_busy || action == null) return;
    await action();
  }

  Future<void> reset() async {
    if (_busy) return;
    await _run('重置配置', OperationStage.idle, () async {
      await _configStore.clear();
      _config = const ModConfig.empty();
      _snapshot = null;
      _status = '请填写 Mod 信息后连接仓库';
    });
  }

  Future<void> _setConfig(ModConfig config) async {
    if (_busy) return;
    _config = config;
    _snapshot = null;
    _error = null;
    _status = '信息已更新，请连接仓库';
    notifyListeners();
    try {
      await _configStore.save(config);
    } on UserFacingException catch (exception) {
      _fail('保存配置', exception.message, () => _setConfig(config));
    }
  }

  Future<void> _run(
    String title,
    OperationStage stage,
    Future<void> Function() action, {
    bool recordSuccess = true,
  }) async {
    if (_busy) return;
    _busy = true;
    _error = null;
    _retryAction = null;
    _operationStage = stage;
    _status = '$title中...';
    notifyListeners();
    try {
      await action();
      if (recordSuccess) _record(title, _status, true);
    } on UserFacingException catch (exception) {
      _fail(
        title,
        exception.message,
        () => _run(title, stage, action, recordSuccess: recordSuccess),
      );
    } catch (_) {
      _fail(
        title,
        '操作未完成，请检查配置后重试。',
        () => _run(title, stage, action, recordSuccess: recordSuccess),
      );
    } finally {
      _busy = false;
      _operationStage = OperationStage.idle;
      notifyListeners();
    }
  }

  void _fail(String title, String message, Future<void> Function() retry) {
    _error = message;
    _status = message;
    _retryAction = retry;
    _record(title, message, false);
  }

  void _record(String title, String detail, bool success) {
    _activity.insert(
      0,
      ActivityItem(
        occurredAt: DateTime.now(),
        title: title,
        detail: detail,
        success: success,
      ),
    );
  }
}
