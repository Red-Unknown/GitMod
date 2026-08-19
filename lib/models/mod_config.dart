enum ModRole { creator, player }

class ModConfig {
  const ModConfig({
    required this.role,
    required this.name,
    required this.directoryPath,
    required this.repositoryUrl,
    this.repositorySubdirectory = '',
  });

  const ModConfig.empty()
    : role = ModRole.player,
      name = '',
      directoryPath = '',
      repositoryUrl = '',
      repositorySubdirectory = '';

  final ModRole role;
  final String name;
  final String directoryPath;
  final String repositoryUrl;

  /// The optional path, relative to [directoryPath], that contains the Mod.
  ///
  /// The value is kept as entered so it can be shown back to the user. Git
  /// operations should use [normalizedRepositorySubdirectory] after checking
  /// [repositorySubdirectoryError].
  final String repositorySubdirectory;

  /// Returns the canonical separator form used by Git pathspecs.
  String get normalizedRepositorySubdirectory =>
      normalizeRepositorySubdirectory(repositorySubdirectory);

  /// Returns a user-facing validation message, or null when the path is valid.
  String? get repositorySubdirectoryError =>
      validateRepositorySubdirectory(repositorySubdirectory);

  /// Normalizes a user-entered repository-relative path for Git and Windows.
  static String normalizeRepositorySubdirectory(String value) {
    var normalized = value.trim().replaceAll('\\', '/');
    while (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }

  /// Validates the optional repository-relative path.
  ///
  /// Empty is intentionally valid for backwards compatibility. Every other
  /// value must be a relative directory and may not traverse outside the
  /// repository or enter Git's metadata directory.
  static String? validateRepositorySubdirectory(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.startsWith('/') ||
        trimmed.startsWith('\\') ||
        RegExp(r'^[A-Za-z]:').hasMatch(trimmed)) {
      return '仓库内 Mod 目录必须是相对目录，不能填写绝对路径或盘符。';
    }
    final normalized = normalizeRepositorySubdirectory(value);
    if (normalized.isEmpty) return null;
    final parts = normalized.split('/');
    if (parts.any((part) => part.isEmpty)) {
      return '仓库内 Mod 目录格式不正确，请使用相对目录。';
    }
    if (parts.any((part) => part == '.' || part == '..')) {
      return '仓库内 Mod 目录不能包含“.”或“..”。';
    }
    if (parts.any((part) => part.toLowerCase() == '.git')) {
      return '仓库内 Mod 目录不能指向 Git 元数据目录。';
    }
    return null;
  }

  bool get isComplete =>
      name.trim().isNotEmpty &&
      directoryPath.trim().isNotEmpty &&
      repositoryUrl.trim().isNotEmpty;

  ModConfig copyWith({
    ModRole? role,
    String? name,
    String? directoryPath,
    String? repositoryUrl,
    String? repositorySubdirectory,
  }) {
    return ModConfig(
      role: role ?? this.role,
      name: name ?? this.name,
      directoryPath: directoryPath ?? this.directoryPath,
      repositoryUrl: repositoryUrl ?? this.repositoryUrl,
      repositorySubdirectory:
          repositorySubdirectory ?? this.repositorySubdirectory,
    );
  }

  Map<String, Object> toJson() => <String, Object>{
    'role': role.name,
    'name': name,
    'directoryPath': directoryPath,
    'repositoryUrl': repositoryUrl,
    'repositorySubdirectory': repositorySubdirectory,
  };

  factory ModConfig.fromJson(Map<String, Object?> json) {
    final roleName = json['role'] as String?;
    final role = switch (roleName) {
      'creator' => ModRole.creator,
      _ => ModRole.player,
    };
    return ModConfig(
      role: role,
      name: json['name'] as String? ?? '',
      directoryPath: json['directoryPath'] as String? ?? '',
      repositoryUrl: json['repositoryUrl'] as String? ?? '',
      repositorySubdirectory: json['repositorySubdirectory'] as String? ?? '',
    );
  }
}
