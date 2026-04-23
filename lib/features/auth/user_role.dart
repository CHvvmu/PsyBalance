enum UserRole {
  client,
  coach,
  administrator,
}

extension UserRoleMapper on UserRole {
  String get value {
    switch (this) {
      case UserRole.client:
        return 'client';
      case UserRole.coach:
        return 'coach';
      case UserRole.administrator:
        return 'administrator';
    }
  }

  static UserRole? fromValue(String? raw) {
    switch (raw) {
      case 'client':
        return UserRole.client;
      case 'coach':
        return UserRole.coach;
      case 'administrator':
        return UserRole.administrator;
      default:
        return null;
    }
  }
}

