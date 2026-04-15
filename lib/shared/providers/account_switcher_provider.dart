import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/chat/providers/chat_providers.dart';
import '../../features/home/providers/post_providers.dart';
import '../models/stored_account.dart';
import '../providers/auth_provider.dart' as app_auth;
import '../providers/profiles_provider.dart';
import '../services/account_vault.dart';

final accountVaultProvider = Provider<AccountVault>((ref) {
  return AccountVault.instance;
});

final savedAccountsProvider = FutureProvider<List<StoredAccount>>((ref) async {
  return ref.watch(accountVaultProvider).readAccounts();
});

final switchableAccountsProvider = FutureProvider<List<StoredAccount>>((
  ref,
) async {
  final List<StoredAccount> savedAccounts = await ref.watch(
    savedAccountsProvider.future,
  );
  final app_auth.AuthState authState = ref.watch(
    app_auth.authNotifierProvider,
  );
  final SupabaseClient? client = _readClient();
  final Session? currentSession = client?.auth.currentSession;

  final StoredAccount? activeAccount = currentSession == null
      ? null
      : _buildStoredAccount(
          session: currentSession,
          authState: authState,
        );

  final Map<String, StoredAccount> accountsByKey = <String, StoredAccount>{};
  if (activeAccount != null) {
    accountsByKey[activeAccount.key] = activeAccount;
  }
  for (final StoredAccount account in savedAccounts) {
    accountsByKey.putIfAbsent(account.key, () => account);
  }

  return accountsByKey.values.toList(growable: false);
});

final accountSwitcherControllerProvider =
    NotifierProvider<AccountSwitcherController, AccountSwitcherState>(
      AccountSwitcherController.new,
    );

class AccountSwitcherState {
  const AccountSwitcherState({
    this.isSwitching = false,
    this.statusMessage,
  });

  final bool isSwitching;
  final String? statusMessage;

  AccountSwitcherState copyWith({
    bool? isSwitching,
    String? statusMessage,
  }) {
    return AccountSwitcherState(
      isSwitching: isSwitching ?? this.isSwitching,
      statusMessage: statusMessage ?? this.statusMessage,
    );
  }
}

class AccountSwitchResult {
  const AccountSwitchResult({
    required this.success,
    this.message,
    this.expired = false,
  });

  final bool success;
  final String? message;
  final bool expired;
}

class AccountSwitcherController extends Notifier<AccountSwitcherState> {
  @override
  AccountSwitcherState build() {
    return const AccountSwitcherState();
  }

  Future<void> saveAndSwitchToLogin() async {
    state = const AccountSwitcherState(
      isSwitching: true,
      statusMessage: 'Securing current account...',
    );

    try {
      await _storeCurrentSession();
      ref.invalidate(savedAccountsProvider);
      ref.invalidate(switchableAccountsProvider);
    } finally {
      state = const AccountSwitcherState();
    }
  }

  Future<AccountSwitchResult> switchToAccount(StoredAccount account) async {
    final SupabaseClient? client = _readClient();
    if (client == null) {
      return const AccountSwitchResult(
        success: false,
        message: 'Supabase is not configured for account switching yet.',
      );
    }

    state = const AccountSwitcherState(
      isSwitching: true,
      statusMessage: 'Switching account...',
    );

    try {
      await _storeCurrentSession();
      await client.auth.recoverSession(account.sessionJson);
      await ref
          .read(app_auth.authNotifierProvider.notifier)
          .reloadFromCurrentSession();
      await _storeCurrentSession();
      await _refreshUserScopedData();
      ref.invalidate(savedAccountsProvider);
      ref.invalidate(switchableAccountsProvider);

      return AccountSwitchResult(
        success: true,
        message: 'Switched to ${account.displayName}.',
      );
    } on AuthException {
      await ref.read(accountVaultProvider).removeAccount(account.key);
      ref.invalidate(savedAccountsProvider);
      ref.invalidate(switchableAccountsProvider);
      return const AccountSwitchResult(
        success: false,
        expired: true,
        message: 'That saved session expired. Please log in again.',
      );
    } catch (error) {
      return AccountSwitchResult(
        success: false,
        message: error.toString(),
      );
    } finally {
      state = const AccountSwitcherState();
    }
  }

  Future<void> _storeCurrentSession() async {
    final SupabaseClient? client = _readClient();
    final Session? session = client?.auth.currentSession;
    final app_auth.AuthState authState = ref.read(
      app_auth.authNotifierProvider,
    );
    if (session == null) {
      return;
    }

    final StoredAccount account = _buildStoredAccount(
      session: session,
      authState: authState,
    );
    await ref.read(accountVaultProvider).upsertAccount(account);
  }

  Future<void> _refreshUserScopedData() async {
    ref.invalidate(postsProvider);
    ref.invalidate(profilesDirectoryProvider);
    ref.invalidate(savedAccountsProvider);
    ref.invalidate(switchableAccountsProvider);
    ref.invalidate(recentChatsProvider);

    try {
      await Future.wait<Object?>(<Future<Object?>>[
        ref.read(profilesDirectoryProvider.future),
        ref.read(postsProvider.future),
      ]);
    } catch (_) {
      // The individual screens will surface their own loading or error states.
    }
  }
}

StoredAccount _buildStoredAccount({
  required Session session,
  required app_auth.AuthState authState,
}) {
  final User user = session.user;
  final String? email = user.email?.trim();
  final String? metadataUsername =
      user.userMetadata?['username']?.toString().trim();
  final String? authUsername = authState.username?.trim();
  final String? username = authUsername?.isNotEmpty == true
      ? authUsername
      : metadataUsername?.isNotEmpty == true
          ? metadataUsername
          : null;
  final String key = authState.userId?.trim().isNotEmpty == true
      ? authState.userId!.trim()
      : email?.isNotEmpty == true
          ? email!
          : user.id;

  return StoredAccount(
    key: key,
    sessionJson: jsonEncode(session.toJson()),
    userId: authState.userId ?? user.id,
    email: email,
    username: username,
    fullName: authState.fullName,
    avatarUrl: authState.avatarUrl,
    savedAt: DateTime.now(),
  );
}

SupabaseClient? _readClient() {
  try {
    return Supabase.instance.client;
  } catch (_) {
    return null;
  }
}
