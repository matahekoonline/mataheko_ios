import 'package:cloud_firestore/cloud_firestore.dart';

enum MediaType { video, music }

// `audio` covers plain MP3/direct audio file links, distinct from `spotify`
// (a streaming link) since they're opened/displayed a bit differently.
enum MediaSource { youtube, spotify, audio }

class MediaItem {
  final String id;
  final String title;
  final String creatorName;
  final MediaType type;
  final MediaSource source;
  final String sourceId; // YouTube video ID, full Spotify URL, or direct mp3/audio URL
  final String thumbnailNote; // short description shown under title

  const MediaItem({
    required this.id,
    required this.title,
    required this.creatorName,
    required this.type,
    required this.source,
    required this.sourceId,
    required this.thumbnailNote,
  });

  /// Builds a [MediaItem] from a Firestore document.
  factory MediaItem.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return MediaItem(
      id: doc.id,
      title: (data['title'] as String?) ?? '',
      creatorName: (data['creatorName'] as String?) ?? '',
      type: _typeFromString(data['type'] as String?),
      source: _sourceFromString(data['source'] as String?),
      sourceId: (data['sourceId'] as String?) ?? '',
      thumbnailNote: (data['thumbnailNote'] as String?) ?? '',
    );
  }

  /// Serializes this item for writing to Firestore. `id` is excluded since
  /// it's the document ID, not a field.
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'creatorName': creatorName,
      'type': type.name,
      'source': source.name,
      'sourceId': sourceId,
      'thumbnailNote': thumbnailNote,
    };
  }

  static MediaType _typeFromString(String? value) {
    return MediaType.values.firstWhere(
      (t) => t.name == value,
      orElse: () => MediaType.video,
    );
  }

  static MediaSource _sourceFromString(String? value) {
    return MediaSource.values.firstWhere(
      (s) => s.name == value,
      orElse: () => MediaSource.youtube,
    );
  }
}
