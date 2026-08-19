import 'package:flutter/material.dart';

import 'controllers/git_mod_controller.dart';
import 'core/directory_picker.dart';
import 'services/app_config_store.dart';
import 'services/git_mod_service.dart';
import 'ui/design_lab_page.dart';
import 'ui/git_mod_app.dart';
import 'ui/theme/app_theme.dart';

Future<void> main(List<String> arguments) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (arguments.contains('--design-lab')) {
    runApp(const _DesignLabApp());
    return;
  }
  final configStore = await JsonAppConfigStore.createDefault();
  final controller = GitModController(
    configStore: configStore,
    gitService: GitCliModService(),
    directoryPicker: const FilePickerDirectoryPicker(),
  );
  await controller.load();
  runApp(GitModApp(controller: controller));
}

class _DesignLabApp extends StatelessWidget {
  const _DesignLabApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GitMod 组件预览',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: const DesignLabPage(),
    );
  }
}
