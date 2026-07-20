/// Building types a mason typically works on. Mirrors Mechanic's
/// vehicleTypeOptions — "what kind of jobs do they cover".
const List<String> buildingTypeOptions = [
  'Residential',
  'Commercial',
  'Industrial',
  'Renovation',
];

/// Core masonry specialties. Mirrors Mechanic's brandSpecialtyOptions.
const List<String> masonrySpecialtyOptions = [
  'Blockwork',
  'Brickwork',
  'Stonework',
  'Plastering',
  'Concrete & Foundation',
  'Tiling',
  'Rendering',
];

/// Services offered. Mirrors Mechanic's serviceOptions.
const List<String> masonServiceOptions = [
  'New Construction',
  'Renovation & Repairs',
  'Fencing / Wall Construction',
  'Foundation Laying',
  'Plastering',
  'Tiling',
  'Concrete Work',
];

class Mason {
  final String id;
  final String name;
  final String phoneNumber;
  final String businessName;
  final String stationArea;
  final int yearsOfExperience;
  final List<String> buildingTypes;
  final List<String> specialties;
  final List<String> servicesOffered;
  final bool offersEmergencyRepairs;
  final double rating;
  final int reviewCount;
  final bool isApproved;
  final bool isPending;
  final String ghanaCardNumber;
  final String? photoUrl;
  final String? ghanaCardPhotoUrl;

  const Mason({
    required this.id,
    required this.name,
    required this.phoneNumber,
    required this.businessName,
    required this.stationArea,
    required this.yearsOfExperience,
    required this.buildingTypes,
    required this.specialties,
    required this.servicesOffered,
    required this.offersEmergencyRepairs,
    required this.rating,
    required this.reviewCount,
    required this.isApproved,
    required this.isPending,
    required this.ghanaCardNumber,
    this.photoUrl,
    this.ghanaCardPhotoUrl,
  });

  factory Mason.fromMap(String id, Map<String, dynamic> map) {
    return Mason(
      id: id,
      name: map['name'] as String? ?? '',
      phoneNumber: map['phoneNumber'] as String? ?? '',
      businessName: map['businessName'] as String? ?? '',
      stationArea: map['stationArea'] as String? ?? '',
      yearsOfExperience: (map['yearsOfExperience'] as num?)?.toInt() ?? 0,
      buildingTypes: List<String>.from(map['buildingTypes'] as List? ?? const []),
      specialties: List<String>.from(map['specialties'] as List? ?? const []),
      servicesOffered: List<String>.from(map['servicesOffered'] as List? ?? const []),
      offersEmergencyRepairs: map['offersEmergencyRepairs'] as bool? ?? false,
      rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: (map['reviewCount'] as num?)?.toInt() ?? 0,
      isApproved: map['isApproved'] as bool? ?? false,
      isPending: map['isPending'] as bool? ?? true,
      ghanaCardNumber: map['ghanaCardNumber'] as String? ?? '',
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
      'buildingTypes': buildingTypes,
      'specialties': specialties,
      'servicesOffered': servicesOffered,
      'offersEmergencyRepairs': offersEmergencyRepairs,
      'rating': rating,
      'reviewCount': reviewCount,
      'isApproved': isApproved,
      'isPending': isPending,
      'ghanaCardNumber': ghanaCardNumber,
      'photoUrl': photoUrl,
      'ghanaCardPhotoUrl': ghanaCardPhotoUrl,
      // String, not Timestamp — matches the createdAt format AuthService's
      // registerAsX() methods already use elsewhere (e.g. registerAsSteelBender).
      'createdAt': DateTime.now().toIso8601String(),
    };
  }
}
