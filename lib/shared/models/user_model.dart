enum UserRole { student, alumni, staff }

extension UserRoleLabel on UserRole {
  String get label {
    switch (this) {
      case UserRole.student:
        return 'Student';
      case UserRole.alumni:
        return 'Alumni';
      case UserRole.staff:
        return 'Staff';
    }
  }
}

enum VerificationLevel { none, blueVerified }

extension VerificationLevelLabel on VerificationLevel {
  String get label {
    switch (this) {
      case VerificationLevel.none:
        return 'None';
      case VerificationLevel.blueVerified:
        return 'Blue Verified';
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
    this.gracyId,
    this.selectedTheme = 'dark',
    this.notificationsEnabled = true,
    this.verificationLevel = VerificationLevel.none,
    this.isGhostMode = false,
    this.phone,
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
  final String? gracyId;
  final String selectedTheme;
  final bool notificationsEnabled;
  final VerificationLevel verificationLevel;
  final bool isGhostMode;
  final String? phone;

  String get initials {
    final List<String> parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) {
      return '';
    }
    final String first = parts.first.isNotEmpty ? parts.first[0] : '';
    final String last = parts.length > 1 && parts.last.isNotEmpty
        ? parts.last[0]
        : '';
    return (first + last).toUpperCase();
  }

  bool get isBlueVerified => verificationLevel == VerificationLevel.blueVerified;
  bool get isAlumni => role == UserRole.alumni;

  UserModel copyWith({
    String? id,
    String? fullName,
    String? username,
    int? age,
    UserRole? role,
    List<String>? courses,
    String? bio,
    bool? isOnline,
    String? location,
    String? avatarSeed,
    String? year,
    String? gracyId,
    String? selectedTheme,
    bool? notificationsEnabled,
    VerificationLevel? verificationLevel,
    bool? isGhostMode,
    String? phone,
  }) {
    return UserModel(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      username: username ?? this.username,
      age: age ?? this.age,
      role: role ?? this.role,
      courses: courses ?? this.courses,
      bio: bio ?? this.bio,
      isOnline: isOnline ?? this.isOnline,
      location: location ?? this.location,
      avatarSeed: avatarSeed ?? this.avatarSeed,
      year: year ?? this.year,
      gracyId: gracyId ?? this.gracyId,
      selectedTheme: selectedTheme ?? this.selectedTheme,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      verificationLevel: verificationLevel ?? this.verificationLevel,
      isGhostMode: isGhostMode ?? this.isGhostMode,
      phone: phone ?? this.phone,
    );
  }
}
