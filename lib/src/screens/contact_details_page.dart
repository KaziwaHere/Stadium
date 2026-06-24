import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stadium/src/services/contact_details_service.dart';
import 'package:stadium/src/theme/app_theme.dart';
import 'package:stadium/src/widgets/app_notification.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactDetailsPage extends StatelessWidget {
  const ContactDetailsPage({super.key, this.repository});

  final ContactDetailsRepository? repository;

  ContactDetailsRepository get _repository =>
      repository ?? contactDetailsService;

  @override
  Widget build(BuildContext context) {
    return _ContactDetailsFrame(
      title: 'Contact Us',
      subtitle: 'Reach the admin team using the details below.',
      child: FutureBuilder<ContactDetails>(
        future: _repository.getContactDetails(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done &&
              !snapshot.hasData) {
            return const _ContactStatusCard(
              icon: Icons.support_agent_rounded,
              title: 'Loading contact details',
              subtitle: 'Fetching the latest admin contact info.',
            );
          }

          if (snapshot.hasError) {
            return const _ContactStatusCard(
              icon: Icons.error_rounded,
              title: 'Could not load contact details',
              subtitle: 'Please check your connection and try again.',
            );
          }

          final details = snapshot.data ?? ContactDetails.empty;
          if (details.isEmpty) {
            return const _ContactStatusCard(
              icon: Icons.contact_support_rounded,
              title: 'No contact details yet',
              subtitle: 'The admin has not added an email or phone number.',
            );
          }

          return Column(
            children: [
              if (details.hasEmail)
                _ContactInfoCard(
                  icon: Icons.email_rounded,
                  title: 'Email',
                  value: details.email,
                  actionLabel: 'Email admin',
                  onTap: () => _launchContactUri(
                    context,
                    Uri(scheme: 'mailto', path: details.email),
                  ),
                ),
              if (details.hasEmail && details.hasPhone)
                const SizedBox(height: 12),
              if (details.hasPhone)
                _ContactInfoCard(
                  icon: Icons.phone_rounded,
                  title: 'Phone',
                  value: details.phone,
                  actionLabel: 'Call admin',
                  onTap: () => _launchContactUri(
                    context,
                    Uri(scheme: 'tel', path: details.phone),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _launchContactUri(BuildContext context, Uri uri) async {
    final opened = await launchUrl(uri);
    if (opened || !context.mounted) return;

    showAppNotification(
      context,
      title: 'Could not open',
      message: 'No app is available for this action.',
      type: AppNotificationType.error,
    );
  }
}

class AdminContactDetailsPage extends StatefulWidget {
  const AdminContactDetailsPage({super.key, this.repository});

  final ContactDetailsRepository? repository;

  @override
  State<AdminContactDetailsPage> createState() =>
      _AdminContactDetailsPageState();
}

class _AdminContactDetailsPageState extends State<AdminContactDetailsPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  late Future<ContactDetails> _detailsFuture;
  bool _isSaving = false;
  String? _emailError;
  String? _phoneError;

  ContactDetailsRepository get _repository =>
      widget.repository ?? contactDetailsService;

  @override
  void initState() {
    super.initState();
    _detailsFuture = _loadDetails();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<ContactDetails> _loadDetails() async {
    final details = await _repository.getContactDetails();
    _emailController.text = details.email;
    _phoneController.text = _localIraqPhoneNumber(details.phone);
    return details;
  }

  @override
  Widget build(BuildContext context) {
    return _ContactDetailsFrame(
      title: 'Contact Details',
      subtitle: 'Update the email and phone number users see.',
      child: FutureBuilder<ContactDetails>(
        future: _detailsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done &&
              !snapshot.hasData) {
            return const _ContactStatusCard(
              icon: Icons.manage_accounts_rounded,
              title: 'Loading details',
              subtitle: 'Fetching current contact information.',
            );
          }

          if (snapshot.hasError) {
            return const _ContactStatusCard(
              icon: Icons.error_rounded,
              title: 'Could not load details',
              subtitle: 'Check admin permissions and table setup.',
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                onChanged: (_) {
                  if (_emailError != null) setState(() => _emailError = null);
                },
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
                decoration: _contactInputDecoration(
                  context: context,
                  icon: Icons.email_rounded,
                  label: 'Admin email',
                  errorText: _emailError,
                ),
              ),
              const SizedBox(height: 14),
              _IraqPhoneField(
                controller: _phoneController,
                errorText: _phoneError,
                onChanged: () {
                  if (_phoneError != null) setState(() => _phoneError = null);
                },
                onSubmitted: _save,
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: context.appColors.action,
                    foregroundColor: context.appColors.onAction,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  onPressed: _isSaving ? null : _save,
                  icon: _isSaving
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              context.appColors.onAction,
                            ),
                          ),
                        )
                      : const Icon(Icons.save_rounded),
                  label: const Text(
                    'Save contact details',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _save() async {
    final email = _emailController.text.trim();
    final phone = _fullIraqPhoneNumber(_phoneController.text);
    var hasError = false;

    if (email.isEmpty || !email.contains('@')) {
      _emailError = 'Enter a valid email';
      hasError = true;
    }
    if (phone == _iraqDialCode) {
      _phoneError = 'Enter the phone number after +964';
      hasError = true;
    }
    if (hasError) {
      setState(() {});
      return;
    }

    setState(() => _isSaving = true);

    try {
      await _repository.updateContactDetails(email: email, phone: phone);
      if (!mounted) return;
      showAppNotification(
        context,
        title: 'Contact details updated',
        message: 'Users will now see the new email and phone number.',
        type: AppNotificationType.success,
      );
    } on AppwriteException catch (error) {
      if (!mounted) return;
      showAppNotification(
        context,
        title: 'Save failed',
        message: error.message ?? 'Could not update contact details.',
        type: AppNotificationType.error,
      );
    } catch (_) {
      if (!mounted) return;
      showAppNotification(
        context,
        title: 'Save failed',
        message: 'Could not update contact details.',
        type: AppNotificationType.error,
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

const _iraqDialCode = '+964';

String _localIraqPhoneNumber(String phone) {
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  final withoutCountryCode = digits.startsWith('964')
      ? digits.substring(3)
      : digits;
  return withoutCountryCode.replaceFirst(RegExp(r'^0+'), '');
}

String _fullIraqPhoneNumber(String localPhone) {
  final localDigits = localPhone
      .replaceAll(RegExp(r'\D'), '')
      .replaceFirst(RegExp(r'^0+'), '');
  return '$_iraqDialCode$localDigits';
}

class _ContactDetailsFrame extends StatelessWidget {
  const _ContactDetailsFrame({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

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
                  IconButton(
                    tooltip: 'Back',
                    onPressed: () => Navigator.of(context).pop(),
                    style: IconButton.styleFrom(
                      foregroundColor: Colors.white.withValues(alpha: .86),
                      backgroundColor: colors.glassFill,
                      minimumSize: const Size(46, 46),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: colors.glassBorder),
                      ),
                    ),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: .58),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _ContactInfoCard extends StatelessWidget {
  const _ContactInfoCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.actionLabel,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.glassFill,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.glassBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: colors.glassFill,
              borderRadius: BorderRadius.circular(17),
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
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.white.withValues(alpha: .6),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            tooltip: actionLabel,
            onPressed: onTap,
            style: IconButton.styleFrom(
              foregroundColor: colors.selection,
              backgroundColor: colors.activeNavFill,
              minimumSize: const Size(44, 44),
            ),
            icon: const Icon(Icons.open_in_new_rounded, size: 20),
          ),
        ],
      ),
    );
  }
}

class _ContactStatusCard extends StatelessWidget {
  const _ContactStatusCard({
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

class _IraqPhoneField extends StatelessWidget {
  const _IraqPhoneField({
    required this.controller,
    required this.onChanged,
    required this.onSubmitted,
    this.errorText,
  });

  final TextEditingController controller;
  final VoidCallback onChanged;
  final VoidCallback onSubmitted;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    const textStyle = TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.w800,
    );

    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: colors.glassBorder),
    );

    return InputDecorator(
      decoration: InputDecoration(
        labelText: 'Admin phone',
        errorText: errorText,
        prefixIcon: Icon(Icons.phone_rounded, color: colors.mutedIcon),
        filled: true,
        fillColor: colors.glassFill,
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(color: colors.selection),
        ),
        contentPadding: const EdgeInsets.fromLTRB(0, 14, 16, 14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text('$_iraqDialCode ', style: textStyle),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => onChanged(),
              onSubmitted: (_) => onSubmitted(),
              style: textStyle,
              decoration: InputDecoration.collapsed(
                hintText: '7701234567',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: .42),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

InputDecoration _contactInputDecoration({
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
