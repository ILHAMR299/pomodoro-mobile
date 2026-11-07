class UserModel {
  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.passwordHash,
    required this.passwordSalt,
    required this.createdAt,
  });

  final int id;
  final String name;
  final String email;
  final String passwordHash;
  final String passwordSalt;
  final String createdAt;

  factory UserModel.fromMap(Map<String, Object?> map) => UserModel(
    id: map['id'] as int,
    name: map['name'] as String,
    email: map['email'] as String,
    passwordHash: map['password_hash'] as String,
    passwordSalt: map['password_salt'] as String,
    createdAt: map['created_at'] as String,
  );
}
