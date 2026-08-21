import 'package:flutter/material.dart';

import '../../widgets/login_sheet.dart';

/// Legacy route retained for compatibility. OTP/phone verification is disabled
/// in Mataheko. Account-required actions use the normal LoginSheet instead.
class PhoneLoginScreen extends StatelessWidget {
  const PhoneLoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign in to continue')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 56),
              const SizedBox(height: 16),
              const Text(
                'Sign in only when you need an account action.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () async {
                  final result = await showModalBottomSheet<bool>(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    builder: (_) => const LoginSheet(),
                  );
                  if (result == true && context.mounted) {
                    Navigator.of(context).pop(true);
                  }
                },
                icon: const Icon(Icons.login),
                label: const Text('Sign in / Create account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
