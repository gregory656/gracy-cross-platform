import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants.dart';
import '../models/stored_account.dart';
import '../models/user_model.dart';
import 'profiles_provider.dart';
import '../services/account_vault.dart';
import '../services/database_service.dart';

class AuthState {
  const AuthState({
    required this.isAuthenticated,
    required this.isLoading,
    required this.isOnboardingComplete,
    required this.isBootstrapping,
    this.userId,
    this.username,
    this.fullName,
    this.bio,
    this.yearOfStudy,
    this.gracyId,
    this.avatarUrl,
    this.errorMessage,
    this.selectedTheme = 'midnight',
    this.notificationsEnabled = true,
    this.isAddingAccount = false,
  });

  final bool isAuthenticated;
  final bool isLoading;
  final bool isOnboardingComplete;
  final bool isBootstrapping;
  final String? userId;
  final String? username;
  final String? fullName;
  final String? bio;
  final String? yearOfStudy;
  final String? gracyId;
  final String? avatarUrl;
  final String? errorMessage;
  final String selectedTheme;
  final bool notificationsEnabled;
  final bool isAddingAccount;

  factory AuthState.initial() {
    return const AuthState(
      isAuthenticated: false,
      isLoading: true,
      isOnboardingComplete: false,
      isBootstrapping: true,
    );
  }

