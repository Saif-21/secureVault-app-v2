/// Represents a category folder in SecureVault.
class VaultCategory {
  const VaultCategory({
    required this.id,
    required this.name,
    required this.emoji,
    this.serverId,
    this.isSynced = true,
  });

  final String id;
  final String name;
  final String emoji;
  final String? serverId;
  final bool isSynced;

  VaultCategory copyWith({
    String? id,
    String? name,
    String? emoji,
    String? serverId,
    bool? isSynced,
  }) {
    return VaultCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      serverId: serverId ?? this.serverId,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  factory VaultCategory.fromApiJson(Map<String, dynamic> json) {
    final name = json['name']?.toString() ?? 'General';
    final icon = json['icon']?.toString();
    final serverId = json['_id']?.toString() ?? json['id']?.toString();
    return VaultCategory(
      id: serverId ?? name.toLowerCase().replaceAll(RegExp(r'\s+'), '_'),
      name: name,
      emoji: (icon != null && icon.isNotEmpty) ? icon : '📁',
      serverId: serverId,
      isSynced: true,
    );
  }

  factory VaultCategory.fromJson(Map<String, dynamic> json) {
    return VaultCategory(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      emoji: json['emoji']?.toString() ?? '📁',
      serverId: json['serverId']?.toString(),
      isSynced: json['isSynced'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'emoji': emoji,
    'serverId': serverId,
    'isSynced': isSynced,
  };
}

/// Represents an encrypted vault record (password / credential / secure note).
class VaultItem {
  VaultItem({
    required this.id,
    required this.title,
    required this.username,
    required this.password,
    required this.group,
    this.website,
    this.notes,
    this.iconEmoji,
    DateTime? updatedAt,
    this.serverId,
    this.isSynced = true,
  }) : updatedAt = updatedAt ?? DateTime.now();

  final String id;
  final String title;
  final String username;
  final String password;
  final String group;
  final String? website;
  final String? notes;
  final String? iconEmoji;
  final DateTime updatedAt;
  final String? serverId;
  final bool isSynced;

  String get timeAgoText {
    final now = DateTime.now();
    final diff = now.difference(updatedAt);
    if (diff.inMinutes < 1) return 'Updated just now';
    if (diff.inHours < 1) return 'Updated ${diff.inMinutes}m ago';
    if (diff.inHours < 24) return 'Updated ${diff.inHours} hours ago';
    if (diff.inDays == 1) return 'Updated yesterday';
    return 'Updated ${diff.inDays} days ago';
  }

  /// Returns a clean, user-facing group label, ensuring technical IDs (such as MongoDB ObjectIds) are never displayed.
  String get displayGroup {
    if (RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(group) ||
        group.startsWith('local_') ||
        group.startsWith('vault_') ||
        group.trim().isEmpty) {
      return 'General';
    }
    return group;
  }

  VaultItem copyWith({
    String? id,
    String? title,
    String? username,
    String? password,
    String? group,
    String? website,
    String? notes,
    String? iconEmoji,
    DateTime? updatedAt,
    String? serverId,
    bool? isSynced,
  }) {
    return VaultItem(
      id: id ?? this.id,
      title: title ?? this.title,
      username: username ?? this.username,
      password: password ?? this.password,
      group: group ?? this.group,
      website: website ?? this.website,
      notes: notes ?? this.notes,
      iconEmoji: iconEmoji ?? this.iconEmoji,
      updatedAt: updatedAt ?? this.updatedAt,
      serverId: serverId ?? this.serverId,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  factory VaultItem.fromApiJson(
    Map<String, dynamic> json, {
    List<VaultCategory>? categories,
    String? defaultGroup,
  }) {
    String groupName = defaultGroup ?? 'General';
    if (json['group'] is Map) {
      groupName = json['group']['name']?.toString() ?? groupName;
    } else if (json['group'] is String && (json['group'] as String).isNotEmpty) {
      final rawGroup = json['group'] as String;
      if (categories != null && categories.isNotEmpty) {
        final match = categories.firstWhere(
          (c) =>
              c.serverId == rawGroup ||
              c.id == rawGroup ||
              c.name.toLowerCase() == rawGroup.toLowerCase(),
          orElse: () => const VaultCategory(id: '', name: '', emoji: ''),
        );
        if (match.name.isNotEmpty) {
          groupName = match.name;
        } else if (RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(rawGroup) ||
            rawGroup.startsWith('local_') ||
            rawGroup.startsWith('vault_')) {
          groupName = defaultGroup ?? 'General';
        } else {
          groupName = rawGroup;
        }
      } else if (RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(rawGroup) ||
          rawGroup.startsWith('local_') ||
          rawGroup.startsWith('vault_')) {
        groupName = defaultGroup ?? 'General';
      } else {
        groupName = rawGroup;
      }
    }
    final serverId = json['_id']?.toString() ?? json['id']?.toString();
    return VaultItem(
      id: serverId ?? 'vault_${DateTime.now().millisecondsSinceEpoch}',
      title: json['title']?.toString() ?? 'Untitled',
      username: json['username']?.toString() ?? '',
      password: json['password']?.toString() ?? '',
      group: groupName,
      website: json['website']?.toString(),
      notes: json['notes']?.toString(),
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'].toString()) : null,
      serverId: serverId,
      isSynced: true,
    );
  }

  factory VaultItem.fromJson(Map<String, dynamic> json) {
    return VaultItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      password: json['password']?.toString() ?? '',
      group: json['group']?.toString() ?? 'General',
      website: json['website']?.toString(),
      notes: json['notes']?.toString(),
      iconEmoji: json['iconEmoji']?.toString(),
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'].toString()) : null,
      serverId: json['serverId']?.toString(),
      isSynced: json['isSynced'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'username': username,
    'password': password,
    'group': group,
    'website': website,
    'notes': notes,
    'iconEmoji': iconEmoji,
    'updatedAt': updatedAt.toIso8601String(),
    'serverId': serverId,
    'isSynced': isSynced,
  };
}
