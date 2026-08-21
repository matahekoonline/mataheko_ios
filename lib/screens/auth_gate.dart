import 'package:flutter/material.dart';

import 'main_screen.dart';

/// Mataheko is guest-first: users can browse the app without signing in.
/// Authentication is requested only when an action requires an account.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return const MainScreen();
  }
}
