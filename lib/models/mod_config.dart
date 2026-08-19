enum ModRole { creator, player }

class ModConfig {
  const ModConfig({
    required this.role,
    required this.name,
    required this.directoryPath,
    required this.repositoryUrl,
  });

  const ModConfig.empty()
    : role = ModRole.player,
      name = '',
      directoryPath = '',
      repositoryUrl = '';

  final ModRole role;
  final String name;
  final String directoryPath;
  final String repositoryUrl;

  bool get isComplete =>
      name.trim().isNotEmpty &&
      directoryPath.trim().isNotEmpty &&
      repositoryUrl.trim().isNotEmpty;

  ModConfig copyWith({
    ModRole? role,
    String? name,
    String? directoryPath,
    String? repositoryUrl,
  }) {
    return ModConfig(
      role: role ?? this.role,
      name: name ?? this.name,
      directoryPath: directoryPath ?? this.directoryPath,
      repositoryUrl: repositoryUrl ?? this.repositoryUrl,
    );
  }

  Map<String, Object> toJson() => <String, Object>{
    'role': role.name,
    'name': name,
    'directoryPath': directoryPath,
    'repositoryUrl': repositoryUrl,
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
    );
  }
}
