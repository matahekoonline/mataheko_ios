// lib/models/tailor.dart
//
// Mirrors the Mechanic/Plumber model's shape (same fields renamed for the
// tailoring trade) so Tailor can reuse the exact same list/detail screen
// patterns, RatingDisplay widget, and admin approval flow already proven
// out for Mechanics, Plumbers, and Okada Riders.

// Option lists for the Add/Edit Tailor forms — mirrors the shape of
// vehicleTypeOptions/propertyTypeOptions etc. in mechanic.dart/plumber.dart.
const List<String> garmentCategoryOptions = [
  'Men\'s wear',
  'Women\'s wear',
  'Children\'s wear',
  'Traditional/Kente wear',
  'Bridal/Wedding wear',
  'School uniforms',
  'Corporate wear',
];

const List<String> fabricSpecialtyOptions = [
  'Kente',
  'Ankara',
  'Lace',
  'Cotton',
  'Batik',
  'Denim',
  'Other',
];

const List<String> tailoringServiceOptions = [
  'Custom tailoring',
  'Alterations & repairs',
  'Wedding/bridal wear',
  'Kente/traditional wear',
  'School uniforms',
  'Corporate wear',
  'Pattern making',
  'Embroidery/beading',
];

class Tailor {
  final String id;
  final String name;
  final String businessName;
  final String phoneNumber;
  final String? photoUrl;
  final double rating;
  final int reviewCount;
  final String stationArea;
  final int yearsOfExperience;

  /// Whether this tailor takes rush/express orders — the tailoring
  /// equivalent of Mechanic.offersRoadsideService / Plumber.offersEmergencyService.
  final bool offersRushService;

  /// Garment categories serviced, e.g. "Men's wear", "Bridal/Wedding wear".
  /// Plays the same role vehicleTypes/propertyTypesServiced play elsewhere.
  final List<String> garmentTypesServiced;

  /// Fabrics/materials they're experienced working with, e.g. "Kente",
  /// "Lace". Mirrors Mechanic.brandSpecialties / Plumber.fixtureBrands.
  final List<String> fabricSpecialties;

  /// e.g. "Custom tailoring", "Alterations & repairs", "Wedding/bridal wear",
  /// "Kente/traditional wear", "School uniforms", "Pattern making".
  final List<String> servicesOffered;

  final bool isApproved;
  final bool isPending;
  final String? ghanaCardNumber;
  final String? ghanaCardPhotoUrl;

  const Tailor({
    required this.id,
    required this.name,
    required this.businessName,
    required this.phoneNumber,
    this.photoUrl,
    required this.rating,
    required this.reviewCount,
    required this.stationArea,
    required this.yearsOfExperience,
    required this.offersRushService,
    required this.garmentTypesServiced,
    required this.fabricSpecialties,
    required this.servicesOffered,
    required this.isApproved,
    required this.isPending,
    this.ghanaCardNumber,
    this.ghanaCardPhotoUrl,
  });

  factory Tailor.fromMap(String id, Map<String, dynamic> map) {
    List<String> _stringList(dynamic v) =>
        (v as List<dynamic>? ?? const []).map((e) => e.toString()).toList();

    return Tailor(
      id: id,
      name: (map['name'] ?? '') as String,
      businessName: (map['businessName'] ?? '') as String,
      phoneNumber: (map['phoneNumber'] ?? '') as String,
      photoUrl: map['photoUrl'] as String?,
      rating: ((map['rating'] ?? 0.0) as num).toDouble(),
      reviewCount: ((map['reviewCount'] ?? 0) as num).toInt(),
      stationArea: (map['stationArea'] ?? '') as String,
      yearsOfExperience: ((map['yearsOfExperience'] ?? 0) as num).toInt(),
      offersRushService: map['offersRushService'] == true,
      garmentTypesServiced: _stringList(map['garmentTypesServiced']),
      fabricSpecialties: _stringList(map['fabricSpecialties']),
      servicesOffered: _stringList(map['servicesOffered']),
      isApproved: map['isApproved'] == true,
      isPending: map['isPending'] == true,
      ghanaCardNumber: map['ghanaCardNumber'] as String?,
      ghanaCardPhotoUrl: map['ghanaCardPhotoUrl'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'businessName': businessName,
      'phoneNumber': phoneNumber,
      'photoUrl': photoUrl,
      'rating': rating,
      'reviewCount': reviewCount,
      'stationArea': stationArea,
      'yearsOfExperience': yearsOfExperience,
      'offersRushService': offersRushService,
      'garmentTypesServiced': garmentTypesServiced,
      'fabricSpecialties': fabricSpecialties,
      'servicesOffered': servicesOffered,
      'isApproved': isApproved,
      'isPending': isPending,
      'ghanaCardNumber': ghanaCardNumber,
      'ghanaCardPhotoUrl': ghanaCardPhotoUrl,
    };
  }
}
