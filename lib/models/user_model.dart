class UserModel {
  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String role;
  final String? profileImagePath;

  UserModel({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.role,
    this.profileImagePath,
  });

  factory UserModel.fromFirestore(Map<String, dynamic> data, String id) {
    return UserModel(
      id: id,
      email: data['email'] ?? '',
      firstName: data['firstName'] ?? '',
      lastName: data['lastName'] ?? '',
      role: data['role'] ?? 'User',
      profileImagePath: data['profileImagePath'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'role': role,
      'profileImagePath': profileImagePath,
    };
  }

  UserModel copyWith({
    String? email,
    String? firstName,
    String? lastName,
    String? role,
    String? profileImagePath,
  }) {
    return UserModel(
      id: this.id,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      role: role ?? this.role,
      profileImagePath: profileImagePath ?? this.profileImagePath,
    );
  }
}

