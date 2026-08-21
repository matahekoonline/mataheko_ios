// lib/models/marketplace_item.dart

class MarketplaceItem {
  final String id;
  final String sellerId;
  final String title;
  final String description;
  final String price;
  final String locationText;
  final String? areaDetail;
  final String sellerPhone;

  /// Marketplace supports a maximum of 4 photos.
  final List<String> photoUrls;

  final int viewCount;
  final double rating;
  final int reviewCount;
  final bool isVerified;
  final bool isApproved;
  final DateTime? dateAdded;

  const MarketplaceItem({
    required this.id,
    required this.sellerId,
    required this.title,
    required this.description,
    required this.price,
    required this.locationText,
    this.areaDetail,
    required this.sellerPhone,
    this.photoUrls = const [],
    this.viewCount = 0,
    this.rating = 0.0,
    this.reviewCount = 0,
    this.isVerified = false,
    this.isApproved = false,
    this.dateAdded,
  });

  factory MarketplaceItem.fromMap(
    Map<String, dynamic> map,
    String id,
  ) {
    final rawPhotos = map['photoUrls'];

    final parsedPhotos = rawPhotos is List
        ? rawPhotos
            .whereType<String>()
            .map((url) => url.trim())
            .where((url) => url.isNotEmpty)
            .take(4)
            .toList()
        : <String>[];

    return MarketplaceItem(
      id: id,
      sellerId:
          map['sellerId']?.toString() ?? '',
      title:
          map['title']?.toString() ?? '',
      description:
          map['description']?.toString() ?? '',
      price:
          map['price']?.toString() ?? '',
      locationText:
          map['locationText']?.toString() ?? '',
      areaDetail:
          map['areaDetail']?.toString(),
      sellerPhone:
          map['sellerPhone']?.toString() ?? '',
      photoUrls: parsedPhotos,
      viewCount:
          (map['viewCount'] as num?)?.toInt() ??
              0,
      rating:
          (map['rating'] as num?)?.toDouble() ??
              0.0,
      reviewCount:
          (map['reviewCount'] as num?)?.toInt() ??
              0,
      isVerified:
          map['isVerified'] as bool? ??
              false,
      isApproved:
          map['isApproved'] as bool? ??
              false,
      dateAdded:
          _parseDate(map['createdAt']),
    );
  }

  static DateTime? _parseDate(
    dynamic value,
  ) {
    // Current/future records use Firestore Timestamp.
    if (value is DateTime) {
      return value;
    }

    // Existing records in your database may still contain ISO strings.
    if (value is String) {
      return DateTime.tryParse(value);
    }

    // Avoid importing cloud_firestore into the model just for parsing.
    //
    // If createdAt is a Firestore Timestamp, the service can still display
    // the item normally; dateAdded remains null unless Timestamp is converted
    // before reaching this model.
    //
    // The marketplace service now writes Timestamp consistently.
    try {
      final dynamic timestamp = value;

      if (timestamp != null &&
          timestamp.toDate is Function) {
        return timestamp.toDate() as DateTime;
      }
    } catch (_) {
      // Ignore malformed/unsupported dates.
    }

    return null;
  }

  Map<String, dynamic> toMap() {
    return {
      'sellerId': sellerId,
      'title': title,
      'description': description,
      'price': price,
      'locationText': locationText,
      'areaDetail': areaDetail,
      'sellerPhone': sellerPhone,

      // Never expose more than 4 URLs from this model.
      'photoUrls':
          photoUrls.take(4).toList(),

      'viewCount': viewCount,
      'rating': rating,
      'reviewCount': reviewCount,
      'isVerified': isVerified,
      'isApproved': isApproved,
    };
  }
}
