// =======================================================================
// INTEGRATION POINT 1: lib/main.dart
// =======================================================================
//
// In your AppStartupScreen's _initFirebase() (the one with the 10-second
// timeout you already have), add ONE line right after Firebase initializes
// successfully, before navigating to MainScreen:
//
//   await Firebase.initializeApp(
//     options: DefaultFirebaseOptions.currentPlatform,
//   ).timeout(const Duration(seconds: 10));
//
//   await NotificationService.instance.initialize();   // <-- ADD THIS LINE
//
//   if (!mounted) return;
//   Navigator.of(context).pushReplacement(
//     MaterialPageRoute(builder: (_) => const MainScreen()),
//   );
//
// Also add the import at the top of main.dart:
//   import 'services/notification_service.dart';


// =======================================================================
// INTEGRATION POINT 2: wherever your admin dashboard/verify screen
// confirms isAdmin (e.g. lib/screens/admin_dashboard_screen.dart or
// verify_providers_screen.dart's initState, same pattern as the existing
// _loadAdminStatus() in every provider list screen)
// =======================================================================
//
// Right after confirming isAdmin == true, call:
//
//   await NotificationService.instance.registerAdminDeviceToken();
//
// This registers the CURRENT device as the one that gets pushes -- so
// simply have your one admin account open the admin dashboard/screen
// once on their phone, and that device's token gets saved.


// =======================================================================
// INTEGRATION POINT 3: lib/services/auth_service.dart
// =======================================================================
//
// Add the import at the top:
//   import 'notification_service.dart';
//
// Then add ONE line at the end of each self-registration method (the
// ones keyed by uid -- registerAsMechanic, registerAsWelder,
// registerAsCarpenter, registerAsSteelBender, registerAsTailor,
// registerAsPlumber, registerAsTiler, registerAsElectrician,
// registerAsOkadaRider, registerAsHomeCook, registerAsTeacher).
//
// Do NOT add it to the addXByAdmin methods -- those are performed BY the
// admin, so there's no one to notify.
//
// Example for registerAsMechanic (add right before the closing `}`,
// after the Firestore .set() call finishes):
//
//   Future<void> registerAsMechanic({
//     ...
//   }) async {
//     ...
//     await _db.collection('mechanics').doc(uid).set({
//       ...
//     });
//
//     NotificationService.notifyAdmin(                     // <-- ADD THIS
//       title: 'New Mechanic registration',                 // <-- ADD THIS
//       body: '$fullName ($workshopName) is awaiting approval', // <-- ADD
//       category: 'mechanics',                               // <-- ADD THIS
//     );                                                     // <-- ADD THIS
//   }
//
// Repeat the same pattern (swap the title/body wording) for every other
// registerAsX method. Since notifyAdmin() is fire-and-forget (it swallows
// its own errors), you don't need `await` on it if you'd rather not delay
// the method's return -- either works.
//
// For NEW USER SIGNUP specifically, add it inside registerWithEmail(),
// right after setUserRole() succeeds:
//
//   Future<User?> registerWithEmail(
//       String email, String password, UserRole role,
//       {String? displayName}) async {
//     final result = await _auth.createUserWithEmailAndPassword(email: email, password: password);
//     if (displayName != null) await result.user?.updateDisplayName(displayName);
//     if (result.user != null) {
//       await setUserRole(result.user!.uid, role);
//
//       NotificationService.notifyAdmin(                    // <-- ADD THIS
//         title: 'New user signed up',                       // <-- ADD THIS
//         body: '${displayName ?? email} joined as ${role.name}', // <-- ADD
//         category: 'new_user',                               // <-- ADD THIS
//       );                                                    // <-- ADD THIS
//     }
//     return result.user;
//   }
