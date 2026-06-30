import 'dart:async';
import 'dart:convert';

import 'package:appwrite/appwrite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stadium/src/appwrite_client.dart';

class AdminService {
  AdminService(this._functions, this._account, this._realtime);

  static const functionId = 'admin-users';
  static const Duration _usersCacheTtl = Duration(seconds: 45);
  static const _usersCacheKey = 'admin_users_cache_v1';
  static const _usersCacheTimestampKey = 'admin_users_cache_timestamp_v1';

  final Functions _functions;
  final Account _account;
  final Realtime _realtime;
  final StreamController<AdminUsersSnapshot> _usersController =
      StreamController<AdminUsersSnapshot>.broadcast();

  DateTime? _usersCacheTimestamp;
  List<AdminUser>? _usersCache;
  Future<void>? _cacheLoadFuture;
  Future<List<AdminUser>>? _refreshFuture;
  RealtimeSubscription? _usersSubscription;
  int _ignoredFunctionExecutionEvents = 0;

  Stream<AdminUsersSnapshot> watchUsers({bool forceRefresh = false}) {
    _ensureUsersSubscription();
    _ensureCachedUsersLoaded()
        .then((_) {
          final users = _usersCache;
          if (users != null) {
            _emitUsers(isRefreshing: true, isFromCache: true);
          }

          refreshUsers(forceRefresh: true);
        })
        .catchError((Object error, StackTrace stackTrace) {
          _usersController.addError(error, stackTrace);
        });

    return _usersController.stream;
  }

  Future<void> preloadUsers() async {
    await _ensureCachedUsersLoaded();
    await refreshUsers(forceRefresh: true);
  }

  Future<List<AdminUser>> listUsers({bool forceRefresh = false}) async {
    await _ensureCachedUsersLoaded();

    final now = DateTime.now();
    if (!forceRefresh &&
        _usersCache != null &&
        _usersCacheTimestamp != null &&
        now.difference(_usersCacheTimestamp!) <= _usersCacheTtl) {
      return List<AdminUser>.unmodifiable(_usersCache!);
    }

    return refreshUsers(forceRefresh: forceRefresh);
  }

  Future<List<AdminUser>> refreshUsers({bool forceRefresh = true}) async {
    await _ensureCachedUsersLoaded();

    final now = DateTime.now();
    if (!forceRefresh &&
        _usersCache != null &&
        _usersCacheTimestamp != null &&
        now.difference(_usersCacheTimestamp!) <= _usersCacheTtl) {
      _emitUsers(isRefreshing: false, isFromCache: true);
      return List<AdminUser>.unmodifiable(_usersCache!);
    }

    final existingRefresh = _refreshFuture;
    if (existingRefresh != null) return existingRefresh;

    final refresh = _fetchUsers();
    _refreshFuture = refresh;

    return refresh.whenComplete(() {
      _refreshFuture = null;
    });
  }

  Future<List<AdminUser>> _fetchUsers() async {
    await _ensureCachedUsersLoaded();
    _emitUsers(isRefreshing: true, isFromCache: _usersCache != null);

    try {
      final user = await _account.get();
      final body = jsonEncode({'userId': user.$id});

      _ignoreNextFunctionExecutionEvent();
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

      await _setUsersCache(parsedUsers);
      _emitUsers(isRefreshing: false, isFromCache: false);

      return List<AdminUser>.unmodifiable(parsedUsers);
    } catch (error, stackTrace) {
      final cachedUsers = _usersCache;
      if (cachedUsers != null) {
        _emitUsers(
          isRefreshing: false,
          isFromCache: true,
          errorMessage: error.toString(),
        );
        return List<AdminUser>.unmodifiable(cachedUsers);
      }

      _usersController.addError(error, stackTrace);
      rethrow;
    }
  }

  Future<void> _ensureCachedUsersLoaded() {
    return _cacheLoadFuture ??= _loadCachedUsers();
  }

