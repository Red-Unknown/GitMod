import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/mod_config.dart';
import '../core/user_facing_exception.dart';

abstract interface class AppConfigStore {
  Future<ModConfig?> load();
  Future<void> save(ModConfig config);
  Future<void> clear();
}

class JsonAppConfigStore implements AppConfigStore {
  JsonAppConfigStore(this._file);

  final File _file;

  static Future<JsonAppConfigStore> createDefault() async {
    final directory = await getApplicationSupportDirectory();
    return JsonAppConfigStore(
      File('${directory.path}${Platform.pathSeparator}config.json'),
    );
  }

  @override
  Future<ModConfig?> load() async {
    if (!await _file.exists()) return null;
    try {
      final source = await _file.readAsString(encoding: utf8);
      final decoded = jsonDecode(source);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException();
      }
      return ModConfig.fromJson(decoded);
    } on FormatException {
      throw const UserFacingException('本地配置无法读取，请重置后重新连接。');
    } on FileSystemException {
      throw const UserFacingException('无法读取本地配置，请检查应用数据目录权限。');
    }
  }

  @override
  Future<void> save(ModConfig config) async {
    try {
      await _file.parent.create(recursive: true);
      await _file.writeAsString(
        jsonEncode(config.toJson()),
        encoding: utf8,
        flush: true,
      );
    } on FileSystemException {
      throw const UserFacingException('无法保存本地配置，请检查应用数据目录权限。');
    }
  }

  @override
  Future<void> clear() async {
    try {
      if (await _file.exists()) await _file.delete();
    } on FileSystemException {
      throw const UserFacingException('无法清除本地配置，请检查应用数据目录权限。');
    }
  }
}
