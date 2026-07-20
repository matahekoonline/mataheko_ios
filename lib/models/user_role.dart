enum UserRole {
  buyer,
  provider;

  static UserRole fromString(String value) {
    return UserRole.values.firstWhere(
      (r) => r.name == value,
      orElse: () => UserRole.buyer,
    );
  }

  String get label {
    switch (this) {
      case UserRole.buyer:
        return 'Buyer';
      case UserRole.provider:
        return 'Service Provider';
    }
  }
}
