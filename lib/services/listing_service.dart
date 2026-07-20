import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/listing.dart';

/// Firestore-backed source of truth for listings. Mirrors the
/// HeroBannerService pattern — a singleton with live streams, so any
/// listing added/edited/removed (e.g. from an admin screen) reflects
/// immediately wherever it's used (home screen stats, Latest Additions,
/// category directory screens).
///
/// Expects a top-level `listings` collection where each document maps to
/// a Listing (see Listing.fromFirestore / toMap for the field shape).
class ListingService {
  ListingService._();
  static final ListingService instance = ListingService._();

  final CollectionReference<Map<String, dynamic>> _collection =
      FirebaseFirestore.instance.collection('listings');

  /// All listings, unordered. Good for counts (e.g. the home screen stats
  /// strip) where sort order doesn't matter.
  Stream<List<Listing>> allListingsStream() {
    return _collection.snapshots().map(
          (snapshot) =>
              snapshot.docs.map((doc) => Listing.fromFirestore(doc)).toList(),
        );
  }

  /// The [count] most recently added listings, newest first. Powers the
  /// home screen's "Latest Additions" row.
  Stream<List<Listing>> latestListingsStream({int count = 8}) {
    return _collection
        .orderBy('dateAdded', descending: true)
        .limit(count)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Listing.fromFirestore(doc)).toList());
  }

  /// Listings for a single category, newest first. Powers category screens
  /// like OkadaRidersScreen, CarpentersScreen, etc.
  Stream<List<Listing>> listingsByCategoryStream(String category) {
    return _collection
        .where('category', isEqualTo: category)
        .orderBy('dateAdded', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Listing.fromFirestore(doc)).toList());
  }

  Future<void> addListing(Listing listing) {
    return _collection.doc(listing.id).set(listing.toMap());
  }

  Future<void> updateListing(Listing listing) {
    return _collection.doc(listing.id).update(listing.toMap());
  }

  Future<void> deleteListing(String id) {
    return _collection.doc(id).delete();
  }
}
