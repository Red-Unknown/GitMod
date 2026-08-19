import 'mod_config.dart';

class ModSnapshot {
  const ModSnapshot({
    required this.config,
    required this.isConnected,
    required this.hasUpdates,
    required this.hasLocalChanges,
    required this.localVersion,
    required this.remoteUpdateMessage,
    required this.pendingUpdateFiles,
    required this.localChangedFiles,
  });

  final ModConfig config;
  final bool isConnected;
  final bool hasUpdates;
  final bool hasLocalChanges;
  final String localVersion;
  final String? remoteUpdateMessage;
  final List<String> pendingUpdateFiles;
  final List<String> localChangedFiles;

  List<String> get changedFiles => <String>{
    ...pendingUpdateFiles,
    ...localChangedFiles,
  }.toList(growable: false);

  int get changedFileCount => changedFiles.length;

  String get statusText {
    if (!isConnected) return '尚未连接';
    if (hasLocalChanges) return '检测到本地改动';
    if (hasUpdates) return '发现可同步的更新';
    return '已是最新状态';
  }
}
