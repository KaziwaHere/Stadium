import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:flutter/material.dart';
import 'package:stadium/src/screens/contact_details_page.dart';
import 'package:stadium/src/services/admin_service.dart';
import 'package:stadium/src/theme/app_theme.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key, required this.user, this.adminRepository});

  final models.User user;
  final AdminService? adminRepository;

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  Stream<AdminUsersSnapshot>? _usersStream;
  bool _isViewingUsers = false;

  AdminService get _adminRepository => widget.adminRepository ?? adminService;

  bool get _isAdmin => widget.user.labels.contains('admin');

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors.backgroundGradient,
          ),
        ),
        child: SafeArea(
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
            children: [
              Row(
                children: [
                  _AdminIconButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: _handleBack,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isViewingUsers ? 'Users' : 'Admin Panel',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isViewingUsers
                              ? 'All registered users and roles'
                              : 'Manage app data and permissions',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: .58),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_isViewingUsers)
                    _AdminIconButton(
                      icon: Icons.refresh_rounded,
                      onTap: _refreshUsers,
                    ),
                ],
              ),
              const SizedBox(height: 24),
              if (!_isAdmin)
                const _AdminStatusCard(
                  icon: Icons.lock_rounded,
                  title: 'Admin access required',
                  subtitle:
                      'Only users with the admin role can view this page.',
                )
              else if (_isViewingUsers)
                _UsersPanel(
                  usersStream: _usersStream ?? _watchUsers(),
                  onUserAction: _handleUserAction,
                )
              else ...[
                _AdminActionCard(
                  icon: Icons.groups_rounded,
                  title: 'Users',
                  subtitle: 'View all users and their roles',
                  onTap: _openUsers,
                ),
                const SizedBox(height: 12),
                _AdminActionCard(
                  icon: Icons.contact_phone_rounded,
                  title: 'Contact details',
                  subtitle: 'Update admin email and phone',
                  onTap: _openContactDetails,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Stream<AdminUsersSnapshot> _watchUsers() {
    final usersStream = _adminRepository.watchUsers();
    _usersStream = usersStream;
    return usersStream;
  }

  void _openUsers() {
    setState(() {
      _isViewingUsers = true;
      _usersStream = _adminRepository.watchUsers();
    });
  }

  void _refreshUsers() {
    _adminRepository.refreshUsers(forceRefresh: true);
  }

  void _openContactDetails() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const AdminContactDetailsPage()),
    );
  }

  Future<void> _handleUserAction(AdminUser user, _UserAction action) async {
    try {
      switch (action) {
        case _UserAction.promoteAdmin:
          await _adminRepository.promoteUserToAdmin(user.id);
          break;
        case _UserAction.demoteAdmin:
          await _adminRepository.demoteUserFromAdmin(user.id);
          break;
        case _UserAction.promoteManager:
          await _adminRepository.promoteUserToManager(user.id);
          break;
        case _UserAction.demoteManager:
          await _adminRepository.demoteUserFromManager(user.id);
          break;
        case _UserAction.setToUser:
          await _adminRepository.demoteUser(user.id);
          break;
        case _UserAction.deleteUser:
          final shouldDelete = await _confirmDelete(user);
          if (!shouldDelete) return;
          await _adminRepository.deleteUser(user.id);
          break;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User updated successfully.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<bool> _confirmDelete(AdminUser user) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete user?'),
        content: Text('This will permanently delete ${user.displayName}.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  void _handleBack() {
    if (_isViewingUsers) {
      setState(() => _isViewingUsers = false);
      return;
    }

    Navigator.of(context).pop();
  }
}

class _UsersPanel extends StatelessWidget {
  const _UsersPanel({required this.usersStream, required this.onUserAction});

  final Stream<AdminUsersSnapshot> usersStream;
  final Future<void> Function(AdminUser user, _UserAction action) onUserAction;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AdminUsersSnapshot>(
      stream: usersStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData && !snapshot.hasError) {
          return const _AdminStatusCard(
            icon: Icons.groups_rounded,
            title: 'Loading users',
            subtitle: 'Checking local cache and syncing with Appwrite.',
          );
        }

        if (snapshot.hasError && !snapshot.hasData) {
          return _AdminStatusCard(
            icon: Icons.error_rounded,
            title: 'Could not load users',
            subtitle: _adminErrorMessage(snapshot.error),
          );
        }

        final usersSnapshot = snapshot.data;
        final users = usersSnapshot?.users ?? const [];
        if (users.isEmpty) {
          return const _AdminStatusCard(
            icon: Icons.person_off_rounded,
            title: 'No users found',
            subtitle: 'The admin backend returned an empty list.',
          );
        }

        return Column(
          children: [
            if (usersSnapshot != null &&
                (usersSnapshot.isRefreshing ||
                    usersSnapshot.isFromCache ||
                    usersSnapshot.errorMessage != null)) ...[
              _UsersSyncStatus(snapshot: usersSnapshot),
              const SizedBox(height: 12),
            ],
            for (var index = 0; index < users.length; index++) ...[
              _AdminUserCard(
                user: users[index],
                index: index,
                onActionSelected: onUserAction,
              ),
              if (index != users.length - 1) const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }

  String _adminErrorMessage(Object? error) {
    if (error is AppwriteException && error.code == 404) {
      return 'The admin-users Appwrite Function is not deployed yet.';
    }

    return error.toString();
  }
}

class _AdminActionCard extends StatelessWidget {
  const _AdminActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.glassFill,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: colors.glassBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors.glassFill,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: Colors.white.withValues(alpha: .82)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .56),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white.withValues(alpha: .42),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UsersSyncStatus extends StatelessWidget {
  const _UsersSyncStatus({required this.snapshot});

  final AdminUsersSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final label = snapshot.errorMessage != null
        ? 'Showing cached users. Sync failed.'
        : snapshot.isRefreshing
        ? 'Showing cached users while syncing...'
        : snapshot.isFromCache
        ? 'Showing cached users.'
        : 'Users are up to date.';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colors.glassFill,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.glassBorder),
      ),
      child: Row(
        children: [
          if (snapshot.isRefreshing)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(colors.selection),
              ),
            )
          else
            Icon(
              snapshot.errorMessage != null
                  ? Icons.cloud_off_rounded
                  : Icons.cloud_done_rounded,
              color: colors.selection,
              size: 18,
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: .68),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminUserCard extends StatelessWidget {
  const _AdminUserCard({
    required this.user,
    required this.index,
    required this.onActionSelected,
  });

  final AdminUser user;
  final int index;
  final Future<void> Function(AdminUser user, _UserAction action)
  onActionSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final gradient =
        colors.stadiumGradients[index % colors.stadiumGradients.length];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.glassFill,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.glassBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradient),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.person_rounded, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        user.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _UserActionsButton(
                      user: user,
                      onActionSelected: (action) =>
                          onActionSelected(user, action),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  user.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white.withValues(alpha: .56)),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final role
                        in user.roles.isEmpty ? const ['user'] : user.roles)
                      _RoleChip(role: role),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.activeNavFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.glassBorder),
      ),
      child: Text(
        role,
        style: TextStyle(
          color: colors.selection,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

enum _UserAction {
  promoteAdmin,
  demoteAdmin,
  promoteManager,
  demoteManager,
  setToUser,
  deleteUser,
}

class _UserActionsButton extends StatelessWidget {
  const _UserActionsButton({
    required this.user,
    required this.onActionSelected,
  });

  final AdminUser user;
  final Future<void> Function(_UserAction action) onActionSelected;

  @override
  Widget build(BuildContext context) {
    final hasAdminRole = user.roles.contains('admin');
    final hasManagerRole =
        user.roles.contains('manager') ||
        user.roles.contains('stadiummanager') ||
        user.roles.contains('stadium_manager');
    final hasElevatedRoles = hasAdminRole || hasManagerRole;

    return PopupMenuButton<_UserAction>(
      tooltip: 'User actions',
      icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
      onSelected: onActionSelected,
      itemBuilder: (context) => [
        PopupMenuItem(
          value: hasAdminRole
              ? _UserAction.demoteAdmin
              : _UserAction.promoteAdmin,
          child: Text(hasAdminRole ? 'Demote admin' : 'Promote to admin'),
        ),
        PopupMenuItem(
          value: hasManagerRole
              ? _UserAction.demoteManager
              : _UserAction.promoteManager,
          child: Text(hasManagerRole ? 'Demote manager' : 'Promote to manager'),
        ),
        if (hasElevatedRoles)
          const PopupMenuItem(
            value: _UserAction.setToUser,
            child: Text('Set to user'),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: _UserAction.deleteUser,
          child: Text('Delete user'),
        ),
      ],
    );
  }
}

class _AdminIconButton extends StatelessWidget {
  const _AdminIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: colors.glassFill,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.glassBorder),
        ),
        child: Icon(icon, color: Colors.white.withValues(alpha: .86)),
      ),
    );
  }
}

class _AdminStatusCard extends StatelessWidget {
  const _AdminStatusCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.glassFill,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.glassBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: colors.glassFill,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.white.withValues(alpha: .58)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
