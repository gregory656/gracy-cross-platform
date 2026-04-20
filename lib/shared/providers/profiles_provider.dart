import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants.dart';
import '../enums/user_role.dart';
import '../mock_data/mock_users.dart';
import '../models/user_model.dart';
import '../services/database_service.dart';

final profilesDirectoryProvider = FutureProvider<List<UserModel>>((ref) async {
  if (!SupabaseConfig.isConfigured) {
    return mockUsers;
  }

  final SupabaseClient? client;
  try {
    client = Supabase.instance.client;
  } catch (_) {
    return mockUsers;
  }

  final String ownerId = client.auth.currentUser?.id ?? '';
  if (ownerId.isEmpty) {
    return mockUsers;
  }

  try {
    final List<dynamic> rows = await client
        .from('profiles')
        .select()
        .order('username')
        .timeout(const Duration(seconds: 3));

    final List<UserModel> profiles = rows
        .map(
          (dynamic row) =>
              _userFromProfile(Map<String, dynamic>.from(row as Map)),
        )
        .toList();

    if (profiles.isNotEmpty) {
      await DatabaseService.instance.cacheProfiles(profiles, ownerId);
      return profiles;
    }
  } catch (_) {
    final List<UserModel> cachedProfiles = await DatabaseService.instance
        .getCachedProfiles(ownerId);
    if (cachedProfiles.isNotEmpty) {
      return cachedProfiles;
    }
  }

  final List<UserModel> cachedProfiles = await DatabaseService.instance
      .getCachedProfiles(ownerId);
  if (cachedProfiles.isNotEmpty) {
    return cachedProfiles;
  }

  return mockUsers;
});

final profileByIdProvider = FutureProvider.family<UserModel?, String>((
  ref,
  String userId,
) async {
  final List<UserModel> profiles = await ref.watch(
    profilesDirectoryProvider.future,
  );
  for (final UserModel profile in profiles) {
    if (profile.id == userId) {
      return profile;
    }
  }
  return null;
});

UserModel _userFromProfile(Map<String, dynamic> row) {
  final String id = row['id']?.toString() ?? '';
  final String username = row['username']?.toString() ?? 'gracyuser';
  final String fullName = row['full_name']?.toString().trim().isNotEmpty == true
      ? row['full_name'].toString()
      : username;
  final String bio = row['bio']?.toString().trim().isNotEmpty == true
      ? row['bio'].toString()
      : 'No bio yet.';
  final String year = row['year_of_study']?.toString().trim().isNotEmpty == true
      ? row['year_of_study'].toString()
      : 'Not set';
  final String? avatarUrl =
      row['avatar_url']?.toString().trim().isNotEmpty == true
      ? row['avatar_url'].toString().trim()
      : null;
  final String? gracyId = row['gracy_id']?.toString().trim().isNotEmpty == true
      ? row['gracy_id'].toString()
      : null;
  final String selectedTheme = row['selected_theme']?.toString() ?? 'midnight';
  final bool notificationsEnabled = row['notifications_enabled'] == true;

  return UserModel(
    id: id,
    fullName: fullName,
    username: username.startsWith('@') ? username : '@$username',
    age: 0,
    role: UserRole.student,
    courses: gracyId == null
        ? const <String>['Gracy member']
        : <String>[gracyId],
    bio: bio,
    isOnline: true,
    location: 'Gracy network',
    avatarSeed: username,
    year: year,
    avatarUrl: avatarUrl,
    gracyId: gracyId,
    selectedTheme: selectedTheme,
    notificationsEnabled: notificationsEnabled,
  );
}
