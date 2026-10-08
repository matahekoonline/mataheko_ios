import 'package:cloud_firestore/cloud_firestore.dart';

/// Stores user safety / policy acknowledgements.
///
/// This service is intentionally small and only contains the functionality
/// currently used by the registration flow.
class ModerationService {
  ModerationService._();
  static final ModerationService instance = ModerationService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Records the version of the Terms of Use accepted by a signed-in user.
  ///
  /// The information is stored on the user's existing Firestore document so
  /// it stays together with the account/profile data already used by the app.
  Future<void> recordTermsAcceptance(String uid, String termsVersion) async {
    final trimmedUid = uid.trim();
    final trimmedVersion = termsVersion.trim();

    if (trimmedUid.isEmpty) {
      throw ArgumentError('uid cannot be empty');
    }
    if (trimmedVersion.isEmpty) {
      throw ArgumentError('termsVersion cannot be empty');
    }

    await _db.collection('users').doc(trimmedUid).set({
      'termsAccepted': true,
      'termsVersion': trimmedVersion,
      'termsAcceptedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
