import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:flutter/material.dart';
import 'package:stadium/src/screens/contact_details_page.dart';
import 'package:stadium/src/screens/stadium_booking_page.dart';
import 'package:stadium/src/services/admin_service.dart';
import 'package:stadium/src/services/manager_stadium_service.dart';
import 'package:stadium/src/theme/app_theme.dart';
import 'package:stadium/src/widgets/app_confirmation_dialog.dart';

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
                  onUserTap: _openManagerStadium,
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
    final shouldContinue = await _confirmUserAction(user, action);
    if (!shouldContinue || !mounted) return;

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

  Future<bool> _confirmUserAction(AdminUser user, _UserAction action) {
    final actionLabel = _userActionLabel(action);
    final isDelete = action == _UserAction.deleteUser;

    return showAppConfirmationDialog(
      context: context,
      icon: isDelete
          ? Icons.delete_forever_rounded
          : Icons.manage_accounts_rounded,
      title: '$actionLabel?',
      message: _userActionConfirmationMessage(user, action),
      confirmLabel: _userActionConfirmLabel(action),
      cancelLabel: 'Cancel',
      isDestructive:
          isDelete ||
          action == _UserAction.demoteAdmin ||
          action == _UserAction.demoteManager ||
          action == _UserAction.setToUser,
    );
  }

  Future<void> _openManagerStadium(AdminUser user, int index) async {
    if (!_hasManagerRole(user)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This user does not manage a stadium.')),
      );
      return;
    }

    try {
      final stadium = await managerStadiumService.managerStadium(user.id);
      if (!mounted) return;

      if (stadium == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${user.displayName} has no stadium yet.')),
        );
        return;
      }

      final colors = context.appColors;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => StadiumBookingPage(
            stadium: stadium,
            gradient:
                colors.stadiumGradients[index % colors.stadiumGradients.length],
            user: widget.user,
            isHearted: false,
          ),
        ),
      );
    } on AppwriteException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? 'Could not open stadium.')),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  String _userActionLabel(_UserAction action) {
    return switch (action) {
      _UserAction.promoteAdmin => 'Promote to admin',
      _UserAction.demoteAdmin => 'Demote admin',
      _UserAction.promoteManager => 'Promote to manager',
      _UserAction.demoteManager => 'Demote manager',
      _UserAction.setToUser => 'Set to user',
      _UserAction.deleteUser => 'Delete user',
    };
  }

  String _userActionConfirmLabel(_UserAction action) {
    return switch (action) {
      _UserAction.promoteAdmin || _UserAction.promoteManager => 'Promote',
      _UserAction.demoteAdmin || _UserAction.demoteManager => 'Demote',
      _UserAction.setToUser => 'Set to user',
      _UserAction.deleteUser => 'Delete',
    };
  }

  String _userActionConfirmationMessage(AdminUser user, _UserAction action) {
    return switch (action) {
      _UserAction.promoteAdmin =>
        'Give ${user.displayName} admin access to manage users and app data?',
      _UserAction.demoteAdmin =>
        'Remove admin access from ${user.displayName}?',
      _UserAction.promoteManager =>
        'Allow ${user.displayName} to manage a stadium?',
      _UserAction.demoteManager =>
        'Remove manager access from ${user.displayName}?',
      _UserAction.setToUser =>
        'Remove elevated roles from ${user.displayName} and keep them as a regular user?',
      _UserAction.deleteUser =>
        _hasManagerRole(user)
            ? 'This will permanently delete ${user.displayName}, their bookings, favorites, stadium, and deny pending requests for that stadium.'
            : 'This will permanently delete ${user.displayName}, their bookings, and favorites.',
    };
  }

  void _handleBack() {
    if (_isViewingUsers) {
      setState(() => _isViewingUsers = false);
      return;
    }

    Navigator.of(context).pop();
  }
}

class _UsersPanel extends StatefulWidget {
  const _UsersPanel({
    required this.usersStream,
    required this.onUserAction,
    required this.onUserTap,
  });

  final Stream<AdminUsersSnapshot> usersStream;
  final Future<void> Function(AdminUser user, _UserAction action) onUserAction;
  final Future<void> Function(AdminUser user, int index) onUserTap;

  @override
  State<_UsersPanel> createState() => _UsersPanelState();
}

