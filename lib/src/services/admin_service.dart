import 'dart:convert';

import 'package:appwrite/appwrite.dart';
import 'package:stadium/src/appwrite_client.dart';

class AdminService {
  AdminService(this._functions, this._account);

  static const functionId = 'admin-users';
  static const Duration _usersCacheTtl = Duration(seconds: 45);

  final Functions _functions;
  final Account _account;
  DateTime? _usersCacheTimestamp;
  List<AdminUser>? _usersCache;

  Future<List<AdminUser>> listUsers({bool forceRefresh = false}) async {
    final now = DateTime.now();
    if (!forceRefresh &&
        _usersCache != null &&
        _usersCacheTimestamp != null &&
        now.difference(_usersCacheTimestamp!) <= _usersCacheTtl) {
      return List<AdminUser>.unmodifiable(_usersCache!);
    }

    // Get current user to pass to function
    final user = await _account.get();
    final body = jsonEncode({'userId': user.$id});

    final execution = await _functions.createExecution(
      functionId: functionId,
      body: body,
      xasync: false,
    );

    if (execution.responseStatusCode < 200 ||
        execution.responseStatusCode >= 300) {
      throw AdminServiceException(
        execution.responseBody.isEmpty
            ? 'Could not load users.'
            : execution.responseBody,
      );
    }

    final decoded = jsonDecode(execution.responseBody);
    if (decoded is! Map<String, dynamic>) {
      throw const AdminServiceException('Invalid admin response.');
    }

    final users = decoded['users'];
    if (users is! List) {
      throw const AdminServiceException('Admin response is missing users.');
    }

    final parsedUsers = users
        .whereType<Map<String, dynamic>>()
        .map(AdminUser.fromMap)
        .toList();

    _usersCache = parsedUsers;
    _usersCacheTimestamp = now;

    return List<AdminUser>.unmodifiable(parsedUsers);
  }

  void clearUsersCache() {
    _usersCache = null;
    _usersCacheTimestamp = null;
  }

  Future<void> promoteUserToAdmin(String targetUserId) async {
    await _executeAdminAction({
      'action': 'promote',
      'targetUserId': targetUserId,
      'role': 'admin',
    });
  }

  Future<void> promoteUserToManager(String targetUserId) async {
    await _executeAdminAction({
      'action': 'promote',
      'targetUserId': targetUserId,
      'role': 'manager',
    });
  }

  Future<void> demoteUserFromAdmin(String targetUserId) async {
    await _executeAdminAction({
      'action': 'revoke',
      'targetUserId': targetUserId,
      'role': 'admin',
    });
  }

  Future<void> demoteUserFromManager(String targetUserId) async {
    await _executeAdminAction({
      'action': 'revoke',
      'targetUserId': targetUserId,
      'role': 'manager',
    });
  }

  Future<void> demoteUser(String targetUserId) async {
    await _executeAdminAction({
      'action': 'demote',
      'targetUserId': targetUserId,
    });
  }

  Future<void> deleteUser(String targetUserId) async {
    await _executeAdminAction({
      'action': 'delete',
      'targetUserId': targetUserId,
    });
  }

  Future<void> _executeAdminAction(Map<String, dynamic> actionPayload) async {
    final user = await _account.get();
    final body = jsonEncode({'userId': user.$id, ...actionPayload});

    final execution = await _functions.createExecution(
      functionId: functionId,
      body: body,
      xasync: false,
    );

    if (execution.responseStatusCode < 200 ||
        execution.responseStatusCode >= 300) {
      throw AdminServiceException(
        execution.responseBody.isEmpty
            ? 'Admin action failed.'
            : execution.responseBody,
      );
    }

    clearUsersCache();
  }
}

class AdminUser {
  const AdminUser({
    required this.id,
    required this.name,
    required this.email,
    required this.roles,
    required this.status,
  });

  final String id;
  final String name;
  final String email;
  final List<String> roles;
  final bool status;

  factory AdminUser.fromMap(Map<String, dynamic> map) {
    final roles = map['roles'] ?? map['labels'] ?? const [];

    return AdminUser(
      id: (map['id'] ?? map['\$id'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      email: (map['email'] ?? '').toString(),
      roles: roles is List ? roles.map((role) => role.toString()).toList() : [],
      status: map['status'] is bool ? map['status'] as bool : true,
    );
  }

  String get displayName => name.trim().isEmpty ? 'Unnamed user' : name;
  String get displayRoles => roles.isEmpty ? 'user' : roles.join(', ');
}

class AdminServiceException implements Exception {
  const AdminServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

final AdminService adminService = AdminService(
  Functions(client),
  Account(client),
);
