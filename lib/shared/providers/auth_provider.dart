import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants.dart';
import '../models/user_model.dart';
import '../services/database_service.dart';

class AuthState {
  const AuthState({
    required this.isAuthenticated,
    required this.isLoading,
    required this.isOnboardingComplete,
    this.userId,
    this.username,
    this.fullName,
    this.bio,
    this.yearOfStudy,
    this.gracyId,
    this.errorMessage,
    this.selectedTheme = 'midnight',
    this.notificationsEnabled = true,
  });

  final bool isAuthenticated;
  final bool isLoading;
  final bool isOnboardingComplete;
  final String? userId;
  final String? username;
  final String? fullName;
  final String? bio;
  final String? yearOfStudy;
  final String? gracyId;
  final String? errorMessage;
  final String selectedTheme;
  final bool notificationsEnabled;

  factory AuthState.initial() {
    return const AuthState(
      isAuthenticated: false,
      isLoading: false,
      isOnboardingComplete: false,
    );
  }

  AuthState copyWith({
    bool? isAuthenticated,
    bool? isLoading,
    bool? isOnboardingComplete,
    String? userId,
    String? username,
    String? fullName,
    String? bio,
    String? yearOfStudy,
    String? gracyId,
    String? errorMessage,
    String? selectedTheme,
    bool? notificationsEnabled,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      isOnboardingComplete: isOnboardingComplete ?? this.isOnboardingComplete,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      fullName: fullName ?? this.fullName,
      bio: bio ?? this.bio,
      yearOfStudy: yearOfStudy ?? this.yearOfStudy,
      gracyId: gracyId ?? this.gracyId,
      errorMessage: errorMessage,
      selectedTheme: selectedTheme ?? this.selectedTheme,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    );
  }
}

final authNotifierProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    Future<void>.microtask(_bootstrap);
    return AuthState.initial();
  }

  SupabaseClient? get _client {
    if (!SupabaseConfig.isConfigured) {
      return null;
    }

    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  void _bootstrap() {
    Future<void>(() async {
      bool onboardingComplete = false;

      try {
        onboardingComplete = await DatabaseService.instance
            .isOnboardingComplete();
      } catch (_) {
        onboardingComplete = false;
      }

      if (!SupabaseConfig.isConfigured) {
        state = state.copyWith(
          isAuthenticated: onboardingComplete,
          isLoading: false,
          isOnboardingComplete: onboardingComplete,
        );
        return;
      }

      final SupabaseClient? client = _client;
      if (client == null) {
        state = state.copyWith(
          isAuthenticated: onboardingComplete,
          isLoading: false,
          isOnboardingComplete: onboardingComplete,
        );
        return;
      }

      final Session? session = client.auth.currentSession;
      final User? user = session?.user;

      if (user == null) {
        state = state.copyWith(
          isAuthenticated: onboardingComplete,
          isLoading: false,
          isOnboardingComplete: onboardingComplete,
        );
        return;
      }

      String? fullName;
      String? bio;
      String? yearOfStudy;
      String? gracyId;
      String selectedTheme = 'midnight';
      bool notificationsEnabled = true;

      try {
        final Map<String, dynamic>? profile = await client
            .from('profiles')
            .select(
              'full_name,bio,year_of_study,gracy_id,username,selected_theme,notifications_enabled',
            )
            .eq('id', user.id)
            .maybeSingle();

        if (profile != null) {
          fullName = profile['full_name']?.toString();
          bio = profile['bio']?.toString();
          yearOfStudy = profile['year_of_study']?.toString();
          gracyId = profile['gracy_id']?.toString();
          selectedTheme = profile['selected_theme']?.toString() ?? 'midnight';
          notificationsEnabled = profile['notifications_enabled'] == true;
        }
      } catch (_) {
        // If the profile row is unavailable, fall back to auth metadata only.
      }

      state = state.copyWith(
        isAuthenticated: onboardingComplete,
        isLoading: false,
        isOnboardingComplete: onboardingComplete,
        userId: user.id,
        username: user.userMetadata?['username']?.toString(),
        fullName: fullName,
        bio: bio,
        yearOfStudy: yearOfStudy,
        gracyId: gracyId,
        selectedTheme: selectedTheme,
        notificationsEnabled: notificationsEnabled,
      );
      debugPrint(
        'Auth bootstrap: session=true onboardingComplete=$onboardingComplete userId=${user.id}',
      );
    });
  }

  Future<bool> completeOnboarding({
    required String username,
    required String fullName,
    required String bio,
    required String yearOfStudy,
    required String gracyId,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final String normalizedUsername = _normalizeUsername(username);

      if (!SupabaseConfig.isConfigured) {
        await DatabaseService.instance.initialize();
        await DatabaseService.instance.setOnboardingComplete(true);

        state = state.copyWith(
          isAuthenticated: true,
          isLoading: false,
          isOnboardingComplete: true,
          userId: 'gracy-$normalizedUsername',
          username: normalizedUsername,
          fullName: fullName.trim().isEmpty ? null : fullName.trim(),
          bio: bio.trim().isEmpty ? null : bio.trim(),
          yearOfStudy: yearOfStudy.trim().isEmpty ? null : yearOfStudy.trim(),
          gracyId: gracyId,
        );
        debugPrint('Auth complete: local fallback authenticated=true');
        return true;
      }

      final SupabaseClient? client = _client;
      if (client == null) {
        await DatabaseService.instance.initialize();
        await DatabaseService.instance.setOnboardingComplete(true);

        state = state.copyWith(
          isAuthenticated: true,
          isLoading: false,
          isOnboardingComplete: true,
          userId: 'gracy-$normalizedUsername',
          username: normalizedUsername,
          fullName: fullName.trim().isEmpty ? null : fullName.trim(),
          bio: bio.trim().isEmpty ? null : bio.trim(),
          yearOfStudy: yearOfStudy.trim().isEmpty ? null : yearOfStudy.trim(),
          gracyId: gracyId,
        );
        debugPrint('Auth complete: fallback client authenticated=true');
        return true;
      }

      final AuthResponse response = await client.auth.signInAnonymously(
        data: <String, dynamic>{'username': normalizedUsername},
      );

      final User? user = response.user ?? client.auth.currentUser;
      final String userId = user?.id ?? normalizedUsername;
      await client.from('profiles').upsert(<String, dynamic>{
        'id': userId,
        'username': normalizedUsername,
        'full_name': fullName.trim(),
        'bio': bio.trim(),
        'year_of_study': yearOfStudy.trim(),
        'gracy_id': gracyId,
      }, onConflict: 'id');

      await DatabaseService.instance.setOnboardingComplete(true);

      state = state.copyWith(
        isAuthenticated: true,
        isLoading: false,
        isOnboardingComplete: true,
        userId: userId,
        username: normalizedUsername,
        fullName: fullName.trim().isEmpty ? null : fullName.trim(),
        bio: bio.trim().isEmpty ? null : bio.trim(),
        yearOfStudy: yearOfStudy.trim().isEmpty ? null : yearOfStudy.trim(),
        gracyId: gracyId,
      );
      debugPrint('Auth complete: authenticated=true userId=$userId');
      return true;
    } on AuthException catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.message);
      return false;
    } catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.toString());
      return false;
    }
  }

  String _normalizeUsername(String username) {
    final String cleaned = username.trim().toLowerCase();
    final String handle = cleaned.startsWith('@')
        ? cleaned.substring(1)
        : cleaned;
    final String safeHandle = handle.replaceAll(RegExp(r'[^a-z0-9._-]'), '');
    return safeHandle.isEmpty ? 'gracyuser' : safeHandle;
  }

  Future<void> updateProfile({
    required String fullName,
    required String bio,
  }) async {
    final SupabaseClient? client = _client;
    final String? userId = state.userId;
    if (client == null || userId == null) return;

    state = state.copyWith(fullName: fullName, bio: bio);

    try {
      await client
          .from('profiles')
          .update(<String, dynamic>{'full_name': fullName, 'bio': bio})
          .eq('id', userId);
    } catch (_) {}
  }

  Future<void> logout() async {
    final SupabaseClient? client = _client;
    if (client != null) {
      await client.auth.signOut();
    }
    state = AuthState.initial();
  }
}

final currentUserProvider = Provider<UserModel?>((ref) {
  final AuthState authState = ref.watch(authNotifierProvider);
  if (!authState.isOnboardingComplete || authState.userId == null) {
    return null;
  }

  return UserModel(
    id: authState.userId!,
    fullName: authState.fullName?.trim().isNotEmpty == true
        ? authState.fullName!.trim()
        : 'Gracy User',
    username: authState.username?.trim().isNotEmpty == true
        ? '@${authState.username!.trim()}'
        : '@gracyuser',
    age: 0,
    role: UserRole.student,
    courses: const <String>[],
    bio: authState.bio?.trim().isNotEmpty == true
        ? authState.bio!.trim()
        : 'No bio yet.',
    isOnline: true,
    location: 'Private',
    avatarSeed: authState.username?.trim().isNotEmpty == true
        ? authState.username!.trim()
        : 'GR',
    year: authState.yearOfStudy?.trim().isNotEmpty == true
        ? authState.yearOfStudy!.trim()
        : 'Not set',
    gracyId: authState.gracyId,
    selectedTheme: authState.selectedTheme,
    notificationsEnabled: authState.notificationsEnabled,
  );
});
