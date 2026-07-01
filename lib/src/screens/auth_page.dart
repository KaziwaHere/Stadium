import 'dart:ui';

import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stadium/src/services/auth_service.dart';
import 'package:stadium/src/theme/app_theme.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key, required this.onAuthenticated});

  final ValueChanged<models.User> onAuthenticated;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isRegistering = false;
  bool _isSubmitting = false;
  bool _obscurePassword = true;
  bool _wasKeyboardVisible = false;
  String? _formError;
  String? _formMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final isKeyboardVisible = View.of(context).viewInsets.bottom > 0;
      if (_wasKeyboardVisible && !isKeyboardVisible) {
        FocusManager.instance.primaryFocus?.unfocus();
      }

      _wasKeyboardVisible = isKeyboardVisible;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      body: Stack(
        children: [
          _AuthBackground(colors: colors),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _BrandHeader(isRegistering: _isRegistering),
                      const SizedBox(height: 26),
                      _AuthPanel(
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              _ModeSwitch(
                                isRegistering: _isRegistering,
                                onChanged: _setMode,
                              ),
                              const SizedBox(height: 22),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 180),
                                child: _isRegistering
                                    ? Padding(
                                        key: const ValueKey('nameField'),
                                        padding: const EdgeInsets.only(
                                          bottom: 14,
                                        ),
                                        child: _AuthTextField(
                                          controller: _nameController,
                                          icon: Icons.person_rounded,
                                          label: 'Full name',
                                          textInputAction: TextInputAction.next,
                                          validator: _validateName,
                                          onChanged: (_) => _clearFormError(),
                                        ),
                                      )
                                    : const SizedBox.shrink(
                                        key: ValueKey('emptyNameField'),
                                      ),
                              ),
                              _AuthTextField(
                                controller: _phoneController,
                                icon: Icons.phone_rounded,
                                label: 'Phone number',
                                keyboardType: TextInputType.phone,
                                textInputAction: TextInputAction.next,
                                validator: _validatePhone,
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'[\d+]'),
                                  ),
                                ],
                                onChanged: (_) => _clearFormError(),
                              ),
                              const SizedBox(height: 14),
                              _AuthTextField(
                                controller: _passwordController,
                                icon: Icons.lock_rounded,
                                label: 'Password',
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.done,
                                validator: _validatePassword,
                                onChanged: (_) => _clearFormError(),
                                suffixIcon: IconButton(
                                  tooltip: _obscurePassword
                                      ? 'Show password'
                                      : 'Hide password',
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_rounded
                                        : Icons.visibility_off_rounded,
                                  ),
                                ),
                                onSubmitted: (_) => _submit(),
                              ),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 180),
                                child: _formMessage == null
                                    ? const SizedBox.shrink()
                                    : Padding(
                                        padding: const EdgeInsets.only(
                                          top: 12,
                                          left: 12,
                                          right: 12,
                                        ),
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            _formMessage!,
                                            style: TextStyle(
                                              color: colors.selection,
                                              fontSize: 12,
                                              height: 1.25,
                                            ),
                                          ),
                                        ),
                                      ),
                              ),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 180),
                                child: _formError == null
                                    ? SizedBox(
                                        height: _formMessage == null ? 22 : 16,
                                      )
                                    : Padding(
                                        padding: const EdgeInsets.only(
                                          top: 16,
                                          left: 12,
                                          right: 12,
                                        ),
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            _formError!,
                                            style: TextStyle(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.error,
                                              fontSize: 12,
                                              height: 1.25,
                                            ),
                                          ),
                                        ),
                                      ),
                              ),
                              if (_formError != null)
                                const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                height: 54,
                                child: FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: colors.action,
                                    foregroundColor: colors.onAction,
                                    disabledBackgroundColor: colors.glassFill,
                                    disabledForegroundColor: Colors.white
                                        .withValues(alpha: .46),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                  ),
                                  onPressed: _isSubmitting ? null : _submit,
                                  icon: _isSubmitting
                                      ? SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.4,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  colors.onAction,
                                                ),
                                          ),
                                        )
                                      : Icon(
                                          _isRegistering
                                              ? Icons.person_add_rounded
                                              : Icons.login_rounded,
                                        ),
                                  label: Text(
                                    _isRegistering
                                        ? 'Create account'
                                        : 'Sign in',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _setMode(bool isRegistering) {
    if (_isSubmitting || _isRegistering == isRegistering) return;

    setState(() {
      _isRegistering = isRegistering;
      _formError = null;
      _formMessage = null;
    });
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    setState(() {
      _formError = null;
      _formMessage = null;
      _isSubmitting = true;
    });

    try {
      final phone = _normalizedPhone(_phoneController.text);
      final password = _passwordController.text;
      final user = _isRegistering
          ? await authService.register(
              name: _nameController.text.trim(),
              phone: phone,
              password: password,
            )
          : await authService.login(phone: phone, password: password);

      widget.onAuthenticated(user);
    } on AppwriteException catch (error) {
      setState(() => _formError = _authErrorMessage(error));
    } catch (error) {
      final message = error.toString().toLowerCase();
      setState(
        () => _formError =
            message.contains('failed host lookup') ||
                message.contains('socketexception')
            ? 'Cannot reach Appwrite. Check your internet or Private DNS, then try again.'
            : 'Authentication failed. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  String? _validateName(String? value) {
    if (!_isRegistering) return null;
    if (value == null || value.trim().length < 2) {
      return 'Enter your name';
    }

    return null;
  }

  String? _validatePhone(String? value) {
    final phone = _normalizedPhone(value ?? '');
    if (!RegExp(r'^\+9647\d{9}$').hasMatch(phone)) {
      return 'Enter a valid phone number, like 07701234567';
    }

    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.length < 8) {
      return 'Password must be at least 8 characters';
    }

    return null;
  }

  String _authErrorMessage(AppwriteException error) {
    if (!_isRegistering && (error.code == 400 || error.code == 401)) {
      return 'Phone number or password is incorrect.';
    }

    if (_isRegistering && error.code == 409) {
      return 'An account already exists with this phone number.';
    }

    return error.message ?? 'Authentication failed.';
  }

  void _clearFormError() {
    if (_formError == null && _formMessage == null) return;

    setState(() {
      _formError = null;
      _formMessage = null;
    });
  }

  String _normalizedPhone(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    final localDigits = digits.startsWith('964')
        ? digits.substring(3)
        : digits.replaceFirst(RegExp(r'^0+'), '');
    return '+964$localDigits';
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.isRegistering});

  final bool isRegistering;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: .14)),
          ),
          child: const Icon(Icons.stadium_rounded, color: Colors.white),
        ),
        const SizedBox(height: 22),
        Text(
          isRegistering ? 'Create your account' : 'Welcome back',
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          isRegistering
              ? 'Join Stadium Baghdad and reserve your next match slot.'
              : 'Sign in to manage bookings and reserve stadium slots.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Colors.white.withValues(alpha: .66),
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _AuthPanel extends StatelessWidget {
  const _AuthPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.glassFill,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: colors.glassBorder),
            boxShadow: [
              BoxShadow(
                color: colors.shadow,
                blurRadius: 30,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.isRegistering, required this.onChanged});

  final bool isRegistering;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.glassBorder),
      ),
      child: Row(
        children: [
          _ModeButton(
            label: 'Login',
            isSelected: !isRegistering,
            onTap: () => onChanged(false),
          ),
          const SizedBox(width: 6),
          _ModeButton(
            label: 'Register',
            isSelected: isRegistering,
            onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
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

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? colors.activeNavFill : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected
                  ? colors.selection
                  : Colors.white.withValues(alpha: .62),
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthTextField extends StatefulWidget {
  const _AuthTextField({
    required this.controller,
    required this.icon,
    required this.label,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.inputFormatters,
    this.obscureText = false,
    this.suffixIcon,
    this.onSubmitted,
    this.onChanged,
  });

  final TextEditingController controller;
  final IconData icon;
  final String label;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final FormFieldValidator<String>? validator;
  final List<TextInputFormatter>? inputFormatters;
  final bool obscureText;
  final Widget? suffixIcon;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;

  @override
  State<_AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<_AuthTextField> {
  final _fieldKey = GlobalKey<FormFieldState<String>>();
  late final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_validateWhenFocusLeaves);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_validateWhenFocusLeaves);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return TextFormField(
      key: _fieldKey,
      controller: widget.controller,
      focusNode: _focusNode,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      validator: widget.validator,
      inputFormatters: widget.inputFormatters,
      obscureText: widget.obscureText,
      onFieldSubmitted: widget.onSubmitted,
      onChanged: _handleChanged,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        labelText: widget.label,
        floatingLabelStyle: TextStyle(color: colors.selection),
        prefixIcon: Icon(widget.icon, color: colors.mutedIcon),
        suffixIcon: widget.suffixIcon,
        filled: true,
        fillColor: Colors.white.withValues(alpha: .06),
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
          borderSide: BorderSide(color: colors.selection, width: 1.4),
        ),
      ),
    );
  }

  void _validateWhenFocusLeaves() {
    if (_focusNode.hasFocus) return;

    _fieldKey.currentState?.validate();
  }

  void _handleChanged(String value) {
    widget.onChanged?.call(value);

    final field = _fieldKey.currentState;
    if (field == null || !field.hasError) return;

    field.validate();
  }
}

class _AuthBackground extends StatelessWidget {
  const _AuthBackground({required this.colors});

  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors.backgroundGradient,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -86,
            left: -74,
            child: _Glow(size: 240, color: colors.ambientGlows[0]),
          ),
          Positioned(
            right: -110,
            bottom: 120,
            child: _Glow(size: 280, color: colors.ambientGlows[1]),
          ),
          Positioned(
            left: 58,
            bottom: -140,
            child: _Glow(size: 300, color: colors.ambientGlows[2]),
          ),
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [BoxShadow(color: color, blurRadius: 90, spreadRadius: 35)],
      ),
    );
  }
}
