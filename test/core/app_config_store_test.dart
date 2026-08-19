import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gitmod/models/mod_config.dart';
import 'package:gitmod/services/app_config_store.dart';

void main() {
  test('配置以 UTF-8 JSON 保存且不包含令牌字段', () async {
    final directory = await Directory.systemTemp.createTemp(
      'gitmod-config-test-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}${Platform.pathSeparator}config.json');
    final store = JsonAppConfigStore(file);
    const config = ModConfig(
      role: ModRole.creator,
      name: '测试模组',
      directoryPath: r'D:\Mod',
      repositoryUrl: 'https://example.com/mod.git',
    );

    await store.save(config);

    expect(utf8.decode(await file.readAsBytes()), contains('测试模组'));
    expect(await store.load(), isNotNull);
    expect((await store.load())!.toJson(), config.toJson());
    expect(await file.readAsString(), isNot(contains('token')));
  });
}
