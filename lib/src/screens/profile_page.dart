import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stadium/src/screens/admin_page.dart';
import 'package:stadium/src/screens/contact_details_page.dart';
import 'package:stadium/src/services/auth_service.dart';
import 'package:stadium/src/theme/app_theme.dart';
import 'package:stadium/src/widgets/app_confirmation_dialog.dart';
import 'package:stadium/src/widgets/app_notification.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.user, required this.onSignedOut});

  final models.User user;
  final VoidCallback onSignedOut;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late models.User _user = widget.user;
  bool _isSigningOut = false;

  @override
  void initState() {
    super.initState();
    _refreshProfile(showError: false);
  }

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
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 110),
            children: [
              Row(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: colors.glassFill,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: colors.glassBorder),
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      color: Colors.white,
                      size: 34,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _displayName,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _displayPhone,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: .6),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              _ProfileOption(
                icon: Icons.account_circle_rounded,
                title: 'Personal details',
                subtitle: 'Name, phone, and password',
                onTap: _openPersonalDetails,
              ),
              const SizedBox(height: 12),
              const _ProfileOption(
                icon: Icons.payments_rounded,
                title: 'Payment methods',
                subtitle: 'Cards and wallet settings',
              ),
              const SizedBox(height: 12),
              _ProfileOption(
                icon: Icons.support_agent_rounded,
                title: 'Contact us',
                subtitle: 'Admin email and phone number',
                onTap: _openContactUs,
              ),
              if (_user.labels.contains('admin')) ...[
                const SizedBox(height: 12),
                _ProfileOption(
                  icon: Icons.admin_panel_settings_rounded,
                  title: 'Admin panel',
                  subtitle: 'Manage users and roles',
                  onTap: _openAdminPanel,
                ),
              ],
              const SizedBox(height: 22),
              SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: colors.glassBorder),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  onPressed: _isSigningOut ? null : _signOut,
                  icon: _isSigningOut
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.4),
                        )
                      : const Icon(Icons.logout_rounded),
                  label: const Text(
                    'Sign out',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _displayName => _user.name.trim().isEmpty ? 'Profile' : _user.name;
  String get _displayPhone => _user.phone.trim().isEmpty
      ? 'No phone number added'
      : _localPhoneNumber(_user.phone);

  Future<void> _refreshProfile({bool showError = true}) async {
    try {
      final user = await authService.refreshUser();
      if (!mounted) return;

      setState(() => _user = user);
    } on AppwriteException catch (error) {
      if (!mounted || !showError) return;

      showAppNotification(
        context,
        title: 'Profile unavailable',
        message: error.message ?? 'Could not refresh your profile.',
        type: AppNotificationType.error,
      );
    } catch (error) {
      if (!mounted || !showError) return;

      showAppNotification(
        context,
        title: 'Profile unavailable',
        message: 'Could not refresh your profile.',
        type: AppNotificationType.error,
      );
    }
  }

  Future<void> _openPersonalDetails() async {
    final action = await showModalBottomSheet<_PersonalDetailsAction>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PersonalDetailsSheet(user: _user),
    );

    if (action != _PersonalDetailsAction.change || !mounted) return;

    final updatedUser = await Navigator.of(context).push<models.User>(
      MaterialPageRoute(builder: (context) => _ChangeDetailsPage(user: _user)),
    );

    if (!mounted) return;
    if (updatedUser == null) {
      await _refreshProfile(showError: false);
      return;
    }

    setState(() => _user = updatedUser);
  }

  Future<void> _openAdminPanel() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => AdminPage(user: _user)));

    if (mounted) {
      await _refreshProfile(showError: false);
    }
  }

  void _openContactUs() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const ContactDetailsPage()));
  }

  Future<void> _signOut() async {
    final shouldSignOut = await showAppConfirmationDialog(
      context: context,
      icon: Icons.logout_rounded,
      title: 'Sign out?',
      message: 'You will need to sign in again to manage bookings.',
      confirmLabel: 'Sign out',
      cancelLabel: 'Stay here',
      isDestructive: true,
    );
    if (!shouldSignOut || !mounted) return;

    setState(() => _isSigningOut = true);

    try {
      await authService.logout();
      widget.onSignedOut();
    } on AppwriteException catch (error) {
      if (!mounted) return;

      showAppNotification(
        context,
        title: 'Sign out failed',
        message: error.message ?? 'Please try again.',
        type: AppNotificationType.error,
      );
    } catch (error) {
      if (!mounted) return;

      showAppNotification(
        context,
        title: 'Sign out failed',
        message: error.toString(),
        type: AppNotificationType.error,
      );
    } finally {
      if (mounted) {
        setState(() => _isSigningOut = false);
      }
    }
  }
}

