import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Firestore-backed user activity service.
///
/// All user activity is scoped to the signed-in user's UID.  The service is
/// deliberately independent from provider/business collections so the My
/// Activity screen can evolve without changing provider registration logic.
class ActivityService {
  ActivityService._();

  static final ActivityService instance = ActivityService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get uid => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>>? get _userActivity {
    final userId = uid;
    if (userId == null || userId.isEmpty) return null;
    return _db.collection('users').doc(userId).collection('activity');
  }

  CollectionReference<Map<String, dynamic>>? get _saved =>
      _userActivity == null ? null : _userActivity!.doc('saved').collection('items');

  CollectionReference<Map<String, dynamic>>? get _recentlyViewed =>
      _userActivity == null ? null : _userActivity!.doc('recently_viewed').collection('items');

  CollectionReference<Map<String, dynamic>>? get _enquiries =>
      _userActivity == null ? null : _userActivity!.doc('enquiries').collection('items');

  Stream<QuerySnapshot<Map<String, dynamic>>> savedStream() {
    final ref = _saved;
    if (ref == null) return const Stream.empty();
    return ref.snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> recentlyViewedStream() {
    final ref = _recentlyViewed;
    if (ref == null) return const Stream.empty();
    return ref.snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> enquiriesStream() {
    final ref = _enquiries;
    if (ref == null) return const Stream.empty();
    return ref.snapshots();
  }

  /// Reviews written by the current user. New reviews include reviewerUid.
  /// Older reviews that pre-date My Activity are intentionally not guessed or
  /// matched by name because names are not unique.
  Stream<QuerySnapshot<Map<String, dynamic>>> reviewsStream() {
    final userId = uid;
    if (userId == null || userId.isEmpty) return const Stream.empty();
    return _db
        .collectionGroup('reviews')
        .where('reviewerUid', isEqualTo: userId)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> myMarketplaceItemsStream() {
    final userId = uid;
    if (userId == null || userId.isEmpty) return const Stream.empty();
    return _db
        .collection('marketplace_items')
        .where('sellerId', isEqualTo: userId)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> myRidesStream() {
    final userId = uid;
    if (userId == null || userId.isEmpty) return const Stream.empty();
    return _db
        .collection('ride_along')
        .where('driverUid', isEqualTo: userId)
        .snapshots();
  }

  /// Requests made by the current user across Ride Along trips.
  Stream<QuerySnapshot<Map<String, dynamic>>> myRideRequestsStream() {
    final userId = uid;
    if (userId == null || userId.isEmpty) return const Stream.empty();
    return _db
        .collectionGroup('requests')
        .where('passengerUid', isEqualTo: userId)
        .snapshots();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> providerApplicationStream() {
    final userId = uid;
    if (userId == null || userId.isEmpty) return const Stream.empty();
    return _db.collection('provider_applications').doc(userId).snapshots();
  }

  Future<void> saveItem({
    required String itemId,
    required String type,
    required String title,
    String subtitle = '',
    String imageUrl = '',
    Map<String, dynamic>? metadata,
  }) async {
    final ref = _saved;
    if (ref == null) throw Exception('Please sign in to save items.');

    await ref.doc('${type}_$itemId').set({
      'itemId': itemId,
      'type': type,
      'title': title,
      'subtitle': subtitle,
      'imageUrl': imageUrl,
      'metadata': metadata ?? <String, dynamic>{},
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> removeSavedItem({
    required String itemId,
    required String type,
  }) async {
    final ref = _saved;
    if (ref == null) return;
    await ref.doc('${type}_$itemId').delete();
  }

  Stream<bool> isSavedStream({required String itemId, required String type}) {
    final ref = _saved;
    if (ref == null) return Stream.value(false);
    return ref.doc('${type}_$itemId').snapshots().map((snap) => snap.exists);
  }

  Future<void> recordRecentlyViewed({
    required String itemId,
    required String type,
    required String title,
    String subtitle = '',
    String imageUrl = '',
    Map<String, dynamic>? metadata,
  }) async {
    final ref = _recentlyViewed;
    if (ref == null) return;

    await ref.doc('${type}_$itemId').set({
      'itemId': itemId,
      'type': type,
      'title': title,
      'subtitle': subtitle,
      'imageUrl': imageUrl,
      'metadata': metadata ?? <String, dynamic>{},
      'viewedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> removeRecentlyViewed({
    required String itemId,
    required String type,
  }) async {
    final ref = _recentlyViewed;
    if (ref == null) return;
    await ref.doc('${type}_$itemId').delete();
  }

  Future<void> clearRecentlyViewed() async {
    final ref = _recentlyViewed;
    if (ref == null) return;
    final snap = await ref.get();
    if (snap.docs.isEmpty) return;
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  Future<void> createEnquiry({
    required String subject,
    required String message,
    required String targetId,
    required String targetType,
    String targetName = '',
  }) async {
    final ref = _enquiries;
    final userId = uid;
    if (ref == null || userId == null) {
      throw Exception('Please sign in to send an enquiry.');
    }

    await ref.add({
      'subject': subject.trim(),
      'message': message.trim(),
      'targetId': targetId,
      'targetType': targetType,
      'targetName': targetName.trim(),
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markEnquiryRead(String enquiryId) async {
    final ref = _enquiries;
    if (ref == null) return;
    await ref.doc(enquiryId).set({
      'read': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
