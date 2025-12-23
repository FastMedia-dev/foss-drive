import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:myapp/features/auth/account_model.dart';
import 'package:googleapis_auth/auth_io.dart';

class AccountService {
  static const _storage = FlutterSecureStorage();
  static const _accountsKey = 'accounts';
  static const _currentAccountKey = 'currentAccount';

  Future<List<Account>> getAccounts() async {
    final String? accountsJson = await _storage.read(key: _accountsKey);
    if (accountsJson != null) {
      try {
        final List<dynamic> jsonList = json.decode(accountsJson);
        return jsonList.map((json) => Account.fromJson(json)).toList();
      } catch (e) {
        print('Error parsing accounts: $e');
        return [];
      }
    } else {
      return [];
    }
  }

  Future<void> _saveAccounts(List<Account> accounts) async {
    final String accountsJson = json.encode(accounts.map((account) => account.toJson()).toList());
    await _storage.write(key: _accountsKey, value: accountsJson);
  }

  Future<Account?> getCurrentAccount() async {
    final String? accountJson = await _storage.read(key: _currentAccountKey);
    if (accountJson != null) {
      try {
        return Account.fromJson(json.decode(accountJson));
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  Future<void> setCurrentAccount(Account account) async {
    await _storage.write(key: _currentAccountKey, value: json.encode(account.toJson()));
  }

  /// Parses the Service Account JSON and adds it as an account.
  /// Returns the newly created Account object.
  Future<Account> addAccountFromCredential(String jsonContent) async {
    try {
      final Map<String, dynamic> creds = json.decode(jsonContent);

      // Basic validation
      if (!creds.containsKey('client_email') || !creds.containsKey('private_key')) {
        throw Exception('Invalid Service Account JSON: Missing client_email or private_key');
      }

      final String email = creds['client_email'];
      final String projectId = creds['project_id'] ?? 'Unknown Project';

      // Generate a deterministic ID based on email
      final String id = email.hashCode.toString();

      // Service accounts don't have profile photos by default,
      // but we can look for one or leave it null (UI will handle generation).
      // We will store the FULL json content to recreate the credentials later.

      final newAccount = Account(
        id: id,
        email: email,
        name: projectId, // Use Project ID as name for Service Account
        credentialJson: jsonContent,
        photoUrl: null, // Will be auto-generated in UI
      );

      List<Account> accounts = await getAccounts();

      // Check if already exists
      final existingIndex = accounts.indexWhere((a) => a.email == email);
      if (existingIndex != -1) {
        accounts[existingIndex] = newAccount; // Update
      } else {
        accounts.add(newAccount);
      }

      await _saveAccounts(accounts);
      await setCurrentAccount(newAccount);

      return newAccount;
    } catch (e) {
      throw Exception('Failed to process credential file: $e');
    }
  }

  Future<void> logout() async {
    await _storage.delete(key: _currentAccountKey);
  }

  /// Returns an authenticated client for the current account
  Future<AutoRefreshingAuthClient?> getAuthenticatedClient() async {
    final account = await getCurrentAccount();
    if (account == null) return null;

    try {
      final creds = ServiceAccountCredentials.fromJson(account.credentialJson);
      final scopes = ['https://www.googleapis.com/auth/drive'];

      final client = await clientViaServiceAccount(creds, scopes);
      return client;
    } catch (e) {
      print('Error creating auth client: $e');
      return null;
    }
  }
}