class _ProfileOption extends StatelessWidget {
  const _ProfileOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

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

enum _PersonalDetailsAction { change }

class _PersonalDetailsSheet extends StatelessWidget {
  const _PersonalDetailsSheet({required this.user});

  final models.User user;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final displayName = user.name.trim().isEmpty ? 'Profile' : user.name;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .22),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Personal details',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 18),
                _ReadonlyProfileField(
                  icon: Icons.person_rounded,
                  label: 'Name',
                  value: displayName,
                ),
                const SizedBox(height: 10),
                _ReadonlyProfileField(
                  icon: Icons.phone_rounded,
                  label: 'Phone',
                  value: user.phone.isEmpty
                      ? 'No phone number added'
                      : _localPhoneNumber(user.phone),
                  badge: user.phoneVerification ? 'Verified' : null,
                ),
                const SizedBox(height: 10),
                _AccountInfoRow(
                  icon: Icons.info_rounded,
                  text: 'Tap Change details to update account information.',
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.action,
                      foregroundColor: colors.onAction,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop(_PersonalDetailsAction.change);
                    },
                    icon: const Icon(Icons.edit_rounded),
                    label: const Text(
                      'Change details',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChangeDetailsPage extends StatefulWidget {
  const _ChangeDetailsPage({required this.user});

  final models.User user;

  @override
  State<_ChangeDetailsPage> createState() => _ChangeDetailsPageState();
}

class _ChangeDetailsPageState extends State<_ChangeDetailsPage> {
  late models.User _user = widget.user;

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
                  _SmallIconButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => Navigator.of(context).pop(_user),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Change details',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _ProfileOption(
                icon: Icons.person_rounded,
                title: 'Change name',
                subtitle: _user.name.trim().isEmpty
                    ? 'No name set'
                    : _user.name,
                onTap: _changeName,
              ),
              const SizedBox(height: 12),
              _ProfileOption(
                icon: Icons.phone_rounded,
                title: 'Change phone number',
                subtitle: _user.phone.isEmpty
                    ? 'No phone number added'
                    : _localPhoneNumber(_user.phone),
                onTap: _changePhone,
              ),
              const SizedBox(height: 12),
              _ProfileOption(
                icon: Icons.lock_rounded,
                title: 'Change password',
                subtitle: 'Update your account password',
                onTap: _changePassword,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _changeName() async {
    final user = await showModalBottomSheet<models.User>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _NameEditSheet(user: _user),
    );

    _handleUpdatedUser(user, 'Name updated', 'Your name was saved.');
  }

  Future<void> _changePhone() async {
    final user = await showModalBottomSheet<models.User>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PhoneEditSheet(user: _user),
    );

    _handleUpdatedUser(user, 'Phone updated', 'Your phone number was saved.');
  }

  Future<void> _changePassword() async {
    final user = await showModalBottomSheet<models.User>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PasswordEditSheet(),
    );

