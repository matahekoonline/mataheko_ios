/// Carpenter provider model. Field names match exactly what
/// registerAsCarpenter / addCarpenterByAdmin write to Firestore, so
/// Carpenter.fromMap() can read straight off a `carpenters/{id}` doc.
///
/// Option lists live as static members on the class (Carpenter.specialtyOptions,
/// Carpenter.materialOptions, Carpenter.serviceOptions) rather than top-level
/// consts, since that's the convention bio_data_screen.dart already expects.
class Carpenter {
  final String id;
  final String fullName;
  final String phoneNumber;
  final String workshopName;
  final String stationArea;
  final int yearsOfExperience;
  final List<String> specialties;
  final List<String> materialsWorkedWith;
  final List<String> servicesOffered;
  final bool offersOnSiteService;
  final double rating;
  final int reviewCount;
  final bool isApproved;
  final bool isPending;
  final String? ghanaCardNumber;
  final String? ghanaCardPhotoUrl;
  final String? photoUrl;

  Carpenter({
    required this.id,
    required this.fullName,
    required this.phoneNumber,
    required this.workshopName,
    required this.stationArea,
    required this.yearsOfExperience,
    required this.specialties,
    required this.materialsWorkedWith,
    required this.servicesOffered,
    required this.offersOnSiteService,
    this.rating = 0.0,
    this.reviewCount = 0,
    this.isApproved = false,
    this.isPending = true,
    this.ghanaCardNumber,
    this.ghanaCardPhotoUrl,
    this.photoUrl,
  });

  static const List<String> specialtyOptions = [
    'Furniture Making',
    'Cabinetry & Fittings',
    'Doors & Windows',
    'Roofing & Framing',
    'Formwork / Concrete Shuttering',
    'Furniture Repair',
    'Custom Woodwork',
  ];

  static const List<String> materialOptions = [
    'Softwood',
    'Hardwood',
    'Plywood',
    'MDF / Chipboard',
    'Bamboo',
    'Reclaimed Wood',
  ];

  static const List<String> serviceOptions = [
    'New Furniture',
    'Furniture Repair',
    'Door/Window Installation',
    'Roofing Carpentry',
    'Cabinetry Installation',
    'On-site Custom Builds',
    'Wood Finishing / Polishing',
  ];

  factory Carpenter.fromMap(String id, Map<String, dynamic> map) {
    return Carpenter(
      id: id,
      fullName: map['fullName'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      workshopName: map['workshopName'] ?? '',
      stationArea: map['stationArea'] ?? '',
      yearsOfExperience: map['yearsOfExperience'] ?? 0,
      specialties: List<String>.from(map['specialties'] ?? []),
      materialsWorkedWith: List<String>.from(map['materialsWorkedWith'] ?? []),
      servicesOffered: List<String>.from(map['servicesOffered'] ?? []),
      offersOnSiteService: map['offersOnSiteService'] ?? false,
      rating: (map['rating'] ?? 0.0).toDouble(),
      reviewCount: map['reviewCount'] ?? 0,
      isApproved: map['isApproved'] ?? false,
      isPending: map['isPending'] ?? true,
      ghanaCardNumber: map['ghanaCardNumber'],
      ghanaCardPhotoUrl: map['ghanaCardPhotoUrl'],
      photoUrl: map['photoUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fullName': fullName,
      'phoneNumber': phoneNumber,
      'workshopName': workshopName,
      'stationArea': stationArea,
      'yearsOfExperience': yearsOfExperience,
      'specialties': specialties,
      'materialsWorkedWith': materialsWorkedWith,
      'servicesOffered': servicesOffered,
      'offersOnSiteService': offersOnSiteService,
      'rating': rating,
      'reviewCount': reviewCount,
      'isApproved': isApproved,
      'isPending': isPending,
      'ghanaCardNumber': ghanaCardNumber,
      'ghanaCardPhotoUrl': ghanaCardPhotoUrl,
      'photoUrl': photoUrl,
    };
  }
}
