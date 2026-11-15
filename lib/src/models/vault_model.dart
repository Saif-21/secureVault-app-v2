/// Represents an encrypted vault record (password / credential / secure note).
class VaultItem {
  VaultItem({
    required this.id,
    required this.title,
    required this.username,
    required this.password,
    required this.group,
    this.website,
    this.isSynced = false,
  });

  final String id;
  final String title;
  final String username;
  final String password;
  final String group;
  final String? website;
  final bool isSynced;

  VaultItem copyWith({
    String? id,
    String? title,
    String? username,
    String? password,
    String? group,
    String? website,
    bool? isSynced,
  }) {
    return VaultItem(
      id: id ?? this.id,
      title: title ?? this.title,
      username: username ?? this.username,
      password: password ?? this.password,
      group: group ?? this.group,
      website: website ?? this.website,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}

