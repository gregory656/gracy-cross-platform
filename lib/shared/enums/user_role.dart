enum UserRole {
  student,
  alumni,
  faculty,
  staff,
}

extension UserRoleLabel on UserRole {
  String get label => switch (this) {
    UserRole.student => 'Student',
    UserRole.alumni => 'Alumni',
    UserRole.faculty => 'Faculty',
    UserRole.staff => 'Staff',
  };
}

