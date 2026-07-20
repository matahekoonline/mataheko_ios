// lib/models/plumber.dart
//
// Mirrors the Mechanic model's shape (same fields renamed for the plumbing
// trade) so Plumber can reuse the exact same list/detail screen patterns,
// RatingDisplay widget, and admin approval flow already proven out for
// Mechanics and Okada Riders.

// Option lists for the Add/Edit Plumber forms — mirrors the shape of
// vehicleTypeOptions / brandSpecialtyOptions / serviceOptions in mechanic.dart.
const List<String> propertyTypeOptions = [
  'Residential',
  'Commercial',
  'Industrial',
];

const List<String> fixtureBrandOptions = [
  'American Standard',
  'Kohler',
  'Roca',
  'Twyford',
  'Grohe',
  'Other',
];

const List<String> plumbingServiceOptions = [
  'Pipe repair',
  'Drain cleaning',
  'Water heater installation',
  'Leak detection',
  'Bathroom/kitchen fitting',
  'Water pump installation',
  'Sewer line repair',
  'Borehole plumbing',
];

class Plumber {
  final String id;
  final String name;
  final String businessName;
  final String phoneNumber;
  final String? photoUrl;
  final double rating;
  final int reviewCount;
  final String stationArea;
  final int yearsOfExperience;

  /// Whether this plumber takes emergency/after-hours call-outs — the
  /// plumbing equivalent of Mechanic.offersRoadsideService.
  final bool offersEmergencyService;

  /// Property types serviced, e.g. "Residential", "Commercial", "Industrial".
  /// Plays the same role vehicleTypes plays for Mechanic.
  final List<String> propertyTypesServiced;

  /// Fixture/equipment brands they're experienced installing or repairing,
  /// e.g. "American Standard", "Kohler". Mirrors Mechanic.brandSpecialties.
  final List<String> fixtureBrands;

  /// e.g. "Pipe repair", "Drain cleaning", "Water heater installation",
  /// "Leak detection", "Bathroom/kitchen fitting".
  final List<String> servicesOffered;

  final bool isApproved;
  final bool isPending;
  final String? ghanaCardNumber;
  final String? ghanaCardPhotoUrl;

  const Plumber({
    required this.id,
    required this.name,
    required this.businessName,
    required this.phoneNumber,
    this.photoUrl,
    required this.rating,
    required this.reviewCount,
    required this.stationArea,
    required this.yearsOfExperience,
    required this.offersEmergencyService,
    required this.propertyTypesServiced,
    required this.fixtureBrands,
    required this.servicesOffered,
    required this.isApproved,
    required this.isPending,
    this.ghanaCardNumber,
    this.ghanaCardPhotoUrl,
  });

  factory Plumber.fromMap(String id, Map<String, dynamic> map) {
    List<String> _stringList(dynamic v) =>
        (v as List<dynamic>? ?? const []).map((e) => e.toString()).toList();

    return Plumber(
      id: id,
      name: (map['name'] ?? '') as String,
      businessName: (map['businessName'] ?? '') as String,
      phoneNumber: (map['phoneNumber'] ?? '') as String,
      photoUrl: map['photoUrl'] as String?,
      rating: ((map['rating'] ?? 0.0) as num).toDouble(),
      reviewCount: ((map['reviewCount'] ?? 0) as num).toInt(),
      stationArea: (map['stationArea'] ?? '') as String,
      yearsOfExperience: ((map['yearsOfExperience'] ?? 0) as num).toInt(),
      offersEmergencyService: map['offersEmergencyService'] == true,
      propertyTypesServiced: _stringList(map['propertyTypesServiced']),
      fixtureBrands: _stringList(map['fixtureBrands']),
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
      'offersEmergencyService': offersEmergencyService,
      'propertyTypesServiced': propertyTypesServiced,
      'fixtureBrands': fixtureBrands,
      'servicesOffered': servicesOffered,
      'isApproved': isApproved,
      'isPending': isPending,
      'ghanaCardNumber': ghanaCardNumber,
      'ghanaCardPhotoUrl': ghanaCardPhotoUrl,
    };
  }
}
