import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:myapp/features/auth/account_model.dart';

class AccountService {
  static const _storage = FlutterSecureStorage();
  static const _accountsKey = 'accounts';
  static const _currentAccountKey = 'currentAccount';

  // Dummy accounts for demonstration
  final List<Account> _dummyAccounts = [
    Account(id: '1', email: 'user1@example.com', name: 'User One'),
    Account(id: '2', email: 'user2@example.com', name: 'User Two'),
  ];

  Future<List<Account>> getAccounts() async {
    final String? accountsJson = await _storage.read(key: _accountsKey);
    if (accountsJson != null) {
      final List<dynamic> jsonList = json.decode(accountsJson);
      return jsonList.map((json) => Account.fromJson(json)).toList();
    } else {
      // If no accounts are stored, save dummy accounts for initial use
      await _saveAccounts(_dummyAccounts);
      return _dummyAccounts;
    }
  }

  Future<void> _saveAccounts(List<Account> accounts) async {
    final String accountsJson = json.encode(accounts.map((account) => account.toJson()).toList());
    await _storage.write(key: _accountsKey, value: accountsJson);
  }

  Future<Account?> getCurrentAccount() async {
    final String? accountJson = await _storage.read(key: _currentAccountKey);
    if (accountJson != null) {
      return Account.fromJson(json.decode(accountJson));
    }
    return null;
  }

  Future<void> setCurrentAccount(Account account) async {
    await _storage.write(key: _currentAccountKey, value: json.encode(account.toJson()));
  }

  // Simulates adding a new account (for dummy purposes)
  Future<void> addAccount(Account newAccount) async {
    List<Account> accounts = await getAccounts();
    accounts.add(newAccount);
    await _saveAccounts(accounts);
  }

  Future<void> login(String email, String password) async {
    // In a real app, this would involve authentication with a backend.
    // For now, we'll just pick a dummy account based on email.
    List<Account> accounts = await getAccounts();
    Account? account = accounts.firstWhere(
      (acc) => acc.email == email,
      orElse: () => throw Exception('Account not found'),
    );
    await setCurrentAccount(account);
  }

  Future<void> logout() async {
    await _storage.delete(key: _currentAccountKey);
  }
}
