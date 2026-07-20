// lib/services/marketplace_service.dart
//
// Handles all Firestore reads/writes for the Marketplace feature. Kept
// separate from AuthService since this is a listings/CRUD concern, not a
// provider-registration one — but follows the same singleton pattern
// (MarketplaceService.instance) used throughout the app for consistency.

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/marketplace_item.dart';
import '../services/photo_upload_service.dart';


class MarketplaceService {
  MarketplaceService._();
  static final MarketplaceService instance = MarketplaceService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _items => _db.collection('marketplace_items');

  /// Public listings, newest first — only items an admin has approved.
  /// This is what MarketplaceScreen shows to everyone. NOTE: combining
  /// where(isApproved) with orderBy(createdAt) needs a composite index —
  /// Firestore will throw once with a console link the first time this
  /// runs; click it, wait a minute, retry.
  Stream<List<MarketplaceItem>> streamItems() {
    return _items
        .where('isApproved', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => MarketplaceItem.fromMap(d.data(), d.id)).toList());
  }

  /// Listings pending admin approval, oldest first (so admins clear the
  /// backlog in order). Used by the admin "Verify Marketplace Items" screen.
  Stream<List<MarketplaceItem>> streamPendingItems() {
    return _items
        .where('isApproved', isEqualTo: false)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map((d) => MarketplaceItem.fromMap(d.data(), d.id)).toList());
  }

  /// Listings posted by the currently signed-in user, for a "My Listings"
  /// screen. Shows ALL of the seller's own items regardless of approval
  /// status, so they can see "Pending Review" on their own posts. NOTE:
  /// combining where(sellerId) with orderBy(createdAt) needs a composite
  /// index — Firestore will throw once with a console link the first time
  /// this runs; click it, wait a minute, retry.
  Stream<List<MarketplaceItem>> streamMyItems() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value(const []);
    return _items
        .where('sellerId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => MarketplaceItem.fromMap(d.data(), d.id)).toList());
  }

  /// Uploads up to 5 photos and creates the listing doc. Requires a
  /// signed-in user (call requireLogin() before navigating to the post
  /// screen, same as the rest of the app already does for the FAB).
  /// New listings start as isApproved: false and only appear on the
  /// public marketplace once an admin approves them.
  Future<String> postItem({
    required String title,
    required String description,
    required String price,
    required String locationText,
    String? areaDetail,
    required String sellerPhone,
    required List<File> photos,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('No signed-in user');

    final List<String> photoUrls = [];
    for (final photo in photos.take(5)) {
      // Reuses uploadRiderPhoto since it just POSTs any image file to
      // seghansoccertraining.org and returns a public URL — the same
      // generic upload registerAsMechanic/registerAsSteelBender already
      // rely on. Rename this call if you've since added a dedicated
      // uploadMarketplacePhoto method to PhotoUploadService.
      final url = await PhotoUploadService.uploadRiderPhoto(uid: uid, photo: photo);
      photoUrls.add(url);
    }

    final doc = await _items.add({
      'sellerId': uid,
      'title': title,
      'description': description,
      'price': price,
      'locationText': locationText,
      'areaDetail': areaDetail,
      'sellerPhone': sellerPhone,
      'photoUrls': photoUrls,
      'viewCount': 0,
      'rating': 0.0,
      'reviewCount': 0,
      'isVerified': false,
      'isApproved': false,
      'createdAt': DateTime.now().toIso8601String(),
    });
    return doc.id;
  }

  Future<void> incrementViewCount(String itemId) async {
    await _items.doc(itemId).update({'viewCount': FieldValue.increment(1)});
  }

  /// Admin action — makes a pending item visible on the public marketplace.
  Future<void> approveItem(String itemId) async {
    await _items.doc(itemId).update({'isApproved': true});
  }

  /// Admin action — rejects a pending item by removing it outright.
  /// (No "rejected" status is kept — if you later want to notify the
  /// seller why, add a `rejectionReason` field here instead of deleting.)
  Future<void> rejectItem(String itemId) async {
    await _items.doc(itemId).delete();
  }

  /// Sellers can remove their own listing. Callers should confirm the
  /// current user actually owns the item before showing a delete button.
  Future<void> deleteItem(String itemId) async {
    await _items.doc(itemId).delete();
  }
}