    _handleUpdatedUser(user, 'Password updated', 'Your password was saved.');
  }

  void _handleUpdatedUser(models.User? user, String title, String message) {
    if (user == null || !mounted) return;

    setState(() => _user = user);
    showAppNotification(
      context,
      title: title,
      message: message,
      type: AppNotificationType.success,
    );
  }
}

class _SmallIconButton extends StatelessWidget {
  const _SmallIconButton({required this.icon, required this.onTap});

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

class _NameEditSheet extends StatefulWidget {
  const _NameEditSheet({required this.user});

  final models.User user;

  @override
  State<_NameEditSheet> createState() => _NameEditSheetState();
}

class _NameEditSheetState extends State<_NameEditSheet> {
  late final TextEditingController _nameController = TextEditingController(
    text: widget.user.name,
  );
  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _EditSheetFrame(
      title: 'Change name',
      isSaving: _isSaving,
      onSave: _save,
      child: TextField(
        controller: _nameController,
        textInputAction: TextInputAction.done,
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
        onSubmitted: (_) => _save(),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
        decoration: profileInputDecoration(
          context: context,
          icon: Icons.person_rounded,
          label: 'Name',
          errorText: _error,
        ),
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.length < 2) {
      setState(() => _error = 'Enter at least 2 characters');
      return;
    }

    if (name == widget.user.name) {
      Navigator.of(context).pop();
      return;
    }

    setState(() => _isSaving = true);

    try {
      final user = await authService.updateName(name: name);
      if (mounted) Navigator.of(context).pop(user);
    } on AppwriteException catch (error) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _error = error.message ?? 'Could not save name';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _error = 'Could not save name';
      });
    }
  }
}

class _PhoneEditSheet extends StatefulWidget {
  const _PhoneEditSheet({required this.user});

  final models.User user;

  @override
  State<_PhoneEditSheet> createState() => _PhoneEditSheetState();
}

