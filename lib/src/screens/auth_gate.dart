import 'package:appwrite/models.dart' as models;
import 'package:flutter/material.dart';
import 'package:stadium/src/screens/auth_page.dart';
import 'package:stadium/src/screens/manager_main_page.dart';
import 'package:stadium/src/screens/main_navigation_page.dart';
import 'package:stadium/src/services/auth_service.dart';
import 'package:stadium/src/theme/app_theme.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final Future<models.User?> _initialUser = authService.currentUser();
  models.User? _user;
  bool _signedOut = false;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<models.User?>(
      future: _initialUser,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _AuthLoadingView();
        }

        final user = _signedOut ? null : (_user ?? snapshot.data);

        if (user == null) {
          return AuthPage(onAuthenticated: _handleAuthenticated);
        }

        if (_isManager(user)) {
          return ManagerMainPage(user: user, onSignedOut: _handleSignedOut);
        }

        return MainNavigationPage(user: user, onSignedOut: _handleSignedOut);
      },
    );
  }

  bool _isManager(models.User user) => user.labels.contains('manager');

  void _handleAuthenticated(models.User user) {
    setState(() {
      _user = user;
      _signedOut = false;
    });
  }

  void _handleSignedOut() {
    setState(() {
      _user = null;
      _signedOut = true;
    });
  }
}

class _AuthLoadingView extends StatelessWidget {
  const _AuthLoadingView();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors.backgroundGradient,
          ),
        ),
        child: const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
