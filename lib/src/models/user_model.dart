/// Authenticated user profile data model matching the server UserSchema.
class UserModel {
  const UserModel({
    required this.id,
    required this.name,
    this.email,
    this.mobile,
    this.gender,
    this.isOfflineOnly = false,
  });

  final String id;
  final String name;
  final String? email;
  final String? mobile;
  final String? gender;
  final bool isOfflineOnly;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      name: (json['name'] ?? 'User').toString(),
      email: json['email']?.toString(),
      mobile: json['mobile']?.toString(),
      gender: json['gender']?.toString(),
      isOfflineOnly: json['isOfflineOnly'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'mobile': mobile,
      'gender': gender,
      'isOfflineOnly': isOfflineOnly,
    };
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? mobile,
    String? gender,
    bool? isOfflineOnly,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      mobile: mobile ?? this.mobile,
      gender: gender ?? this.gender,
      isOfflineOnly: isOfflineOnly ?? this.isOfflineOnly,
    );
  }
}
