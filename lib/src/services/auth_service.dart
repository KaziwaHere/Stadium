import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:stadium/src/appwrite_client.dart';

class AuthService {
  AuthService(this._account);

  final Account _account;

  Future<models.User?> currentUser() async {
    try {
      return await _account.get();
    } on AppwriteException catch (error) {
      if (error.code == 401) return null;
      rethrow;
    }
  }

  Future<models.User> refreshUser() {
    return _account.get();
  }

  Future<models.User> updateName({required String name}) {
    return _account.updateName(name: name);
  }

  Future<models.User> updatePhone({
    required String phone,
    required String password,
  }) async {
    await _account.updatePhone(phone: phone, password: password);
    return _account.updateEmail(
      email: _phoneAuthEmail(phone),
      password: password,
    );
  }

  Future<models.User> updatePassword({
    required String password,
    required String oldPassword,
  }) {
    return _account.updatePassword(
      password: password,
      oldPassword: oldPassword,
    );
  }

  Future<models.User> register({
    required String name,
    required String phone,
    required String password,
  }) async {
    await _account.create(
      userId: ID.unique(),
      email: _phoneAuthEmail(phone),
      password: password,
      name: name,
    );

    await login(phone: phone, password: password);
    return _account.updatePhone(phone: phone, password: password);
  }

  Future<models.User> login({
    required String phone,
    required String password,
  }) async {
    await _account.createEmailPasswordSession(
      email: _phoneAuthEmail(phone),
      password: password,
    );
    return _account.get();
  }

  Future<void> logout() {
    return _account.deleteSession(sessionId: 'current');
  }

  String _phoneAuthEmail(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    return 'p$digits@phone.stadium.app';
  }
}

final AuthService authService = AuthService(Account(client));
