// lib/models/marketplace_item.dart

class MarketplaceItem {
  final String id;
  final String sellerId; // Firebase UID of the poster — drives "My Listings" and delete permission
  final String title;
  final String description;
  final String price;
  final String locationText; // general area, e.g. "Adenta, Accra"
  final String? areaDetail; // landmark/street, e.g. "White Signboard, Emmanuel Estate, Melcom Junction"
  final String sellerPhone;
  final List<String> photoUrls; // up to 5 image URLs
  final int viewCount;
  final double rating; // 0.0 - 5.0
  final int reviewCount;
  final bool isVerified;
  final bool isApproved; // admin gate — false until an admin approves; only approved items show on the public marketplace
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

  factory MarketplaceItem.fromMap(Map<String, dynamic> map, String id) {
    return MarketplaceItem(
      id: id,
      sellerId: map['sellerId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      price: map['price'] as String? ?? '',
      locationText: map['locationText'] as String? ?? '',
      areaDetail: map['areaDetail'] as String?,
      sellerPhone: map['sellerPhone'] as String? ?? '',
      photoUrls: (map['photoUrls'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      viewCount: (map['viewCount'] as num?)?.toInt() ?? 0,
      rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: (map['reviewCount'] as num?)?.toInt() ?? 0,
      isVerified: map['isVerified'] as bool? ?? false,
      isApproved: map['isApproved'] as bool? ?? false,
      dateAdded: map['createdAt'] is String ? DateTime.tryParse(map['createdAt'] as String) : null,
    );
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
      'photoUrls': photoUrls,
      'viewCount': viewCount,
      'rating': rating,
      'reviewCount': reviewCount,
      'isVerified': isVerified,
      'isApproved': isApproved,
    };
  }
}