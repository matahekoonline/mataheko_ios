import 'package:flutter/material.dart';
import '../models/user_role.dart';
import '../services/auth_service.dart';
import 'bio_data_screen.dart';

class LoginSheet extends StatefulWidget {
  final String actionLabel;
  const LoginSheet({super.key, this.actionLabel = 'continue'});

  @override
  State<LoginSheet> createState() => _LoginSheetState();
}

class _LoginSheetState extends State<LoginSheet> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isRegister = false;
  bool _loading = false;
  String? _error;
  UserRole _selectedRole = UserRole.buyer;

  Future<void> _submitEmail() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_isRegister) {
        await AuthService.instance.registerWithEmail(
          _emailController.text.trim(),
          _passwordController.text.trim(),
          _selectedRole,
        );
        await _afterRegistration(_selectedRole);
      } else {
        await AuthService.instance.signInWithEmail(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
        if (mounted) Navigator.pop(context, true);
      }
    } catch (e) {
      final msg = e.toString();

      if (_isRegister && msg.contains('email-already-in-use')) {
        setState(() => _loading = false);
        await _promptExistingAccount();
        return;
      }

      if (!_isRegister && msg.contains('user-not-found')) {
        // Older Firebase Auth error code — some SDK versions / other auth
        // providers still send this distinct, unambiguous "no such email"
        // error, so we can be direct about it.
        setState(() => _loading = false);
        await _promptNoAccount();
        return;
      }

      if (!_isRegister && msg.contains('invalid-credential')) {
        // Current Firebase Auth deliberately merges "no account with that
        // email" and "wrong password" into this one generic code, as an
        // anti-enumeration measure -- it will not tell us which happened.
        // Treat it as ambiguous rather than defaulting to "wrong password"
        // (which used to mislead people who never had an account at all).
        setState(() => _loading = false);
        await _promptInvalidCredential();
        return;
      }

      setState(() => _error = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Shown when someone tries to log in with an email that has no
  /// matching account — offers to switch them straight into registration
  /// instead of leaving them stuck on an error.
  Future<void> _promptNoAccount() async {
    if (!mounted) return;
    final shouldRegister = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('No Account Found'),
        content: Text(
          'We could not find an account registered with ${_emailController.text.trim()}. '
              'Would you like to create one?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Create Account'),
          ),
        ],
      ),
    );
    if (shouldRegister == true && mounted) {
      setState(() {
        _isRegister = true;
        _error = null;
      });
    }
  }

  /// Shown on Firebase's generic invalid-credential error, which fires for
  /// BOTH a wrong password AND an email with no account at all — Firebase
  /// won't tell us which, on purpose. Rather than guess, this is honest
  /// about the ambiguity and still offers a way forward either way: try
  /// again, or create an account if that's actually what's missing.
  Future<void> _promptInvalidCredential() async {
    if (!mounted) return;
    final shouldRegister = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign In Failed'),
        content: Text(
          'The email and password for ${_emailController.text.trim()} don\'t match any account. '
              'Double-check your password, or create a new account if you haven\'t signed up yet.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Try Again'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Create Account'),
          ),
        ],
      ),
    );
    if (shouldRegister == true && mounted) {
      setState(() {
        _isRegister = true;
        _error = null;
      });
    }
  }

  /// Shown when someone tries to register with an email that's already
  /// taken — nudges them to log in instead of leaving it as easy-to-miss
  /// inline red text.
  Future<void> _promptExistingAccount() async {
    if (!mounted) return;
    final shouldLogIn = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Account Already Exists'),
        content: Text(
          'An account is already registered with ${_emailController.text.trim()}. '
              'Please log in instead.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log In'),
          ),
        ],
      ),
    );
    if (shouldLogIn == true && mounted) {
      setState(() {
        _isRegister = false;
        _error = null;
      });
    }
  }

  Future<void> _submitGoogle() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = await AuthService.instance.signInWithGoogle();
      if (user == null) {
        // cancelled
        if (mounted) setState(() => _loading = false);
        return;
      }

      final isNew = await AuthService.instance.isNewGoogleUser(user.uid);
      if (isNew && mounted) {
        // First time Google sign-in — ask which role before finishing
        final role = await _askRolePicker();
        if (role != null) {
          await AuthService.instance.setUserRole(user.uid, role);
          await _afterRegistration(role);
          return;
        }
        // Picker was escaped (e.g. a back-gesture) without a choice —
        // this is a brand-new Google account with nothing saved for it
        // yet, so sign them back out rather than silently completing.
        await AuthService.instance.signOut();
        if (mounted) setState(() => _loading = false);
        return;
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _error = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Routes every newly-registered user through the bio data screen —
  /// buyers need name/phone/area same as anyone else, they just don't see
  /// the category picker or Ghana Card section (that's gated inside
  /// BioDataScreen by role, not here).
  ///
  /// If they back out of BioDataScreen without submitting it (Navigator.pop
  /// with no result, or a system back-swipe), `completed` comes back null,
  /// not true — treating that as success used to leave a half-registered
  /// account (a users/{uid} doc with just a role, and a live Auth account)
  /// permanently in the database. Now an incomplete attempt is fully rolled
  /// back instead.
  Future<void> _afterRegistration(UserRole role) async {
    if (!mounted) return;

    final completed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => BioDataScreen(role: role)),
    );

    if (completed == true) {
      if (mounted) Navigator.pop(context, true);
      return;
    }

    // Abandoned mid-registration — don't leave anything saved.
    await AuthService.instance.deleteIncompleteRegistration();
    if (mounted) {
      setState(() => _error = 'Registration was not completed, so nothing was saved. You can sign up again anytime.');
    }
  }

  Future<UserRole?> _askRolePicker() {
    return showDialog<UserRole>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('One last step'),
        content: const Text('How will you be using this app?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, UserRole.buyer),
            child: const Text('Buy / Order Services'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, UserRole.provider),
            child: const Text('Offer a Service'),
          ),
        ],
      ),
    );
  }

  String _friendlyError(Object e) {
    final msg = e.toString();
    if (msg.contains('user-not-found')) return 'No account found with that email address.';
    if (msg.contains('wrong-password') || msg.contains('invalid-credential')) {
      return 'Incorrect password. Please try again.';
    }
    if (msg.contains('email-already-in-use')) return 'An account with that email already exists.';
    if (msg.contains('weak-password')) return 'Password should be at least 6 characters.';
    if (msg.contains('invalid-email')) return 'Please enter a valid email address.';
    if (msg.contains('account-exists-with-different-credential')) {
      return 'That email is already registered with a password. Please log in with email and password instead.';
    }
    if (msg.contains('too-many-requests')) {
      return 'Too many attempts. Please wait a moment and try again.';
    }
    return 'Something went wrong. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Text('Log in to ${widget.actionLabel}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text('Browsing stays free — this is only needed to keep the community safe.',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            if (_isRegister) ...[
              const Text('I want to:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 8),
              SegmentedButton<UserRole>(
                segments: const [
                  ButtonSegment(
                    value: UserRole.buyer,
                    label: Text('Buy / Order'),
                    icon: Icon(Icons.shopping_bag_outlined),
                  ),
                  ButtonSegment(
                    value: UserRole.provider,
                    label: Text('Offer Services'),
                    icon: Icon(Icons.handyman_outlined),
                  ),
                ],
                selected: {_selectedRole},
                onSelectionChanged: (s) => setState(() => _selectedRole = s.first),
              ),
              const SizedBox(height: 18),
            ],
            OutlinedButton.icon(
              onPressed: _loading ? null : _submitGoogle,
              icon: const Icon(Icons.g_mobiledata, size: 26),
              label: const Text('Continue with Google'),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
            ),
            const SizedBox(height: 16),
            Row(children: [
              const Expanded(child: Divider()),
              Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text('or', style: TextStyle(color: Colors.grey[500], fontSize: 12))),
              const Expanded(child: Divider()),
            ]),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
            ],
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: _loading ? null : _submitEmail,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _loading
                  ? const SizedBox(
                  height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(_isRegister ? 'Create account' : 'Log in'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _loading ? null : () => setState(() => _isRegister = !_isRegister),
              child: Text(_isRegister ? 'Already have an account? Log in' : 'New here? Create an account'),
            ),
          ],
        ),
      ),
    );
  }
}