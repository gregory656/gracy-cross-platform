import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/stored_account.dart';

class AccountVault {
  AccountVault._();

  static final AccountVault instance = AccountVault._();

  static const String _vaultKey = 'gracy_account_vault_v1';
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  Future<List<StoredAccount>> readAccounts() async {
    final String? raw = await _storage.read(key: _vaultKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <StoredAccount>[];
    }

    try {
      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      final List<StoredAccount> accounts = decoded
          .whereType<Map<dynamic, dynamic>>()
          .map(
            (Map<dynamic, dynamic> item) => StoredAccount.fromMap(
              Map<String, dynamic>.from(item),
            ),
          )
          .where((StoredAccount account) => account.key.trim().isNotEmpty)
          .toList(growable: true);

      accounts.sort((StoredAccount a, StoredAccount b) {
        final DateTime aDate = a.savedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final DateTime bDate = b.savedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });
      return accounts;
    } catch (_) {
      await _storage.delete(key: _vaultKey);
      return const <StoredAccount>[];
    }
  }

  Future<void> upsertAccount(StoredAccount account) async {
    if (account.key.trim().isEmpty || account.sessionJson.trim().isEmpty) {
      return;
    }

    final List<StoredAccount> currentAccounts = await readAccounts();
    final List<StoredAccount> updated = currentAccounts
        .where((StoredAccount item) => item.key != account.key)
        .toList(growable: true);

    updated.insert(
      0,
      account.copyWith(savedAt: account.savedAt ?? DateTime.now()),
    );
    await _writeAccounts(updated);
  }

  Future<void> removeAccount(String key) async {
    if (key.trim().isEmpty) {
      return;
    }

    final List<StoredAccount> currentAccounts = await readAccounts();
    final List<StoredAccount> updated = currentAccounts
        .where((StoredAccount item) => item.key != key)
        .toList(growable: false);
    await _writeAccounts(updated);
  }

  Future<void> clear() async {
    await _storage.delete(key: _vaultKey);
  }

  Future<void> _writeAccounts(List<StoredAccount> accounts) async {
    final String encoded = jsonEncode(
      accounts.map((StoredAccount account) => account.toMap()).toList(),
    );
    await _storage.write(key: _vaultKey, value: encoded);
  }
}
