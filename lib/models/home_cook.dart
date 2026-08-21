/// A single dish on a home cook's menu.
class MenuItem {
  final String name;
  final String price;
  final String? description;
  final bool available;

  const MenuItem({
    required this.name,
    required this.price,
    this.description,
    this.available = true,
  });

  factory MenuItem.fromMap(Map<String, dynamic> map) {
    return MenuItem(
      name: map['name'] as String? ?? '',
      price: map['price'] as String? ?? '',
      description: map['description'] as String?,
      available: map['available'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'price': price,
      if (description != null) 'description': description,
      'available': available,
    };
  }
}

/// A self-registered or admin-added home food delivery provider.
/// Firestore collection: `home_cooks`, doc id == the provider's uid (for
/// self-registered) or an auto id (for admin-added).
///
/// Mirrors Tailor/Tiler exactly, field-name style included, so
/// ManageProvidersScreen / AdminProviderRecord keep working unchanged
/// across every category. The one addition over the other trades is
/// `menu`, since this category shows dishes + prices rather than a plain
/// services-offered list.
///
/// Photos: `photoUrls` mirrors Hotel's multi-photo pattern (list of
/// uploaded file URLs, first entry doubles as the cover photo) rather
/// than a single URL. `photoUrl` is kept as a read-only convenience
/// getter over `photoUrls.first` so existing screens that display a
/// single avatar/thumbnail (e.g. HomeCooksScreen's list tile) don't need
/// to change. fromMap() also falls back to an old single `photoUrl`
/// field so home cooks saved before this change still render correctly.
class HomeCook {
  final String id;
  final String name;
  final String phoneNumber;
  final String businessName;
  final String stationArea;
  final List<String> cuisineTypes;
  final List<String> deliveryAreas;
  final bool offersDelivery;
  final List<MenuItem> menu;
  final double rating;
  final int reviewCount;
  final bool isApproved;
  final bool isPending;
  final String? ghanaCardNumber;
  final List<String> photoUrls;
  final String? ghanaCardPhotoUrl;

  const HomeCook({
    required this.id,
    required this.name,
    required this.phoneNumber,
    required this.businessName,
    required this.stationArea,
    required this.cuisineTypes,
    required this.deliveryAreas,
    required this.offersDelivery,
    required this.menu,
    this.rating = 0.0,
    this.reviewCount = 0,
    this.isApproved = false,
    this.isPending = true,
    this.ghanaCardNumber,
    this.photoUrls = const [],
    this.ghanaCardPhotoUrl,
  });

  /// Convenience accessor for old call sites expecting a single photo
  /// (e.g. a CircleAvatar backgroundImage) -- the first uploaded photo
  /// doubles as the cover photo, same convention as Hotel.
  String? get photoUrl => photoUrls.isNotEmpty ? photoUrls.first : null;

  factory HomeCook.fromMap(String id, Map<String, dynamic> map) {
    final rawPhotoUrls = map['photoUrls'] as List?;
    final legacyPhotoUrl = map['photoUrl'] as String?;

    return HomeCook(
      id: id,
      name: map['name'] as String? ?? '',
      phoneNumber: map['phoneNumber'] as String? ?? '',
      businessName: map['businessName'] as String? ?? '',
      stationArea: map['stationArea'] as String? ?? '',
      cuisineTypes: List<String>.from(map['cuisineTypes'] as List? ?? const []),
      deliveryAreas: List<String>.from(map['deliveryAreas'] as List? ?? const []),
      offersDelivery: map['offersDelivery'] as bool? ?? false,
      menu: (map['menu'] as List? ?? const [])
          .map((e) => MenuItem.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: (map['reviewCount'] as num?)?.toInt() ?? 0,
      isApproved: map['isApproved'] as bool? ?? false,
      isPending: map['isPending'] as bool? ?? true,
      ghanaCardNumber: map['ghanaCardNumber'] as String?,
      // Prefer the new photoUrls list; fall back to wrapping an old
      // single photoUrl so home cooks saved before this change still
      // show their photo.
      photoUrls: rawPhotoUrls != null
          ? List<String>.from(rawPhotoUrls)
          : (legacyPhotoUrl != null && legacyPhotoUrl.isNotEmpty ? [legacyPhotoUrl] : const []),
      ghanaCardPhotoUrl: map['ghanaCardPhotoUrl'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phoneNumber': phoneNumber,
      'businessName': businessName,
      'stationArea': stationArea,
      'cuisineTypes': cuisineTypes,
      'deliveryAreas': deliveryAreas,
      'offersDelivery': offersDelivery,
      'menu': menu.map((m) => m.toMap()).toList(),
      'rating': rating,
      'reviewCount': reviewCount,
      'isApproved': isApproved,
      'isPending': isPending,
      if (ghanaCardNumber != null) 'ghanaCardNumber': ghanaCardNumber,
      'photoUrls': photoUrls,
      if (ghanaCardPhotoUrl != null) 'ghanaCardPhotoUrl': ghanaCardPhotoUrl,
    };
  }
}