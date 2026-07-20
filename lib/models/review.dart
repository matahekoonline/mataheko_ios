import 'package:cloud_firestore/cloud_firestore.dart';

/// A single buyer review left on a provider's profile (mechanic,
/// electrician, plumber, etc). Lives in a `reviews` subcollection under
/// that provider's document, e.g. `electricians/{id}/reviews/{reviewId}`.
///
/// The provider's own `rating` / `reviewCount` fields are a running
/// average recalculated each time a review is submitted (see
/// AuthService.submitElectricianReview) -- that keeps list screens fast
/// (no need to read every review just to show a star rating), while the
/// full review list is only fetched on the detail screen.
class Review {
  final String id;
  final String reviewerName;
  final double rating; // 1.0-5.0
  final String comment;
  final DateTime? createdAt;

  const Review({
    required this.id,
    required this.reviewerName,
    required this.rating,
    required this.comment,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'reviewerName': reviewerName,
      'rating': rating,
      'comment': comment,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory Review.fromMap(String id, Map<String, dynamic> map) {
    final ts = map['createdAt'];
    return Review(
      id: id,
      reviewerName: (map['reviewerName'] as String?)?.trim().isNotEmpty == true
          ? map['reviewerName'] as String
          : 'Anonymous',
      rating: (map['rating'] ?? 0.0).toDouble(),
      comment: map['comment'] ?? '',
      createdAt: ts is Timestamp ? ts.toDate() : null,
    );
  }
}
