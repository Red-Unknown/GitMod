import 'package:file_picker/file_picker.dart';

import 'user_facing_exception.dart';

abstract interface class DirectoryPicker {
  Future<String?> pickDirectory();
}

class FilePickerDirectoryPicker implements DirectoryPicker {
  const FilePickerDirectoryPicker();

  @override
  Future<String?> pickDirectory() async {
    try {
      return await FilePicker.getDirectoryPath(
        dialogTitle: '选择 Mod 目录',
      );
    } catch (_) {
      throw const UserFacingException('无法打开目录选择窗口，请重试。');
    }
  }
}
