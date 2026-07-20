/// A self-registered or admin-added tiling service provider.
/// Firestore collection: `tilers`, doc id == the provider's uid (for
/// self-registered) or an auto id (for admin-added).
///
/// Mirrors Tailor/Plumber exactly, field-name style included, so
/// ManageProvidersScreen / AdminProviderRecord keep working unchanged
/// across every category.
class Tiler {
  final String id;
  final String name;
  final String phoneNumber;
  final String businessName;
  final String stationArea;
  final int yearsOfExperience;
  final List<String> specialtiesServiced;
  final List<String> materialsWorkedWith;
  final List<String> servicesOffered;
  final bool offersOnSiteConsultation;
  final double rating;
  final int reviewCount;
  final bool isApproved;
  final bool isPending;
  final String? ghanaCardNumber;
  final String? photoUrl;
  final String? ghanaCardPhotoUrl;

  const Tiler({
    required this.id,
    required this.name,
    required this.phoneNumber,
    required this.businessName,
    required this.stationArea,
    required this.yearsOfExperience,
    required this.specialtiesServiced,
    required this.materialsWorkedWith,
    required this.servicesOffered,
    required this.offersOnSiteConsultation,
    this.rating = 0.0,
    this.reviewCount = 0,
    this.isApproved = false,
    this.isPending = true,
    this.ghanaCardNumber,
    this.photoUrl,
    this.ghanaCardPhotoUrl,
  });

  factory Tiler.fromMap(String id, Map<String, dynamic> map) {
    return Tiler(
      id: id,
      name: map['name'] as String? ?? '',
      phoneNumber: map['phoneNumber'] as String? ?? '',
      businessName: map['businessName'] as String? ?? '',
      stationArea: map['stationArea'] as String? ?? '',
      yearsOfExperience: (map['yearsOfExperience'] as num?)?.toInt() ?? 0,
      specialtiesServiced: List<String>.from(map['specialtiesServiced'] as List? ?? const []),
      materialsWorkedWith: List<String>.from(map['materialsWorkedWith'] as List? ?? const []),
      servicesOffered: List<String>.from(map['servicesOffered'] as List? ?? const []),
      offersOnSiteConsultation: map['offersOnSiteConsultation'] as bool? ?? false,
      rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: (map['reviewCount'] as num?)?.toInt() ?? 0,
      isApproved: map['isApproved'] as bool? ?? false,
      isPending: map['isPending'] as bool? ?? true,
      ghanaCardNumber: map['ghanaCardNumber'] as String?,
      photoUrl: map['photoUrl'] as String?,
      ghanaCardPhotoUrl: map['ghanaCardPhotoUrl'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phoneNumber': phoneNumber,
      'businessName': businessName,
      'stationArea': stationArea,
      'yearsOfExperience': yearsOfExperience,
      'specialtiesServiced': specialtiesServiced,
      'materialsWorkedWith': materialsWorkedWith,
      'servicesOffered': servicesOffered,
      'offersOnSiteConsultation': offersOnSiteConsultation,
      'rating': rating,
      'reviewCount': reviewCount,
      'isApproved': isApproved,
      'isPending': isPending,
      if (ghanaCardNumber != null) 'ghanaCardNumber': ghanaCardNumber,
      if (photoUrl != null) 'photoUrl': photoUrl,
      if (ghanaCardPhotoUrl != null) 'ghanaCardPhotoUrl': ghanaCardPhotoUrl,
    };
  }
}
