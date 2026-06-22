import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:flutter/material.dart';
import 'package:stadium/src/models/stadium.dart';
import 'package:stadium/src/services/manager_stadium_service.dart';
import 'package:stadium/src/theme/app_theme.dart';
import 'package:stadium/src/widgets/app_notification.dart';

class ManagerStadiumPage extends StatefulWidget {
  const ManagerStadiumPage({super.key, required this.user, this.repository});

  final models.User user;
  final ManagerStadiumRepository? repository;

  @override
  State<ManagerStadiumPage> createState() => _ManagerStadiumPageState();
}

class _ManagerStadiumPageState extends State<ManagerStadiumPage> {
  late Future<Stadium?> _stadiumFuture = _loadStadium();

  ManagerStadiumRepository get _repository =>
      widget.repository ?? managerStadiumService;

  Future<Stadium?> _loadStadium() {
    return _repository.managerStadium(widget.user.$id);
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
          child: FutureBuilder<Stadium?>(
            future: _stadiumFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return _ManagerStatusView(
                  title: 'Could not load your stadium',
                  subtitle: _errorMessage(snapshot.error),
                  actionLabel: 'Retry',
                  onAction: _refresh,
                  icon: Icons.error_outline_rounded,
                );
              }

              final stadium = snapshot.data;
              if (stadium == null) {
                return _ManagerStatusView(
                  title: 'Create your stadium',
                  subtitle:
                      'No stadium found for your manager account yet. Create it now so regular users can discover and book it.',
                  actionLabel: 'Create stadium',
                  onAction: _openCreateForm,
                  icon: Icons.add_business_rounded,
                );
              }

              return _ManagerStadiumDetails(stadium: stadium);
            },
          ),
        ),
      ),
    );
  }

  String _errorMessage(Object? error) {
    if (error is AppwriteException) {
      return error.message ?? 'Please verify your Appwrite stadiums table.';
    }

    return 'Please try again in a moment.';
  }

  void _refresh() {
    setState(() {
      _stadiumFuture = _loadStadium();
    });
  }

  Future<void> _openCreateForm() async {
    final created = await showModalBottomSheet<Stadium>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CreateManagerStadiumSheet(
        onSubmit: (form) => _repository.createManagerStadium(
          managerId: widget.user.$id,
          name: form.name,
          location: form.location,
          price: form.price,
        ),
      ),
    );

    if (!mounted || created == null) return;

    showAppNotification(
      context,
      title: 'Stadium created',
      message: '${created.name} is now available for users.',
      type: AppNotificationType.success,
    );

    _refresh();
  }
}

class _ManagerStatusView extends StatelessWidget {
  const _ManagerStatusView({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colors.glassFill,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: colors.glassBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 34),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .7),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: Text(actionLabel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ManagerStadiumDetails extends StatelessWidget {
  const _ManagerStadiumDetails({required this.stadium});

  final Stadium stadium;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
      physics: const BouncingScrollPhysics(),
      children: [
        Text(
          'Your stadium',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'This is what regular users will see and book.',
          style: TextStyle(color: Colors.white.withValues(alpha: .68)),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: colors.glassFill,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: colors.glassBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(stadium.icon, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      stadium.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _DetailRow(label: 'Location', value: stadium.location),
              _DetailRow(label: 'Price / hour', value: '\$${stadium.price}'),
              _DetailRow(label: 'Rating', value: stadium.rating.toString()),
              _DetailRow(label: 'Availability', value: stadium.available),
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: .65),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CreateManagerStadiumSheet extends StatefulWidget {
  const _CreateManagerStadiumSheet({required this.onSubmit});

  final Future<Stadium> Function(_StadiumFormValue value) onSubmit;

  @override
  State<_CreateManagerStadiumSheet> createState() =>
      _CreateManagerStadiumSheetState();
}

class _CreateManagerStadiumSheetState
    extends State<_CreateManagerStadiumSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _priceController = TextEditingController(text: '80');
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;
    final colors = context.appColors;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Create stadium profile',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _FormInput(
                    controller: _nameController,
                    label: 'Stadium name',
                    validator: _required,
                  ),
                  _FormInput(
                    controller: _locationController,
                    label: 'Location',
                    validator: _required,
                  ),
                  _FormInput(
                    controller: _priceController,
                    label: 'Price per hour',
                    keyboardType: TextInputType.number,
                    validator: _priceValidator,
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isSaving ? null : _save,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check_rounded),
                      label: Text(_isSaving ? 'Saving...' : 'Create stadium'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) return 'This field is required';
    return null;
  }

  String? _priceValidator(String? value) {
    final requiredError = _required(value);
    if (requiredError != null) return requiredError;

    final parsed = int.tryParse(value!.trim());
    if (parsed == null || parsed <= 0) return 'Enter a valid positive number';
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final stadium = await widget.onSubmit(
        _StadiumFormValue(
          name: _nameController.text.trim(),
          location: _locationController.text.trim(),
          price: int.parse(_priceController.text.trim()),
        ),
      );

      if (!mounted) return;
      Navigator.of(context).pop(stadium);
    } on AppwriteException catch (error) {
      if (!mounted) return;

      showAppNotification(
        context,
        title: 'Could not create stadium',
        message: error.message ?? 'Please check your Appwrite stadiums table.',
        type: AppNotificationType.error,
      );
    } catch (_) {
      if (!mounted) return;

      showAppNotification(
        context,
        title: 'Could not create stadium',
        message: 'Please try again.',
        type: AppNotificationType.error,
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}

class _FormInput extends StatelessWidget {
  const _FormInput({
    required this.controller,
    required this.label,
    this.keyboardType,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}

class _StadiumFormValue {
  const _StadiumFormValue({
    required this.name,
    required this.location,
    required this.price,
  });

  final String name;
  final String location;
  final int price;
}
