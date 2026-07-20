/// Reference lists used for selection chips in the Add Electrician form.
/// Kept here so both the form and detail screen stay in sync.
///
/// Named `electricianPropertyTypeOptions` (not just `propertyTypeOptions`)
/// because Plumber has its own list of the same shape in plumber.dart --
/// using the plain name here caused an ambiguous-import error in any file
/// (like BioDataScreen) that needs both models at once.
const List<String> electricianPropertyTypeOptions = [
  'Residential',
  'Commercial',
  'Industrial',
  'Institutional (School/Hospital/Church)',
];

const List<String> electricalServiceOptions = [
  'Wiring & Rewiring',
  'Electrical Installation',
  'Fault Finding / Troubleshooting',
  'Circuit Breaker & Panel Work',
  'Lighting Installation',
  'Generator & Inverter Setup',
  'Solar Installation',
  'Electrical Safety Inspection',
  'Meter / Prepaid Installation',
];

class Electrician {
  final String id;
  final String name;
  final String phoneNumber;
  final String businessName;
  final String stationArea; // location/area
  final int yearsOfExperience;
  final List<String> propertyTypesServiced; // from electricianPropertyTypeOptions
  final List<String> servicesOffered; // from electricalServiceOptions
  final bool offersEmergencyService;
  final double rating; // average, 0.0-5.0, recalculated on each review
  final int reviewCount;
  final bool isApproved;
  final bool isPending;
  final String ghanaCardNumber;
  final String? photoUrl;
  final String? ghanaCardPhotoUrl;

  const Electrician({
    required this.id,
    required this.name,
    required this.phoneNumber,
    required this.businessName,
    required this.stationArea,
    required this.yearsOfExperience,
    required this.propertyTypesServiced,
    required this.servicesOffered,
    required this.offersEmergencyService,
    required this.rating,
    required this.reviewCount,
    required this.isApproved,
    required this.isPending,
    required this.ghanaCardNumber,
    this.photoUrl,
    this.ghanaCardPhotoUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phoneNumber': phoneNumber,
      'businessName': businessName,
      'stationArea': stationArea,
      'yearsOfExperience': yearsOfExperience,
      'propertyTypesServiced': propertyTypesServiced,
      'servicesOffered': servicesOffered,
      'offersEmergencyService': offersEmergencyService,
      'rating': rating,
      'reviewCount': reviewCount,
      'isApproved': isApproved,
      'isPending': isPending,
      'ghanaCardNumber': ghanaCardNumber,
      'photoUrl': photoUrl,
      'ghanaCardPhotoUrl': ghanaCardPhotoUrl,
      'createdAt': DateTime.now().toIso8601String(),
    };
  }

  factory Electrician.fromMap(String id, Map<String, dynamic> map) {
    return Electrician(
      id: id,
      name: map['name'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      businessName: map['businessName'] ?? '',
      stationArea: map['stationArea'] ?? '',
      yearsOfExperience: (map['yearsOfExperience'] ?? 0) as int,
      propertyTypesServiced: List<String>.from(map['propertyTypesServiced'] ?? const []),
      servicesOffered: List<String>.from(map['servicesOffered'] ?? const []),
      offersEmergencyService: map['offersEmergencyService'] == true,
      rating: (map['rating'] ?? 0.0).toDouble(),
      reviewCount: (map['reviewCount'] ?? 0) as int,
      isApproved: map['isApproved'] == true,
      isPending: map['isPending'] == true,
      ghanaCardNumber: map['ghanaCardNumber'] ?? '',
      photoUrl: map['photoUrl'],
      ghanaCardPhotoUrl: map['ghanaCardPhotoUrl'],
    );
  }
}