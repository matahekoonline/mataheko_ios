import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../widgets/login_sheet.dart';
import 'admin_dashboard_screen.dart';
import 'rider_mode_screen.dart';
import 'aboboyaa_rider_mode_screen.dart';
import 'my_rides_screen.dart';
import 'my_activity_screen.dart';
import 'notification_settings_screen.dart';
import '../screens/provider_registration_screen.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  bool _loading = true;
  bool _saving = false;

  Map<String, dynamic> _profile = {};
  Map<String, dynamic> _emergency = {};

  StreamSubscription<User?>? _authSubscription;

  @override
  void initState() {
    super.initState();

    // AccountScreen lives inside MainScreen's IndexedStack, so its State can
    // remain mounted across logout. Listen directly to auth changes instead
    // of relying on a manual refresh.
    _authSubscription = AuthService.instance.authStateChanges.listen((user) {
      if (!mounted) return;

      if (user == null) {
        setState(() {
          _profile = {};
          _emergency = {};
          _loading = false;
        });
        return;
      }

      setState(() => _loading = true);
      _loadProfile();
    });

    _loadProfile();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // USER
  // ---------------------------------------------------------------------------

  User? get _firebaseUser => AuthService.instance.currentUser;

  String get _uid => _firebaseUser?.uid ?? '';

  // ---------------------------------------------------------------------------
  // PROFILE
  // ---------------------------------------------------------------------------

  Future<void> _loadProfile() async {
    final user = _firebaseUser;

    if (user == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _profile = {};
          _emergency = {};
        });
      }
      return;
    }

    final loadingUid = user.uid;

    try {
      final snap = await _db.collection('users').doc(loadingUid).get();
      final emergencySnap = await _db
          .collection('app_settings')
          .doc('emergency_contacts')
          .get();

      // The user may have logged out while Firestore was loading. Never put
      // the previous user's profile back into the guest AccountScreen.
      if (mounted && AuthService.instance.currentUser?.uid == loadingUid) {
        setState(() {
          _profile = snap.data() ?? {};
          _emergency = emergencySnap.data() ?? {};
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not load your profile: $e'),
          ),
        );
      }
    }
  }

  Future<void> _createUserProfileIfMissing() async {
    final user = _firebaseUser;

    if (user == null) return;

    final ref = _db.collection('users').doc(user.uid);
    final snap = await ref.get();

    if (snap.exists) return;

    await ref.set({
      'uid': user.uid,
      'email': user.email ?? '',
      'phoneNumber': user.phoneNumber ?? '',
      'displayName': user.displayName ?? '',
      'accountType': 'buyer',
      'providerStatus': 'none',
      'providerCategoryId': null,
      'providerCategoryName': null,
      'providerAvailable': false,
      'profileComplete': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _loadProfile();
  }

  // ---------------------------------------------------------------------------
  // SAFE PROFILE VALUES
  // ---------------------------------------------------------------------------

  String get _displayName {
    final candidates = [
      _profile['displayName'],
      _profile['fullName'],
      _profile['name'],
    ];

    for (final candidate in candidates) {
      final value = candidate?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }

    final first = _profile['firstName']?.toString().trim() ?? '';
    final last = _profile['lastName']?.toString().trim() ?? '';
    final combined = '$first $last'.trim();
    if (combined.isNotEmpty) return combined;

    if (_firebaseUser?.displayName?.trim().isNotEmpty == true) {
      return _firebaseUser!.displayName!.trim();
    }

    return 'User';
  }

  String get _firstName {
    final value = _profile['firstName'];

    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }

    final name = _displayName.split(' ');

    return name.isNotEmpty ? name.first : 'User';
  }

  String get _bio {
    final value = _profile['bio'];

    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }

    return 'No bio added yet.';
  }

  String get _location {
    final candidates = [
      _profile['location'],
      _profile['area'],
      _profile['stationArea'],
    ];
    for (final candidate in candidates) {
      final value = candidate?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return 'Location not added';
  }

  String get _profilePhoto {
    final candidates = [
      _profile['photoUrl'],
      _profile['profilePhotoUrl'],
      _profile['imageUrl'],
    ];
    for (final candidate in candidates) {
      final value = candidate?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  String get _accountType {
    final value = _profile['accountType'];

    if (value == 'provider') {
      return 'provider';
    }

    return 'buyer';
  }

  String get _providerStatus {
    final value = _profile['providerStatus'];

    if (value is String && value.isNotEmpty) {
      return value;
    }

    return 'none';
  }

  String get _providerCategoryName {
    final value = _profile['providerCategoryName'];

    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }

    return 'Not selected';
  }

  bool get _providerAvailable {
    return _profile['providerAvailable'] == true;
  }

  bool get _isProvider {
    return _accountType == 'provider';
  }

  bool get _hasProviderApplication {
    return _providerStatus != 'none';
  }

  bool get _isProviderApproved {
    return _providerStatus == 'approved';
  }

  // ---------------------------------------------------------------------------
  // PROFILE COMPLETENESS
  // ---------------------------------------------------------------------------

  double get _profileCompletion {
    // Photo is intentionally optional: the Account editor does not require
    // identity/profile photos, so a user who has supplied every requested
    // basic field must be able to reach 100%.
    int completed = 0;
    const total = 4;

    if (_displayName != 'User') completed++;

    final phone = _profile['phoneNumber']?.toString().trim() ??
        _profile['phone']?.toString().trim() ??
        _profile['mobile']?.toString().trim() ??
        _firebaseUser?.phoneNumber?.trim() ?? '';
    final email = _profile['email']?.toString().trim() ??
        _firebaseUser?.email?.trim() ?? '';
    if (phone.isNotEmpty || email.isNotEmpty) completed++;

    if (_location != 'Location not added') completed++;
    if (_bio != 'No bio added yet.') completed++;

    return completed / total;
  }

  String get _profileCompletionLabel {
    final percentage = (_profileCompletion * 100).round();

    return '$percentage% complete';
  }

  // ---------------------------------------------------------------------------
  // LOGIN
  // ---------------------------------------------------------------------------

  Future<void> _openLoginSheet() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (_) => const LoginSheet(
        actionLabel: 'manage your account',
      ),
    );

    if (result == true && mounted) {
      await _createUserProfileIfMissing();
      await _loadProfile();
      setState(() {});
    }
  }

  // ---------------------------------------------------------------------------
  // EDIT PROFILE
  //
  // Only ordinary/public information is editable here.
  //
  // Deliberately NOT editable:
  // - UID
  // - email verification state
  // - phone verification state
  // - provider status
  // - provider category
  // - admin status
  // - rider status
  // - identity documents
  // - verification documents
  // - internal security fields
  // ---------------------------------------------------------------------------

  Future<void> _editProfile() async {
    final nameController = TextEditingController(
      text: (_profile['displayName'] ??
              _profile['fullName'] ??
              _profile['name'] ??
              '')
          .toString(),
    );

    final firstNameController = TextEditingController(
      text: _profile['firstName']?.toString() ?? '',
    );

    final lastNameController = TextEditingController(
      text: _profile['lastName']?.toString() ?? '',
    );

    final bioController = TextEditingController(
      text: _profile['bio']?.toString() ?? '',
    );

    final locationController = TextEditingController(
      text: (_profile['location'] ?? _profile['area'] ?? _profile['stationArea'] ?? '')
          .toString(),
    );

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _EditProfileSheet(
          nameController: nameController,
          firstNameController: firstNameController,
          lastNameController: lastNameController,
          bioController: bioController,
          locationController: locationController,
        );
      },
    );

    if (result != true || !mounted) return;

    setState(() => _saving = true);

    try {
      final displayName = nameController.text.trim();
      final firstName = firstNameController.text.trim();
      final lastName = lastNameController.text.trim();
      final bio = bioController.text.trim();
      final location = locationController.text.trim();

      await _db.collection('users').doc(_uid).set(
        {
          'displayName': displayName,
          'fullName': displayName,
          'firstName': firstName,
          'lastName': lastName,
          'bio': bio,
          'location': location,
          'area': location,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      await _loadProfile();

      final phoneValue = _profile['phoneNumber']?.toString().trim() ??
          _profile['phone']?.toString().trim() ??
          _profile['mobile']?.toString().trim() ??
          _firebaseUser?.phoneNumber?.trim() ?? '';
      final emailValue = _profile['email']?.toString().trim() ??
          _firebaseUser?.email?.trim() ?? '';
      final complete = displayName.isNotEmpty &&
          phoneValue.isNotEmpty &&
          location.isNotEmpty &&
          bio.isNotEmpty;
      await _db.collection('users').doc(_uid).set({
        'profileComplete': complete,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await _loadProfile();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not update profile: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // BECOME PROVIDER
  // ---------------------------------------------------------------------------

  Future<void> _becomeProvider() async {
    if (_uid.isEmpty) return;

    // A category can be reserved before the detailed form is completed.
    // In that case the user must be able to resume the form instead of being
    // trapped behind a permanent 'Pending' dialog.
    if (_hasProviderApplication) {
      final application = await _db
          .collection('provider_applications')
          .doc(_uid)
          .get();
      final data = application.data() ?? {};
      final category = (data['categoryName'] ??
              data['category'] ??
              _providerCategoryName)
          .toString()
          .trim();
      final categoryId = (data['categoryId'] ?? category).toString().trim();
      final profileSubmitted = data['profileSubmitted'] == true;
      final providerCollection = data['providerCollection']?.toString().trim() ?? '';
      final providerDocId = data['providerDocId']?.toString().trim() ?? '';

      if (_providerStatus == 'pending' &&
          category.isNotEmpty &&
          (!profileSubmitted || providerCollection.isEmpty || providerDocId.isEmpty)) {
        if (!mounted) return;
        final completed = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => ProviderRegistrationScreen(
              categoryId: categoryId.isEmpty ? category : categoryId,
              categoryName: category,
            ),
          ),
        );
        if (completed == true && mounted) await _loadProfile();
        return;
      }

      await _showProviderStatus();
      return;
    }

    final category = await _selectProviderCategory();

    if (category == null || !mounted) return;

    final categoryId = category['id']?.toString() ?? '';
    final categoryName = category['name']?.toString() ?? '';

    if (categoryId.isEmpty || categoryName.isEmpty) {
      return;
    }

    await _showProviderConfirmation(
      categoryId: categoryId,
      categoryName: categoryName,
    );
  }

  // ---------------------------------------------------------------------------
  // CATEGORY SELECTION
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>?> _selectProviderCategory() async {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return _ProviderCategorySheet(
          firestore: _db,
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // PROVIDER CONFIRMATION
  // ---------------------------------------------------------------------------

  Future<void> _showProviderConfirmation({
    required String categoryId,
    required String categoryName,
  }) async {
    final agreed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Become a Service Provider'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'You are about to register as a service provider under:',
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.green.withOpacity(.25),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.category_outlined,
                      color: Colors.green,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        categoryName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Important: a user can register as a service provider '
                    'for only one category.',
              ),
              const SizedBox(height: 8),
              Text(
                'After submitting, your application will be reviewed '
                    'before your provider account becomes active.',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 13,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );

    if (agreed != true || !mounted) return;

    if (!mounted) return;

    final completed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ProviderRegistrationScreen(
          categoryId: categoryId,
          categoryName: categoryName,
        ),
      ),
    );

    if (completed == true && mounted) {
      await _loadProfile();
    }
  }

  // ---------------------------------------------------------------------------
  // PROVIDER APPLICATION
  // ---------------------------------------------------------------------------

  Future<void> _submitProviderApplication({
    required String categoryId,
    required String categoryName,
  }) async {
    if (_uid.isEmpty) return;

    setState(() => _saving = true);

    try {
      final userRef = _db.collection('users').doc(_uid);

      final existing = await userRef.get();

      final existingData = existing.data() ?? {};

      // -----------------------------------------------------------------------
      // HARD ONE-CATEGORY PROTECTION
      // -----------------------------------------------------------------------
      //
      // This prevents the normal dashboard from registering a second category.
      // IMPORTANT:
      // Firestore security rules should ALSO enforce this server-side.
      // -----------------------------------------------------------------------

      final existingCategoryId =
      existingData['providerCategoryId']?.toString();

      final existingStatus =
          existingData['providerStatus']?.toString() ?? 'none';

      if (existingCategoryId != null &&
          existingCategoryId.isNotEmpty &&
          existingStatus != 'none') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'You are already registered under '
                    '${existingData['providerCategoryName'] ?? 'another category'}.',
              ),
            ),
          );
        }

        return;
      }

      final applicationRef =
      _db.collection('provider_applications').doc(_uid);

      await applicationRef.set(
        {
          'uid': _uid,
          'email': _firebaseUser?.email ?? '',
          'categoryId': categoryId,
          'categoryName': categoryName,

          // User-safe information copied at application time.
          'displayName': _profile['displayName'] ?? '',
          'firstName': _profile['firstName'] ?? '',
          'lastName': _profile['lastName'] ?? '',
          'bio': _profile['bio'] ?? '',
          'location': _profile['location'] ?? '',
          'photoUrl': _profile['photoUrl'] ?? '',

          // Workflow.
          'status': 'pending',

          // Admin-only processing fields.
          'adminNote': '',
          'reviewedBy': null,
          'reviewedAt': null,

          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      await userRef.set(
        {
          'accountType': 'provider',
          'providerStatus': 'pending',
          'providerCategoryId': categoryId,
          'providerCategoryName': categoryName,
          'providerAvailable': false,
          'providerApplicationId': _uid,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      await _loadProfile();

      if (!mounted) return;

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Provider application submitted. Your application is now pending review.',
          ),
          duration: Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not submit provider application: $e',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // PROVIDER STATUS
  // ---------------------------------------------------------------------------

  Future<void> _showProviderStatus() async {
    String title = 'Provider Application';
    String message = '';
    IconData icon = Icons.info_outline;
    Color color = Colors.blue;

    switch (_providerStatus) {
      case 'pending':
        title = 'Application Pending';
        message =
        'Your service provider application is currently being reviewed.';
        icon = Icons.hourglass_top;
        color = Colors.orange;
        break;

      case 'approved':
        title = 'Provider Account Approved';
        message =
        'Your provider account has been approved. You can now manage your service.';
        icon = Icons.verified;
        color = Colors.green;
        break;

      case 'rejected':
        title = 'Application Not Approved';
        message =
        'Your provider application was not approved. Please contact support for more information.';
        icon = Icons.cancel_outlined;
        color = Colors.red;
        break;

      case 'suspended':
        title = 'Provider Account Suspended';
        message =
        'Your provider account is currently suspended. Please contact support.';
        icon = Icons.block;
        color = Colors.red;
        break;

      default:
        title = 'Provider Account';
        message = 'You have not registered as a provider.';
        break;
    }

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 10),
              Expanded(child: Text(title)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message),
              const SizedBox(height: 18),
              const Text(
                'Category',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(_providerCategoryName),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // PROVIDER AVAILABILITY
  // ---------------------------------------------------------------------------

  Future<void> _toggleProviderAvailability() async {
    if (!_isProviderApproved) return;

    try {
      await _db.collection('users').doc(_uid).set(
        {
          'providerAvailable': !_providerAvailable,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      await _loadProfile();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not update availability: $e',
            ),
          ),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // SECURITY
  // ---------------------------------------------------------------------------

  Future<void> _openSecurity() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return _SecuritySheet(
          user: _firebaseUser,
          onSignOutAll: _signOut,
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // SIGN OUT
  // ---------------------------------------------------------------------------

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Sign out?'),
          content: const Text(
            'You will need to sign in again to manage your account.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sign Out'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await AuthService.instance.signOut();
    // AuthGate listens to authStateChanges() and will replace the signed-in
    // shell with the login screen. Do not pop AccountScreen here: it is part
    // of the authenticated shell and popping it can expose a dead/blank route.

  }

  // ---------------------------------------------------------------------------
// DELETE ACCOUNT REQUEST
// ---------------------------------------------------------------------------

  Future<void> _requestAccountDeletion() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Request account deletion'),
          content: const Text(
            'For security, account deletion is handled as a request. '
                'Your account will not be immediately deleted from this screen.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Submit Request'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      // -----------------------------------------------------------------------
      // 1. Save the deletion request for the Admin Dashboard
      // -----------------------------------------------------------------------
      await _db
          .collection('account_deletion_requests')
          .doc(_uid)
          .set(
        {
          'uid': _uid,
          'email': _firebaseUser?.email ?? '',
          'displayName': _displayName,
          'status': 'pending',
          'requestedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      // -----------------------------------------------------------------------
      // 2. Notify Admin
      // -----------------------------------------------------------------------
      await NotificationService.instance.notifyAdminAction(
        title: 'Account deletion request',
        body: '$_displayName has requested account deletion.',
        category: 'account_deletion',
        itemId: _uid,
      );

      // -----------------------------------------------------------------------
      // 3. Tell the user that the request was successfully submitted
      // -----------------------------------------------------------------------
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Account deletion request submitted successfully.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not submit account deletion request: $e',
          ),
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // ADMIN
  // ---------------------------------------------------------------------------

  Widget _adminEntry() {
    return FutureBuilder<bool>(
      future: AuthService.instance.isAdmin(),
      builder: (context, snapshot) {
        if (snapshot.data != true) {
          return const SizedBox.shrink();
        }

        return _DashboardTile(
          icon: Icons.admin_panel_settings_outlined,
          title: 'Admin Dashboard',
          subtitle: 'Manage the platform',
          color: Colors.deepPurple,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AdminDashboardScreen(),
              ),
            );
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // RIDER
  // ---------------------------------------------------------------------------

  Widget _riderEntry() {
    return FutureBuilder<bool>(
      future: AuthService.instance.isOkadaRider(),
      builder: (context, snapshot) {
        if (snapshot.data != true) {
          return const SizedBox.shrink();
        }

        return _DashboardTile(
          icon: Icons.motorcycle_outlined,
          title: 'Rider Mode',
          subtitle: 'Manage your rider activity',
          color: Colors.green,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const RiderModeScreen(),
              ),
            );
          },
        );
      },
    );
  }

  Widget _aboboyaaRiderEntry() {
    return FutureBuilder<bool>(
      future: AuthService.instance.isAboboyaaRider(),
      builder: (context, snapshot) {
        if (snapshot.data != true) {
          return const SizedBox.shrink();
        }

        return _DashboardTile(
          icon: Icons.two_wheeler_outlined,
          title: 'Rider Mode',
          subtitle: 'Manage your Aboboyaa availability',
          color: Colors.green,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AboboyaaRiderModeScreen(),
              ),
            );
          },
        );
      },
    );
  }

  Widget _rideAlongEntry() {
    return FutureBuilder<bool>(
      future: AuthService.instance.isRideAlongDriver(),
      builder: (context, snapshot) {
        if (snapshot.data != true) {
          return const SizedBox.shrink();
        }

        return _DashboardTile(
          icon: Icons.directions_car_outlined,
          title: 'My Rides',
          subtitle: 'Manage your posted Ride Along trips',
          color: Colors.green,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const MyRidesScreen(),
              ),
            );
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final user = _firebaseUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Account',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: user == null
          ? _buildSignedOut()
          : _loading
          ? const Center(
        child: CircularProgressIndicator(),
      )
          : RefreshIndicator(
        onRefresh: _loadProfile,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            16,
            16,
            16,
            32,
          ),
          children: [
            _buildProfileHeader(),
            const SizedBox(height: 18),
            _buildProfileCompleteness(),
            const SizedBox(height: 24),
            _buildProviderSection(),
            const SizedBox(height: 24),
            _buildActivitySection(),
            const SizedBox(height: 24),
            _buildSettingsSection(),
            const SizedBox(height: 24),
            _adminEntry(),
            _riderEntry(),
            _aboboyaaRiderEntry(),
            _rideAlongEntry(),
            const SizedBox(height: 12),
            _buildSignOutButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyContacts() {
    final title = (_emergency['title']?.toString().trim().isNotEmpty == true)
        ? _emergency['title'].toString().trim()
        : 'Emergency Contacts';
    final description =
        _emergency['description']?.toString().trim() ?? '';
    final primary = _emergency['primaryPhone']?.toString().trim() ?? '';
    final secondary =
        _emergency['secondaryPhone']?.toString().trim() ?? '';

    if (primary.isEmpty && secondary.isEmpty) {
      return Card(
        elevation: 0,
        child: ListTile(
          leading: const Icon(Icons.emergency_outlined, color: Colors.red),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: const Text('Emergency contact information will appear here.'),
        ),
      );
    }

    Future<void> call(String number) async {
      final uri = Uri(scheme: 'tel', path: number);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    }

    return Card(
      elevation: 0,
      color: Colors.red.withOpacity(.04),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.red.withOpacity(.14)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.emergency_outlined, color: Colors.red),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
              ],
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 7),
              Text(description, style: TextStyle(color: Colors.grey[700])),
            ],
            const SizedBox(height: 10),
            if (primary.isNotEmpty)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  child: Icon(Icons.call_outlined),
                ),
                title: const Text('Primary emergency contact'),
                subtitle: Text(primary),
                trailing: IconButton(
                  tooltip: 'Call',
                  onPressed: () => call(primary),
                  icon: const Icon(Icons.phone, color: Colors.red),
                ),
              ),
            if (secondary.isNotEmpty)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  child: Icon(Icons.phone_in_talk_outlined),
                ),
                title: const Text('Secondary emergency contact'),
                subtitle: Text(secondary),
                trailing: IconButton(
                  tooltip: 'Call',
                  onPressed: () => call(secondary),
                  icon: const Icon(Icons.phone, color: Colors.red),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SIGNED OUT
  // ---------------------------------------------------------------------------

  Widget _buildSignedOut() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 90,
              width: 90,
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(.10),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person_outline,
                size: 48,
                color: Colors.green[700],
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'Manage your account',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Sign in to manage your profile, services, '
                  'saved items and account settings.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[700],
                height: 1.45,
              ),
            ),
            const SizedBox(height: 26),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _openLoginSheet,
                icon: const Icon(Icons.login),
                label: const Text('Sign In / Sign Up'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    vertical: 15,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // PROFILE HEADER
  // ---------------------------------------------------------------------------

  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.green[800]!,
            Colors.green[600]!,
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildAvatar(),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hello, $_firstName',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        _AccountBadge(
                          label: _isProvider
                              ? 'Service Provider'
                              : 'Buyer',
                          icon: _isProvider
                              ? Icons.storefront_outlined
                              : Icons.shopping_bag_outlined,
                        ),
                        if (_isProviderApproved) ...[
                          const SizedBox(width: 6),
                          const _AccountBadge(
                            label: 'Verified',
                            icon: Icons.verified,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _saving ? null : _editProfile,
                icon: const Icon(
                  Icons.edit_outlined,
                  color: Colors.white,
                ),
                tooltip: 'Edit profile',
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  color: Colors.white,
                  size: 19,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _location,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_bio != 'No bio added yet.') ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _bio,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    if (_profilePhoto.isNotEmpty) {
      return CircleAvatar(
        radius: 34,
        backgroundColor: Colors.white,
        backgroundImage: NetworkImage(_profilePhoto),
      );
    }

    return CircleAvatar(
      radius: 34,
      backgroundColor: Colors.white,
      child: Text(
        _displayName.isNotEmpty
            ? _displayName.substring(0, 1).toUpperCase()
            : 'U',
        style: TextStyle(
          fontSize: 25,
          fontWeight: FontWeight.w800,
          color: Colors.green[700],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // PROFILE COMPLETENESS
  // ---------------------------------------------------------------------------

  Widget _buildProfileCompleteness() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.grey.withOpacity(.16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_outline),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Profile completeness',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                _profileCompletionLabel,
                style: TextStyle(
                  color: Colors.green[700],
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: _profileCompletion,
              minHeight: 8,
              backgroundColor: Colors.grey[200],
              color: Colors.green[700],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Complete your basic profile so people can recognize you.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // PROVIDER SECTION
  // ---------------------------------------------------------------------------

  Widget _buildProviderSection() {
    if (!_isProvider) {
      return _buildBecomeProviderCard();
    }

    return _buildProviderDashboardCard();
  }

  Widget _buildBecomeProviderCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.green.withOpacity(.20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 46,
                width: 46,
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.storefront_outlined,
                  color: Colors.green[700],
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Offer your services',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Become a service provider',
                      style: TextStyle(
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Register under one service category and reach people '
                'looking for your services.',
            style: TextStyle(
              color: Colors.grey[700],
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _becomeProvider,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              child: const Text(
                'Become a Service Provider',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderDashboardCard() {
    Color statusColor = Colors.orange;
    IconData statusIcon = Icons.hourglass_top;

    if (_providerStatus == 'approved') {
      statusColor = Colors.green;
      statusIcon = Icons.verified;
    } else if (_providerStatus == 'rejected' ||
        _providerStatus == 'suspended') {
      statusColor = Colors.red;
      statusIcon = Icons.warning_amber_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.grey.withOpacity(.16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.storefront_outlined,
                color: Colors.green,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Service Provider',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
              ),
              Icon(
                statusIcon,
                color: statusColor,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _InfoRow(
            label: 'Category',
            value: _providerCategoryName,
          ),
          const SizedBox(height: 9),
          _InfoRow(
            label: 'Application',
            value: _prettyStatus(_providerStatus),
          ),
          if (_isProviderApproved) ...[
            const SizedBox(height: 9),
            _InfoRow(
              label: 'Availability',
              value: _providerAvailable
                  ? 'Available'
                  : 'Currently unavailable',
            ),
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: _providerAvailable
                    ? Colors.green.withOpacity(.08)
                    : Colors.orange.withOpacity(.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    _providerAvailable
                        ? Icons.circle
                        : Icons.pause_circle_outline,
                    size: 12,
                    color: _providerAvailable
                        ? Colors.green
                        : Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _providerAvailable
                          ? 'Customers can see you as available.'
                          : 'Your service is currently unavailable.',
                      style: const TextStyle(
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _toggleProviderAvailability,
                    icon: Icon(
                      _providerAvailable
                          ? Icons.pause
                          : Icons.play_arrow,
                    ),
                    label: Text(
                      _providerAvailable
                          ? 'Set Unavailable'
                          : 'Set Available',
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _showProviderStatus,
            child: const Text('View Provider Status'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ACTIVITY
  // ---------------------------------------------------------------------------

  Widget _buildActivitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: _SectionTitle(title: 'My Activity'),
            ),
            TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MyActivityScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('View all'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.65,
          children: [
            _DashboardTile(
              icon: Icons.favorite_border,
              title: 'Saved',
              subtitle: 'Your favourites',
              onTap: () => _openActivity('saved'),
            ),
            _DashboardTile(
              icon: Icons.chat_bubble_outline,
              title: 'Enquiries',
              subtitle: 'Your conversations',
              onTap: () => _openActivity('enquiries'),
            ),
            _DashboardTile(
              icon: Icons.history,
              title: 'Recently Viewed',
              subtitle: 'Your history',
              onTap: () => _openActivity('viewed'),
            ),
            _DashboardTile(
              icon: Icons.star_border,
              title: 'Reviews',
              subtitle: 'Ratings & reviews',
              onTap: () => _openActivity('reviews'),
            ),
          ],
        ),
      ],
    );
  }

  void _openActivity(String section) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MyActivityScreen(initialSection: section),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SETTINGS
  // ---------------------------------------------------------------------------

  Widget _buildSettingsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(
          title: 'Account & Settings',
        ),
        const SizedBox(height: 10),
        _SettingsTile(
          icon: Icons.edit_outlined,
          title: 'Edit Profile',
          subtitle: 'Name, bio and basic information',
          onTap: _editProfile,
        ),
        _SettingsTile(
          icon: Icons.lock_outline,
          title: 'Security & Privacy',
          subtitle: 'Password, account security and privacy',
          onTap: _openSecurity,
        ),
        _SettingsTile(
          icon: Icons.notifications_none_outlined,
          title: 'Notifications',
          subtitle: 'Manage your notification preferences',
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const NotificationSettingsScreen(),
              ),
            );
          },
        ),
        _SettingsTile(
          icon: Icons.help_outline,
          title: 'Help & Support',
          subtitle: 'Help, support and emergency contacts',
          onTap: _showHelpAndSupport,
        ),
        _SettingsTile(
          icon: Icons.delete_outline,
          title: 'Delete Account',
          subtitle: 'Request permanent account deletion',
          iconColor: Colors.red,
          onTap: _requestAccountDeletion,
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // HELP & SUPPORT
  // ---------------------------------------------------------------------------

  Future<void> _showHelpAndSupport() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Help & Support',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Get help with your account and reach an emergency contact when you need one.',
                  style: TextStyle(color: Colors.grey[700]),
                ),
                const SizedBox(height: 16),
                _SettingsTile(
                  icon: Icons.help_center_outlined,
                  title: 'Help Center',
                  subtitle: 'Find answers and guidance for using Mataheko',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _comingSoon('Help Center');
                  },
                ),
                _SettingsTile(
                  icon: Icons.support_agent_outlined,
                  title: 'Contact Support',
                  subtitle: 'Get assistance with an account or app issue',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _comingSoon('Contact Support');
                  },
                ),
                const SizedBox(height: 8),
                const Text(
                  'Emergency Contacts',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                _buildEmergencyContacts(),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // SIGN OUT BUTTON
  // ---------------------------------------------------------------------------

  Widget _buildSignOutButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _signOut,
        icon: const Icon(Icons.logout),
        label: const Text('Sign Out'),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red[700],
          side: BorderSide(
            color: Colors.red.withOpacity(.35),
          ),
          padding: const EdgeInsets.symmetric(
            vertical: 14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------

  String _prettyStatus(String status) {
    if (status.isEmpty) return 'Not registered';

    return status[0].toUpperCase() +
        status.substring(1).replaceAll('_', ' ');
  }

  void _comingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature is coming soon.'),
      ),
    );
  }
}

// =============================================================================
// EDIT PROFILE SHEET
// =============================================================================

class _EditProfileSheet extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController firstNameController;
  final TextEditingController lastNameController;
  final TextEditingController bioController;
  final TextEditingController locationController;

  const _EditProfileSheet({
    required this.nameController,
    required this.firstNameController,
    required this.lastNameController,
    required this.bioController,
    required this.locationController,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Edit Profile',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Only ordinary profile information can be changed here.',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 22),

            TextField(
              controller: nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Display name',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: firstNameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'First name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: lastNameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Last name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            TextField(
              controller: locationController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Location / Community',
                prefixIcon: Icon(Icons.location_on_outlined),
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 14),

            TextField(
              controller: bioController,
              minLines: 3,
              maxLines: 5,
              maxLength: 250,
              decoration: const InputDecoration(
                labelText: 'About me',
                hintText: 'Tell people a little about yourself...',
                alignLabelWithHint: true,
                prefixIcon: Padding(
                  padding: EdgeInsets.only(bottom: 45),
                  child: Icon(Icons.info_outline),
                ),
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 8),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.security,
                    size: 18,
                    color: Colors.orange[800],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Identity, verification and security information '
                          'cannot be edited from this screen.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange[900],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context, true);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    vertical: 15,
                  ),
                ),
                child: const Text('Save Changes'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// PROVIDER CATEGORY SHEET
// =============================================================================

class _ProviderCategorySheet extends StatelessWidget {
  final FirebaseFirestore firestore;

  const _ProviderCategorySheet({
    required this.firestore,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * .78,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 18),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Choose your service category',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(height: 5),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'You can register as a provider under only one category.',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: firestore
                  .collection('categories')
                  .orderBy('order')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'Could not load service categories.\n\n'
                            '${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                final docs = snapshot.data?.docs ?? [];

                final categories = docs.where((doc) {
                  final data = doc.data();

                  // Only active categories can receive providers.
                  return data['active'] != false;
                }).toList();

                if (categories.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(30),
                      child: Text(
                        'No service categories are currently available.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    16,
                    0,
                    16,
                    30,
                  ),
                  itemCount: categories.length,
                  separatorBuilder: (_, __) =>
                  const SizedBox(height: 9),
                  itemBuilder: (context, index) {
                    final doc = categories[index];
                    final data = doc.data();

                    final name =
                        data['name']?.toString() ?? 'Unnamed Category';

                    final description =
                        data['description']?.toString() ?? '';

                    return Material(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          Navigator.pop(
                            context,
                            {
                              'id': doc.id,
                              'name': name,
                            },
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.grey.withOpacity(.14),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                height: 46,
                                width: 46,
                                decoration: BoxDecoration(
                                  color:
                                  Colors.green.withOpacity(.09),
                                  borderRadius:
                                  BorderRadius.circular(13),
                                ),
                                child: const Icon(
                                  Icons.handyman_outlined,
                                  color: Colors.green,
                                ),
                              ),
                              const SizedBox(width: 13),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(
                                        fontWeight:
                                        FontWeight.w700,
                                        fontSize: 15,
                                      ),
                                    ),
                                    if (description
                                        .trim()
                                        .isNotEmpty) ...[
                                      const SizedBox(height: 3),
                                      Text(
                                        description,
                                        maxLines: 2,
                                        overflow:
                                        TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// SECURITY SHEET
// =============================================================================

class _SecuritySheet extends StatelessWidget {
  final User? user;
  final Future<void> Function() onSignOutAll;

  const _SecuritySheet({
    required this.user,
    required this.onSignOutAll,
  });

  @override
  Widget build(BuildContext context) {
    final email = user?.email ?? 'Not available';

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        20,
        16,
        20,
        28,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Security & Privacy',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Your sensitive account information is protected.',
              style: TextStyle(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 20),
            _SecurityInfoRow(
              icon: Icons.email_outlined,
              title: 'Account email',
              value: email,
            ),
            _SecurityInfoRow(
              icon: Icons.verified_user_outlined,
              title: 'Email verification',
              value: user?.emailVerified == true
                  ? 'Verified'
                  : 'Not verified',
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(.07),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.security,
                    color: Colors.green[700],
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Sensitive information such as identity records, '
                          'verification documents, provider approval status '
                          'and internal security fields are not editable '
                          'from the user dashboard.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: Colors.grey[800],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  onSignOutAll();
                },
                icon: const Icon(Icons.logout),
                label: const Text('Sign Out'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// SMALL UI COMPONENTS
// =============================================================================

class _AccountBadge extends StatelessWidget {
  final String label;
  final IconData icon;

  const _AccountBadge({
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.16),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _DashboardTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color? color;
  final VoidCallback onTap;

  const _DashboardTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = color ?? Colors.green[700];

    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.grey.withOpacity(.14),
            ),
          ),
          child: Row(
            children: [
              Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                  color: iconColor?.withOpacity(.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[600],
                      ),
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

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? iconColor;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 13,
            ),
            child: Row(
              children: [
                Container(
                  height: 42,
                  width: 42,
                  decoration: BoxDecoration(
                    color: (iconColor ?? Colors.green[700])
                        ?.withOpacity(.09),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: iconColor ?? Colors.green[700],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: Colors.grey,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 13,
            ),
          ),
        ),
        Text(
          value,
          textAlign: TextAlign.right,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

class _SecurityInfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _SecurityInfoRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: Colors.green[700],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}