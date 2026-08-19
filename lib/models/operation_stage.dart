enum OperationStage {
  idle,
  connecting,
  checking,
  publishing,
  syncing;

  String get label => switch (this) {
    OperationStage.idle => '空闲',
    OperationStage.connecting => '正在连接仓库',
    OperationStage.checking => '正在检查更新',
    OperationStage.publishing => '正在发布更新',
    OperationStage.syncing => '正在同步更新',
  };
}
