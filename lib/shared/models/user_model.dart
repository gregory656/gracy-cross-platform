enum UserRole { student, alumni }

extension UserRoleLabel on UserRole {
  String get label {
    switch (this) {
      case UserRole.student:
        return 'Student';
      case UserRole.alumni:
        return 'Alumni';
    }
  }
}

class UserModel {
  const UserModel({
    required this.id,
    required this.fullName,
    required this.username,
    required this.age,
    required this.role,
    required this.courses,
    required this.bio,
    required this.isOnline,
    required this.location,
    required this.avatarSeed,
    required this.year,
  });

  final String id;
  final String fullName;
  final String username;
  final int age;
  final UserRole role;
  final List<String> courses;
  final String bio;
  final bool isOnline;
  final String location;
  final String avatarSeed;
  final String year;

  String get initials {
    final List<String> parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) {
      return '';
    }
    final String first = parts.first.isNotEmpty ? parts.first[0] : '';
    final String last = parts.length > 1 && parts.last.isNotEmpty ? parts.last[0] : '';
    return (first + last).toUpperCase();
  }
}

