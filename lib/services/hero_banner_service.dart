import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/hero_banner.dart';

/// Firestore-backed hero banner management. Collection: `hero_banners`.
///
/// Two read paths:
/// - [activeBannersStream] -- what the public home screen shows (active
///   banners only, in display order). This is what replaces the static
///   `sampleBanners` list.
/// - [allBannersStream] -- what the admin manage screen shows (everything,
///   including inactive banners, so they can be re-enabled later).
class HeroBannerService {
  HeroBannerService._();
  static final HeroBannerService instance = HeroBannerService._();

  final CollectionReference<Map<String, dynamic>> _collection =
      FirebaseFirestore.instance.collection('hero_banners');

  /// Home screen: active banners only, ordered. Filtering `active` here in
  /// Dart (rather than as a second Firestore `where` alongside `orderBy`)
  /// avoids needing a composite index — a `where` + `orderBy` on different
  /// fields requires one, and until it's created/built the live listener
  /// throws failed-precondition, which made banners flash and then vanish.
  /// The `hero_banners` collection is small, so reading everything and
  /// filtering client-side is cheap and needs zero Firestore console setup.
  Stream<List<HeroBanner>> activeBannersStream() {
    return _collection.orderBy('order').snapshots().map((snap) => snap.docs
        .map((d) => HeroBanner.fromMap(d.id, d.data()))
        .where((b) => b.active)
        .toList());
  }

  /// Admin manage screen: every banner, active or not.
  Stream<List<HeroBanner>> allBannersStream() {
    return _collection.orderBy('order').snapshots().map((snap) =>
        snap.docs.map((d) => HeroBanner.fromMap(d.id, d.data())).toList());
  }

  Future<String> addBanner(HeroBanner banner) async {
    final docRef = _collection.doc();
    await docRef.set(banner.toMap());
    return docRef.id;
  }

  /// Reserves a Firestore doc id without writing anything yet. Used by the
  /// add/edit screen so a brand-new banner's photo can be uploaded to
  /// Storage under a path that matches its eventual Firestore id, before
  /// the document itself is created.
  String newBannerId() => _collection.doc().id;

  /// Writes a new banner using an id that was already reserved via
  /// [newBannerId] (rather than letting Firestore generate one via
  /// [addBanner]).
  Future<void> createBannerWithId(HeroBanner banner) async {
    await _collection.doc(banner.id).set(banner.toMap());
  }

  Future<void> updateBanner(HeroBanner banner) async {
    await _collection.doc(banner.id).set(banner.toMap());
  }

  Future<void> deleteBanner(String id) async {
    await _collection.doc(id).delete();
  }

  Future<void> setActive(String id, bool active) async {
    await _collection.doc(id).update({'active': active});
  }

  /// Persists a new relative order for a full reordered list (called after
  /// drag-and-drop reordering in ManageHeroBannersScreen). Batched so every
  /// banner's `order` field updates atomically.
  Future<void> reorder(List<HeroBanner> orderedBanners) async {
    final batch = FirebaseFirestore.instance.batch();
    for (var i = 0; i < orderedBanners.length; i++) {
      batch.update(_collection.doc(orderedBanners[i].id), {'order': i});
    }
    await batch.commit();
  }

  /// One-time convenience for an empty banner list: bulk-writes a starter
  /// set (e.g. your existing `sampleBanners`) into Firestore so the admin
  /// isn't starting from a blank screen.
  Future<void> seedBanners(List<HeroBanner> banners) async {
    final batch = FirebaseFirestore.instance.batch();
    for (var i = 0; i < banners.length; i++) {
      final docRef = _collection.doc();
      batch.set(docRef, banners[i].copyWith(order: i).toMap());
    }
    await batch.commit();
  }
}
