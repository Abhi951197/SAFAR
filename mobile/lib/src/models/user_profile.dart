class UserProfile {
  UserProfile({
    required this.id,
    required this.authUserId,
    required this.email,
    this.name,
    this.avatarUrl,
  });

  final String id;
  final String authUserId;
  final String email;
  final String? name;
  final String? avatarUrl;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      authUserId: json['auth_user_id'] as String,
      email: json['email'] as String,
      name: json['name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'auth_user_id': authUserId,
      'email': email,
      'name': name,
      'avatar_url': avatarUrl,
    };
  }
}
