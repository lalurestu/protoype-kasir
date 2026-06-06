enum UserRole {
  kasir('kasir'),
  owner('owner'),
  superAdmin('super_admin'),
  guest('guest');

  final String value;
  const UserRole(this.value);

  factory UserRole.fromString(String role) {
    return UserRole.values.firstWhere(
      (e) => e.value == role,
      orElse: () => UserRole.guest,
    );
  }
}