  AuthState copyWith({
    bool? isAuthenticated,
    bool? isLoading,
    bool? isOnboardingComplete,
    bool? isBootstrapping,
    String? userId,
    String? username,
    String? fullName,
    String? bio,
    String? yearOfStudy,
    String? gracyId,
    String? avatarUrl,
    String? errorMessage,
    String? selectedTheme,
    bool? notificationsEnabled,
    bool? isAddingAccount,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      isOnboardingComplete: isOnboardingComplete ?? this.isOnboardingComplete,
      isBootstrapping: isBootstrapping ?? this.isBootstrapping,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      fullName: fullName ?? this.fullName,
      bio: bio ?? this.bio,
      yearOfStudy: yearOfStudy ?? this.yearOfStudy,
      gracyId: gracyId ?? this.gracyId,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      errorMessage: errorMessage,
      selectedTheme: selectedTheme ?? this.selectedTheme,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      isAddingAccount: isAddingAccount ?? this.isAddingAccount,
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
      final DateTime startedAt = DateTime.now();
      bool onboardingComplete = false;

      try {
        onboardingComplete = await DatabaseService.instance
            .isOnboardingComplete()
            .timeout(
              const Duration(milliseconds: 450),
              onTimeout: () => false,
            );
      } catch (_) {
        onboardingComplete = false;
      }

      if (!SupabaseConfig.isConfigured) {
        state = state.copyWith(
          isAuthenticated: onboardingComplete,
          isLoading: false,
          isOnboardingComplete: onboardingComplete,
          isBootstrapping: false,
        );
        return;
      }

      final SupabaseClient? client = _client;
      if (client == null) {
        state = state.copyWith(
          isAuthenticated: onboardingComplete,
          isLoading: false,
          isOnboardingComplete: onboardingComplete,
          isBootstrapping: false,
        );
        return;
      }

      final Session? session = client.auth.currentSession;
      User? user = session?.user;

      if (user == null) {
        final List<StoredAccount> accounts = await AccountVault.instance.readAccounts();
        if (accounts.isNotEmpty) {
          final StoredAccount lastAccount = accounts.first;
          try {
            final AuthResponse res = await client.auth.recoverSession(lastAccount.sessionJson);
            user = res.user;
          } catch (e) {
            debugPrint('Failed to recover session: $e');
          }
        }
      }

      if (user == null) {
        state = state.copyWith(
          isAuthenticated: false,
          isLoading: false,
          isOnboardingComplete: false,
          isBootstrapping: false,
        );
        return;
      }

      final int elapsedMs = DateTime.now().difference(startedAt).inMilliseconds;
      const int minimumSplashMs = 1500;
      if (elapsedMs < minimumSplashMs) {
        await Future<void>.delayed(
          Duration(milliseconds: minimumSplashMs - elapsedMs),
        );
      }
      await _applyAuthenticatedUser(
        user,
        preserveLoading: false,
        preserveAddingAccount: state.isAddingAccount,
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
        isBootstrapping: false,
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
        isBootstrapping: false,
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
        isBootstrapping: false,
        userId: userId,
        username: normalizedUsername,
        fullName: fullName.trim().isEmpty ? null : fullName.trim(),
        bio: bio.trim().isEmpty ? null : bio.trim(),
        yearOfStudy: yearOfStudy.trim().isEmpty ? null : yearOfStudy.trim(),
        gracyId: gracyId,
        isAddingAccount: false,
      );
      await _persistCurrentAccount();
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

  Future<bool> signInWithEmail(String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      if (_client != null) {
        final response = await _client!.auth.signInWithPassword(email: email, password: password);
        return await _verifyAndLoadProfile(response.user);
      }
      return false;
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> signUpWithEmail(String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      if (_client != null) {
        final response = await _client!.auth.signUp(email: email, password: password);
        return await _verifyAndLoadProfile(response.user);
      }
      return false;
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> signInWithSocial(OAuthProvider provider) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      if (_client != null) {
        final success = await _client!.auth.signInWithOAuth(provider);
        if (success) {
           // Provide fallback UI update; deep link will handle the actual _bootstrap reload usually
           return true; 
        }
      }
      return false;
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> _verifyAndLoadProfile(User? user) async {
    if (user == null) {
       state = state.copyWith(isLoading: false, errorMessage: 'User null after auth');
       return false;
    }
    
    // Check if profile exists
    await _applyAuthenticatedUser(user);
    return true;
  }

  Future<void> updateProfile({
    required String fullName,
    required String bio,
    String? avatarUrl,
  }) async {
    final SupabaseClient? client = _client;
    final String? userId = state.userId;
    if (client == null || userId == null) return;

    state = state.copyWith(
      fullName: fullName,
      bio: bio,
      avatarUrl: avatarUrl ?? state.avatarUrl,
    );

    try {
      final Map<String, dynamic> payload = <String, dynamic>{
        'full_name': fullName,
        'bio': bio,
      };
      if (avatarUrl != null) {
        payload['avatar_url'] = avatarUrl;
      }

      await client
          .from('profiles')
          .update(payload)
          .eq('id', userId);
      await _persistCurrentAccount(
        fullNameOverride: fullName,
        avatarUrlOverride: avatarUrl ?? state.avatarUrl,
      );
    } catch (_) {}
  }

  void syncSelectedTheme(String themeName) {
    state = state.copyWith(selectedTheme: themeName);
  }

  void enterAccountAddMode() {
    state = state.copyWith(
      isAddingAccount: true,
      errorMessage: null,
    );
  }

  Future<void> reloadFromCurrentSession() async {
    final SupabaseClient? client = _client;
    final User? user = client?.auth.currentUser;
    if (user == null) {
      state = AuthState.initial().copyWith(
        isLoading: false,
        isBootstrapping: false,
      );
      return;
    }

    await _applyAuthenticatedUser(user, preserveLoading: false);
  }

  Future<void> logout() async {
    final String? activeKey = _activeAccountKey;
    final SupabaseClient? client = _client;
    if (client != null) {
      await client.auth.signOut();
    }
    if (activeKey != null) {
      await AccountVault.instance.removeAccount(activeKey);
    }
    state = AuthState.initial().copyWith(
      isLoading: false,
      isBootstrapping: false,
    );
  }

  Future<void> _applyAuthenticatedUser(
    User user, {
    bool preserveLoading = false,
    bool preserveAddingAccount = false,
  }) async {
    final List<StoredAccount> accounts = await AccountVault.instance.readAccounts();
    final bool hasAccountInVault = accounts.any((a) => a.userId == user.id);
    bool onboardingComplete = hasAccountInVault || await DatabaseService.instance.isOnboardingComplete();
    bool hasProfileRow = false;
    String? fullName;
    String? bio;
    String? yearOfStudy;
    String? gracyId;
    String? avatarUrl;
    String username = user.userMetadata?['username']?.toString() ?? 'gracyuser';
    String selectedTheme = 'midnight';
    bool notificationsEnabled = true;

    try {
      final Map<String, dynamic>? profile = await _client!
          .from('profiles')
          .select(
            'full_name,bio,year_of_study,gracy_id,username,selected_theme,notifications_enabled,avatar_url',
          )
          .eq('id', user.id)
          .maybeSingle()
          .timeout(
            const Duration(milliseconds: 1200),
            onTimeout: () => null,
          );

      if (profile != null) {
        hasProfileRow = true;
        fullName = profile['full_name']?.toString();
        bio = profile['bio']?.toString();
        yearOfStudy = profile['year_of_study']?.toString();
        gracyId = profile['gracy_id']?.toString();
        avatarUrl = profile['avatar_url']?.toString();
        username = profile['username']?.toString() ?? username;
        selectedTheme = profile['selected_theme']?.toString() ?? 'midnight';
        notificationsEnabled = profile['notifications_enabled'] == true;
      }
    } catch (_) {
      // Fall back to auth metadata only if the profile query is unavailable.
    }

    final StoredAccount? currentAccount = accounts.where((a) => a.userId == user.id).firstOrNull;
    if (avatarUrl == null && currentAccount != null) {
      avatarUrl = currentAccount.avatarUrl;
    }

    if (!onboardingComplete) {
      onboardingComplete = hasProfileRow ||
          (gracyId?.trim().isNotEmpty == true) ||
          (fullName?.trim().isNotEmpty == true);
      if (onboardingComplete) {
        await DatabaseService.instance.setOnboardingComplete(true);
      }
    }

    state = state.copyWith(
      isAuthenticated: true,
      isLoading: preserveLoading ? state.isLoading : false,
      isOnboardingComplete: onboardingComplete,
      isBootstrapping: false,
      userId: user.id,
      username: username,
      fullName: fullName,
      bio: bio,
      yearOfStudy: yearOfStudy,
      gracyId: gracyId,
      avatarUrl: avatarUrl,
      selectedTheme: selectedTheme,
      notificationsEnabled: notificationsEnabled,
      isAddingAccount: preserveAddingAccount ? state.isAddingAccount : false,
      errorMessage: null,
    );

    await _persistCurrentAccount();
  }

  Future<void> _persistCurrentAccount({
    String? fullNameOverride,
    String? avatarUrlOverride,
  }) async {
    final SupabaseClient? client = _client;
    final Session? session = client?.auth.currentSession;
    final User? user = session?.user;
    final String? key = _activeAccountKey;
    if (session == null || user == null || key == null) {
      return;
    }

    final String? username = state.username?.trim().isNotEmpty == true
        ? state.username!.trim()
        : user.userMetadata?['username']?.toString();

    final StoredAccount account = StoredAccount(
      key: key,
      sessionJson: jsonEncode(session.toJson()),
      userId: state.userId ?? user.id,
      email: user.email,
      username: username,
      fullName: fullNameOverride ?? state.fullName,
      avatarUrl: avatarUrlOverride ?? state.avatarUrl,
      savedAt: DateTime.now(),
    );
    await AccountVault.instance.upsertAccount(account);
  }

  String? get _activeAccountKey {
    final String? userId = state.userId?.trim();
    if (userId != null && userId.isNotEmpty) {
      return userId;
    }

    final String? email = _client?.auth.currentUser?.email?.trim();
    if (email != null && email.isNotEmpty) {
      return email;
    }

    return null;
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
    avatarUrl: authState.avatarUrl?.trim().isNotEmpty == true
        ? authState.avatarUrl!.trim()
        : null,
    gracyId: authState.gracyId,
    selectedTheme: authState.selectedTheme,
    notificationsEnabled: authState.notificationsEnabled,
  );
});

final resolvedCurrentUserProvider = Provider<UserModel?>((ref) {
  final UserModel? currentUser = ref.watch(currentUserProvider);
  final List<UserModel>? profiles = ref.watch(profilesDirectoryProvider).asData?.value;

  if (currentUser == null) {
    return null;
  }

  if (profiles == null || profiles.isEmpty) {
    return currentUser;
  }

  for (final UserModel profile in profiles) {
    if (profile.id == currentUser.id) {
      return currentUser.copyWith(
        fullName: profile.fullName,
        username: profile.username,
        bio: profile.bio,
        year: profile.year,
        avatarSeed: profile.avatarSeed,
        avatarUrl: profile.avatarUrl ?? currentUser.avatarUrl,
        gracyId: profile.gracyId ?? currentUser.gracyId,
        selectedTheme: profile.selectedTheme,
        notificationsEnabled: profile.notificationsEnabled,
      );
    }
  }

  return currentUser;
});