class _UsersPanelState extends State<_UsersPanel> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  _AdminUserRoleFilter _roleFilter = _AdminUserRoleFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AdminUsersSnapshot>(
      stream: widget.usersStream,
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
        final filteredUsers = _filteredUsers(users);
        if (users.isEmpty) {
          return const _AdminStatusCard(
            icon: Icons.person_off_rounded,
            title: 'No users found',
            subtitle: 'The admin backend returned an empty list.',
          );
        }

        return Column(
          children: [
            _AdminUsersSearchBar(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              onClear: _clearSearch,
            ),
            const SizedBox(height: 12),
            _AdminUsersRoleFilter(
              selectedRole: _roleFilter,
              onChanged: (role) => setState(() => _roleFilter = role),
            ),
            const SizedBox(height: 12),
            if (usersSnapshot != null &&
                (usersSnapshot.isRefreshing ||
                    usersSnapshot.isFromCache ||
                    usersSnapshot.errorMessage != null)) ...[
              _UsersSyncStatus(snapshot: usersSnapshot),
              const SizedBox(height: 12),
            ],
            if (filteredUsers.isEmpty)
              _AdminStatusCard(
                icon: Icons.search_off_rounded,
                title: 'No matching users',
                subtitle: _emptyFilterMessage,
              )
            else
              for (var index = 0; index < filteredUsers.length; index++) ...[
                _AdminUserCard(
                  user: filteredUsers[index],
                  index: index,
                  onTap: () => widget.onUserTap(filteredUsers[index], index),
                  onActionSelected: widget.onUserAction,
                ),
                if (index != filteredUsers.length - 1)
                  const SizedBox(height: 12),
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

  List<AdminUser> _filteredUsers(List<AdminUser> users) {
    final query = _searchQuery.trim().toLowerCase();
    final queryDigits = _digitsOnly(query);
    return users.where((user) {
      if (!_matchesRoleFilter(user)) return false;
      if (query.isEmpty) return true;

      final name = user.displayName.toLowerCase();
      final phone = user.phone.toLowerCase();
      final localPhone = _localPhoneNumber(user.phone).toLowerCase();
      final phoneDigits = _digitsOnly(user.phone);
      final localPhoneDigits = _digitsOnly(localPhone);

      return name.contains(query) ||
          phone.contains(query) ||
          localPhone.contains(query) ||
          (queryDigits.isNotEmpty &&
              (phoneDigits.contains(queryDigits) ||
                  localPhoneDigits.contains(queryDigits)));
    }).toList();
  }

  bool _matchesRoleFilter(AdminUser user) {
    return switch (_roleFilter) {
      _AdminUserRoleFilter.all => true,
      _AdminUserRoleFilter.admin => _hasAdminRole(user),
      _AdminUserRoleFilter.manager => _hasManagerRole(user),
      _AdminUserRoleFilter.user =>
        !_hasAdminRole(user) && !_hasManagerRole(user),
    };
  }

  String get _emptyFilterMessage {
    final query = _searchQuery.trim();
    final roleLabel = _roleFilter.label.toLowerCase();

    if (query.isEmpty) {
      return 'No $roleLabel users found.';
    }

    return 'No $roleLabel users match "$query".';
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _searchQuery = '');
  }
}

enum _AdminUserRoleFilter {
  all('All'),
  admin('Admin'),
  manager('Manager'),
  user('User');

  const _AdminUserRoleFilter(this.label);

  final String label;
}

class _AdminUsersSearchBar extends StatelessWidget {
  const _AdminUsersSearchBar({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: colors.glassFill,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.glassBorder),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, color: colors.mutedIcon),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.search,
              cursorColor: colors.selection,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Search by name or phone',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: .52),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, child) {
              if (value.text.isEmpty) return const SizedBox.shrink();

              return IconButton(
                tooltip: 'Clear search',
                onPressed: onClear,
                style: IconButton.styleFrom(
                  foregroundColor: Colors.white.withValues(alpha: .78),
                  minimumSize: const Size(38, 38),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.close_rounded, size: 20),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AdminUsersRoleFilter extends StatelessWidget {
  const _AdminUsersRoleFilter({
    required this.selectedRole,
    required this.onChanged,
  });

  final _AdminUserRoleFilter selectedRole;
  final ValueChanged<_AdminUserRoleFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          for (final role in _AdminUserRoleFilter.values) ...[
            _AdminRoleFilterChip(
              label: role.label,
              isSelected: selectedRole == role,
              onTap: () => onChanged(role),
            ),
            if (role != _AdminUserRoleFilter.values.last)
              const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _AdminRoleFilterChip extends StatelessWidget {
  const _AdminRoleFilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? colors.activeNavFill : colors.glassFill,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? colors.selection : colors.glassBorder,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? colors.selection : Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
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
    required this.onTap,
    required this.onActionSelected,
  });

  final AdminUser user;
  final int index;
  final VoidCallback onTap;
  final Future<void> Function(AdminUser user, _UserAction action)
  onActionSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final gradient =
        colors.stadiumGradients[index % colors.stadiumGradients.length];
    final phoneLabel = _localPhoneNumber(user.phone);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
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
                    SizedBox(height: phoneLabel.isEmpty ? 6 : 5),
                    if (phoneLabel.isNotEmpty) ...[
                      Text(
                        phoneLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .56),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
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
        ),
      ),
    );
  }
}

String _localPhoneNumber(String phone) {
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  final withoutCountryCode = digits.startsWith('964')
      ? digits.substring(3)
      : digits.replaceFirst(RegExp(r'^0+'), '');
  if (withoutCountryCode.isEmpty) return '';
  return '0$withoutCountryCode';
}

String _digitsOnly(String value) {
  return value.replaceAll(RegExp(r'\D'), '');
}

bool _hasAdminRole(AdminUser user) {
  return user.roles.contains('admin');
}

bool _hasManagerRole(AdminUser user) {
  return user.roles.contains('manager') ||
      user.roles.contains('stadiummanager') ||
      user.roles.contains('stadium_manager');
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
    final colors = context.appColors;
    final hasAdminRole = _hasAdminRole(user);
    final hasManagerRole = _hasManagerRole(user);
    final hasElevatedRoles = hasAdminRole || hasManagerRole;

    return SizedBox(
      width: 44,
      height: 44,
      child: PopupMenuButton<_UserAction>(
        tooltip: 'Manage user',
        padding: EdgeInsets.zero,
        offset: const Offset(0, 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: Theme.of(context).colorScheme.surface,
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
            child: Text(
              hasManagerRole ? 'Demote manager' : 'Promote to manager',
            ),
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
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: colors.glassFill,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.glassBorder),
          ),
          child: const Icon(Icons.more_vert_rounded, color: Colors.white),
        ),
      ),
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
