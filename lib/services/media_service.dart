import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/media_item.dart';

/// Firestore-backed source of truth for Local Talent media (videos + music).
/// Same pattern as ListingService/HeroBannerService — a singleton with live
/// streams, so anything added/removed from the admin screen shows up on
/// MediaScreen immediately.
///
/// Expects a top-level `media` collection where each document maps to a
/// MediaItem (see MediaItem.fromFirestore / toMap for the field shape).
class MediaService {
  MediaService._();
  static final MediaService instance = MediaService._();

  final CollectionReference<Map<String, dynamic>> _collection =
      FirebaseFirestore.instance.collection('media');

  /// Videos only, for the Videos tab.
  Stream<List<MediaItem>> videosStream() {
    return _collection
        .where('type', isEqualTo: MediaType.video.name)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => MediaItem.fromFirestore(doc)).toList());
  }

  /// Music only, for the Music tab.
  Stream<List<MediaItem>> musicStream() {
    return _collection
        .where('type', isEqualTo: MediaType.music.name)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => MediaItem.fromFirestore(doc)).toList());
  }

  /// Everything, unfiltered — used by the admin "manage" list.
  Stream<List<MediaItem>> allMediaStream() {
    return _collection.snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => MediaItem.fromFirestore(doc))
              .toList(),
        );
  }

  /// Adds a new item. `item.id` is ignored — Firestore generates the
  /// document ID, so pass any placeholder (e.g. '') when constructing it.
  Future<void> addMediaItem(MediaItem item) {
    return _collection.add(item.toMap());
  }

  Future<void> updateMediaItem(MediaItem item) {
    return _collection.doc(item.id).update(item.toMap());
  }

  Future<void> deleteMediaItem(String id) {
    return _collection.doc(id).delete();
  }
}
