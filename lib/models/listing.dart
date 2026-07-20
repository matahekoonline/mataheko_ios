import 'package:cloud_firestore/cloud_firestore.dart';

class Listing {
  final String id;
  final String name;
  final String category; // e.g. Electrician, Plumber, Food, Tailor
  final String description;
  final String phone;
  final String locationText;
  final String? photoUrl; // null for now, we'll wire up real images later
  final DateTime dateAdded;
  final bool isFeatured;

  const Listing({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.phone,
    required this.locationText,
    required this.dateAdded,
    this.photoUrl,
    this.isFeatured = false,
  });

  /// Builds a [Listing] from a Firestore document. Expects `dateAdded` to be
  /// stored as a Firestore Timestamp. Falls back to now if it's missing so a
  /// malformed doc doesn't crash the Latest Additions / Stats stream.
  factory Listing.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final rawDate = data['dateAdded'];
    final dateAdded = rawDate is Timestamp ? rawDate.toDate() : DateTime.now();

    return Listing(
      id: doc.id,
      name: (data['name'] as String?) ?? '',
      category: (data['category'] as String?) ?? '',
      description: (data['description'] as String?) ?? '',
      phone: (data['phone'] as String?) ?? '',
      locationText: (data['locationText'] as String?) ?? '',
      photoUrl: data['photoUrl'] as String?,
      dateAdded: dateAdded,
      isFeatured: (data['isFeatured'] as bool?) ?? false,
    );
  }

  /// Serializes this listing for writing to Firestore. `id` is excluded
  /// since it's the document ID, not a field.
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'category': category,
      'description': description,
      'phone': phone,
      'locationText': locationText,
      'photoUrl': photoUrl,
      'dateAdded': Timestamp.fromDate(dateAdded),
      'isFeatured': isFeatured,
    };
  }
}
