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

  Future<models.User> register({
    required String name,
    required String email,
    required String password,
  }) async {
    await _account.create(
      userId: ID.unique(),
      email: email,
      password: password,
      name: name,
    );

    await login(email: email, password: password);
    return _account.get();
  }

  Future<models.User> login({
    required String email,
    required String password,
  }) async {
    await _account.createEmailPasswordSession(email: email, password: password);

    return _account.get();
  }

  Future<void> logout() {
    return _account.deleteSession(sessionId: 'current');
  }

  Future<void> sendPasswordRecovery({required String email}) async {
    await _account.createRecovery(
      email: email,
      url: 'https://fra.cloud.appwrite.io',
    );
  }
}

final AuthService authService = AuthService(Account(client));