class _PhoneEditSheetState extends State<_PhoneEditSheet> {
  late final TextEditingController _phoneController = TextEditingController(
    text: _localPhoneNumber(widget.user.phone),
  );
  final TextEditingController _passwordController = TextEditingController();
  bool _isSaving = false;
  String? _phoneError;
  String? _passwordError;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _EditSheetFrame(
      title: 'Change phone',
      isSaving: _isSaving,
      onSave: _save,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textInputAction: TextInputAction.next,
            onChanged: (_) {
              if (_phoneError != null) setState(() => _phoneError = null);
            },
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
            decoration: profileInputDecoration(
              context: context,
              icon: Icons.phone_rounded,
              label: 'New phone number',
              hintText: '07701234567',
              errorText: _phoneError,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _passwordController,
            obscureText: true,
            textInputAction: TextInputAction.done,
            onChanged: (_) {
              if (_passwordError != null) {
                setState(() => _passwordError = null);
              }
            },
            onSubmitted: (_) => _save(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
            decoration: profileInputDecoration(
              context: context,
              icon: Icons.lock_rounded,
              label: 'Current password',
              errorText: _passwordError,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final phone = _normalizedPhoneNumber(_phoneController.text);
    final password = _passwordController.text;
    var hasError = false;

    if (!RegExp(r'^\+9647\d{9}$').hasMatch(phone)) {
      _phoneError = 'Enter a valid phone number, like 07701234567';
      hasError = true;
    }
    if (password.isEmpty) {
      _passwordError = 'Enter your current password';
      hasError = true;
    }
    if (hasError) {
      setState(() {});
      return;
    }
    if (phone == widget.user.phone) {
      Navigator.of(context).pop();
      return;
    }

    setState(() => _isSaving = true);

    try {
      final user = await authService.updatePhone(
        phone: phone,
        password: password,
      );
      if (mounted) Navigator.of(context).pop(user);
    } on AppwriteException catch (error) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _passwordError = error.message ?? 'Could not save phone number';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _passwordError = 'Could not save phone number';
      });
    }
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

String _normalizedPhoneNumber(String phone) {
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  final localDigits = digits.startsWith('964')
      ? digits.substring(3)
      : digits.replaceFirst(RegExp(r'^0+'), '');
  return '+964$localDigits';
}

class _PasswordEditSheet extends StatefulWidget {
  const _PasswordEditSheet();

  @override
  State<_PasswordEditSheet> createState() => _PasswordEditSheetState();
}

class _PasswordEditSheetState extends State<_PasswordEditSheet> {
  final TextEditingController _oldPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  bool _isSaving = false;
  String? _oldPasswordError;
  String? _newPasswordError;

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _EditSheetFrame(
      title: 'Change password',
      isSaving: _isSaving,
      onSave: _save,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _oldPasswordController,
            obscureText: true,
            textInputAction: TextInputAction.next,
            onChanged: (_) {
              if (_oldPasswordError != null) {
                setState(() => _oldPasswordError = null);
              }
            },
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
            decoration: profileInputDecoration(
              context: context,
              icon: Icons.lock_rounded,
              label: 'Current password',
              errorText: _oldPasswordError,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _newPasswordController,
            obscureText: true,
            textInputAction: TextInputAction.done,
            onChanged: (_) {
              if (_newPasswordError != null) {
                setState(() => _newPasswordError = null);
              }
            },
            onSubmitted: (_) => _save(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
            decoration: profileInputDecoration(
              context: context,
              icon: Icons.password_rounded,
              label: 'New password',
              errorText: _newPasswordError,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final oldPassword = _oldPasswordController.text;
    final newPassword = _newPasswordController.text;
    var hasError = false;

    if (oldPassword.isEmpty) {
      _oldPasswordError = 'Enter your current password';
      hasError = true;
    }
    if (newPassword.length < 8) {
      _newPasswordError = 'Password must be at least 8 characters';
      hasError = true;
    }
    if (hasError) {
      setState(() {});
      return;
    }

    setState(() => _isSaving = true);

    try {
      final user = await authService.updatePassword(
        password: newPassword,
        oldPassword: oldPassword,
      );
      if (mounted) Navigator.of(context).pop(user);
    } on AppwriteException catch (error) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _oldPasswordError = error.message ?? 'Could not save password';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _oldPasswordError = 'Could not save password';
      });
    }
  }
}

class _EditSheetFrame extends StatelessWidget {
  const _EditSheetFrame({
    required this.title,
    required this.child,
    required this.isSaving,
    required this.onSave,
  });

  final String title;
  final Widget child;
  final bool isSaving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .22),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 18),
                child,
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.action,
                      foregroundColor: colors.onAction,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    onPressed: isSaving ? null : onSave,
                    icon: isSaving
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                colors.onAction,
                              ),
                            ),
                          )
                        : const Icon(Icons.save_rounded),
                    label: const Text(
                      'Save changes',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

InputDecoration profileInputDecoration({
  required BuildContext context,
  required IconData icon,
  required String label,
  String? hintText,
  String? errorText,
}) {
  final colors = context.appColors;

  return InputDecoration(
    labelText: label,
    hintText: hintText,
    errorText: errorText,
    prefixIcon: Icon(icon, color: colors.mutedIcon),
    filled: true,
    fillColor: colors.glassFill,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: colors.glassBorder),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: colors.glassBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: colors.selection),
    ),
  );
}

class _ReadonlyProfileField extends StatelessWidget {
  const _ReadonlyProfileField({
    required this.icon,
    required this.label,
    required this.value,
    this.badge,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.glassFill,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.glassBorder),
      ),
      child: Row(
        children: [
          Icon(icon, color: colors.mutedIcon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .56),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          if (badge != null) ...[
            const SizedBox(width: 10),
            Text(
              badge!,
              style: TextStyle(
                color: colors.selection,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AccountInfoRow extends StatelessWidget {
  const _AccountInfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.glassFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.glassBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colors.mutedIcon, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white.withValues(alpha: .58),
                height: 1.3,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
