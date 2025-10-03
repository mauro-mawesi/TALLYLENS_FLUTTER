class UserProfile {
  final String id;
  final String? email;
  final String? username;
  final String? firstName;
  final String? lastName;
  final String? profileImageUrl;

  const UserProfile({
    required this.id,
    this.email,
    this.username,
    this.firstName,
    this.lastName,
    this.profileImageUrl,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: (json['id'] ?? '').toString(),
        email: json['email'] as String?,
        username: json['username'] as String?,
        firstName: json['firstName'] as String?,
        lastName: json['lastName'] as String?,
        profileImageUrl: json['profileImageUrl'] as String?,
      );

  String get displayName {
    if (firstName != null && firstName!.trim().isNotEmpty) return firstName!;
    if (username != null && username!.trim().isNotEmpty) return username!;
    return email ?? '';
  }
}

