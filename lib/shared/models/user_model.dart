import 'package:equatable/equatable.dart';

import '../enums/verification_level.dart';
import '../enums/user_role.dart';

class UserModel extends Equatable {
  const UserModel({
    required this.id,
    required this.fullName,
    required this.username,
    this.age = 0,
    this.role = UserRole.student,
    this.courses = const [],
    this.bio = '',
    this.isOnline = false,
    this.isGhostMode = false,
    this.isBlueVerified = false,
    this.isAlumni = false,
    this.verificationLevel,
    this.location = '',
    this.avatarSeed = '',
    this.year = '',
    this.avatarUrl,
    this.gracyId,
    this.selectedTheme = 'midnight',
    this.notificationsEnabled = false,
  });


  final String id;
  final String fullName;
  final String username;
  final int age;
  final UserRole role;
  final List<String> courses;
  final String bio;
  final bool isOnline;
  final bool isGhostMode;
  final bool isBlueVerified;
  final bool isAlumni;
  final VerificationLevel? verificationLevel;
  final String location;
  final String avatarSeed;
  final String year;
  final String? avatarUrl;
  final String? gracyId;
  final String selectedTheme;
  final bool notificationsEnabled;

  String get initials => fullName.isNotEmpty ? fullName[0].toUpperCase() : username[0].toUpperCase();

  UserModel copyWith({
    String? id,
    String? fullName,
    String? username,
    int? age,
    UserRole? role,
    List<String>? courses,
    String? bio,
    bool? isOnline,
    bool? isGhostMode,
    bool? isBlueVerified,
    bool? isAlumni,
    VerificationLevel? verificationLevel,
    String? location,
    String? avatarSeed,
    String? year,
    String? avatarUrl,
    String? gracyId,
    String? selectedTheme,
    bool? notificationsEnabled,
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
      isGhostMode: isGhostMode ?? this.isGhostMode,
      isBlueVerified: isBlueVerified ?? this.isBlueVerified,
      isAlumni: isAlumni ?? this.isAlumni,
      verificationLevel: verificationLevel ?? this.verificationLevel,
      location: location ?? this.location,
      avatarSeed: avatarSeed ?? this.avatarSeed,
      year: year ?? this.year,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      gracyId: gracyId ?? this.gracyId,
      selectedTheme: selectedTheme ?? this.selectedTheme,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    );
  }

@override
  List<Object?> get props => [
    id,
    fullName,
    username,
    age,
    role,
    courses,
    bio,
    isOnline,
    isGhostMode,
    isBlueVerified,
    isAlumni,
    verificationLevel,
    location,
    avatarSeed,
    year,
    avatarUrl,
    gracyId,
    selectedTheme,
    notificationsEnabled,
  ];
}