  Future<void> _loadCachedUsers() async {
    final preferences = await SharedPreferences.getInstance();
    final rawUsers = preferences.getString(_usersCacheKey);
    final timestamp = preferences.getInt(_usersCacheTimestampKey);

    if (rawUsers == null || timestamp == null) return;

    try {
      final decoded = jsonDecode(rawUsers);
      if (decoded is! List) return;

      _usersCache = decoded
          .whereType<Map<String, dynamic>>()
          .map(AdminUser.fromMap)
          .toList();
      _usersCacheTimestamp = DateTime.fromMillisecondsSinceEpoch(timestamp);
    } catch (_) {
      await preferences.remove(_usersCacheKey);
      await preferences.remove(_usersCacheTimestampKey);
    }
  }

  Future<void> _setUsersCache(List<AdminUser> users) async {
    _usersCache = List<AdminUser>.unmodifiable(users);
    _usersCacheTimestamp = DateTime.now();
    unawaited(
      _persistUsersCache(users, _usersCacheTimestamp!).catchError((_) {}),
    );
  }

  Future<void> _persistUsersCache(
    List<AdminUser> users,
    DateTime timestamp,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _usersCacheKey,
      jsonEncode(users.map((user) => user.toMap()).toList()),
    );
    await preferences.setInt(
      _usersCacheTimestampKey,
      timestamp.millisecondsSinceEpoch,
    );
  }

  void _emitUsers({
    required bool isRefreshing,
    required bool isFromCache,
    String? errorMessage,
  }) {
    final users = _usersCache;
    if (users == null) return;

    _usersController.add(
      AdminUsersSnapshot(
        users: List<AdminUser>.unmodifiable(users),
        isRefreshing: isRefreshing,
        isFromCache: isFromCache,
        errorMessage: errorMessage,
      ),
    );
  }

  void _ensureUsersSubscription() {
    if (_usersSubscription != null) return;

    _usersSubscription = _realtime.subscribe([
      'functions.$functionId.executions',
    ]);
    _usersSubscription?.stream.listen((_) {
      if (_ignoredFunctionExecutionEvents > 0) {
        _ignoredFunctionExecutionEvents--;
        return;
      }

      refreshUsers(forceRefresh: true);
    });
  }

  void clearUsersCache() {
    _usersCache = null;
    _usersCacheTimestamp = null;
    SharedPreferences.getInstance().then((preferences) {
      preferences.remove(_usersCacheKey);
      preferences.remove(_usersCacheTimestampKey);
    });
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

    _ignoreNextFunctionExecutionEvent();
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

    await refreshUsers(forceRefresh: true);
  }

  void _ignoreNextFunctionExecutionEvent() {
    if (_usersSubscription == null) return;

    _ignoredFunctionExecutionEvents++;
    Timer(const Duration(seconds: 5), () {
      if (_ignoredFunctionExecutionEvents > 0) {
        _ignoredFunctionExecutionEvents--;
      }
    });
  }
}

class AdminUsersSnapshot {
  const AdminUsersSnapshot({
    required this.users,
    required this.isRefreshing,
    required this.isFromCache,
    this.errorMessage,
  });

  final List<AdminUser> users;
  final bool isRefreshing;
  final bool isFromCache;
  final String? errorMessage;
}

class AdminUser {
  const AdminUser({
    required this.id,
    required this.name,
    required this.phone,
    this.profilePictureId,
    required this.roles,
    required this.status,
  });

  final String id;
  final String name;
  final String phone;
  final String? profilePictureId;
  final List<String> roles;
  final bool status;

  factory AdminUser.fromMap(Map<String, dynamic> map) {
    final roles = map['roles'] ?? map['labels'] ?? const [];

    return AdminUser(
      id: (map['id'] ?? map['\$id'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      phone: (map['phone'] ?? map['email'] ?? '').toString(),
      profilePictureId: _optionalString(map['profilePictureId']),
      roles: roles is List ? roles.map((role) => role.toString()).toList() : [],
      status: map['status'] is bool ? map['status'] as bool : true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'profilePictureId': profilePictureId,
      'roles': roles,
      'status': status,
    };
  }

  String get displayName => name.trim().isEmpty ? 'Unnamed user' : name;
  String get displayRoles => roles.isEmpty ? 'user' : roles.join(', ');
}

String? _optionalString(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
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
  Realtime(client),
);
