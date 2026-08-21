import 'package:cloud_firestore/cloud_firestore.dart';

import 'auth_service.dart';

class CommunityAlertService {
  CommunityAlertService._();
  static final instance = CommunityAlertService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _ref =>
      _db.collection('community_alerts');

  Stream<QuerySnapshot<Map<String, dynamic>>> streamActiveAlerts() {
    // Keep the query to a single-field order so the app does not depend on a
    // composite Firestore index. Active/expired filtering is done in the UI.
    return _ref.orderBy('publishedAt', descending: true).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamAllAlerts() {
    return _ref.orderBy('publishedAt', descending: true).snapshots();
  }

  Future<void> _ensureAdmin() async {
    if (!await AuthService.instance.isAdmin()) {
      throw Exception('Administrator access required.');
    }
  }

  Future<String> createAlert({
    required String title,
    required String description,
    required String type,
    required String location,
    required String source,
    DateTime? expiresAt,
  }) async {
    await _ensureAdmin();
    final ref = _ref.doc();
    await ref.set({
      'title': title.trim(),
      'description': description.trim(),
      'type': type.trim(),
      'location': location.trim(),
      'source': source.trim(),
      'active': true,
      'publishedAt': FieldValue.serverTimestamp(),
      'expiresAt': expiresAt == null ? null : Timestamp.fromDate(expiresAt),
      'createdBy': AuthService.instance.currentUser?.uid,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> updateAlert({
    required String id,
    required String title,
    required String description,
    required String type,
    required String location,
    required String source,
    required bool active,
    DateTime? expiresAt,
  }) async {
    await _ensureAdmin();
    await _ref.doc(id).update({
      'title': title.trim(),
      'description': description.trim(),
      'type': type.trim(),
      'location': location.trim(),
      'source': source.trim(),
      'active': active,
      'expiresAt': expiresAt == null ? null : Timestamp.fromDate(expiresAt),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setActive(String id, bool active) async {
    await _ensureAdmin();
    await _ref.doc(id).update({
      'active': active,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteAlert(String id) async {
    await _ensureAdmin();
    await _ref.doc(id).delete();
  }
}
