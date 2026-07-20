/// Reference lists used for selection chips in the Add Mechanic form.
/// Kept here so both the form and detail screen stay in sync.
const List<String> vehicleTypeOptions = [
  'Saloon / Sedan',
  'SUV / 4x4',
  'Pickup',
  'Minivan / Trotro',
  'Bus',
  'Heavy Duty / Truck',
  'Motorbike',
];

const List<String> brandSpecialtyOptions = [
  'Toyota',
  'Nissan',
  'Hyundai',
  'Kia',
  'Mercedes-Benz',
  'Volkswagen',
  'Honda',
  'Ford',
  'Mitsubishi',
  'Mazda',
];

const List<String> serviceOptions = [
  'Engine Repair',
  'Electrical',
  'Pump servicing',
  'Suspension & Steering',
  'AC / Cooling System',
  'Diagnostics / Scanning',
  'Body Work / Panel Beating',
  'Spraying / Painting',
  'Brakes',
  'Gearbox / Transmission',
];

class Mechanic {
  final String id;
  final String name;
  final String phoneNumber;
  final String workshopName;
  final String stationArea; // location/area in Mataheko-Afienya
  final int yearsOfExperience;
  final List<String> vehicleTypes; // from vehicleTypeOptions
  final List<String> brandSpecialties; // from brandSpecialtyOptions, may be empty (general mechanic)
  final List<String> servicesOffered; // from serviceOptions
  final bool offersRoadsideService;
  final double rating; // average, 0.0–5.0
  final int reviewCount;
  final bool isApproved;
  final bool isPending;
  final String ghanaCardNumber;
  final String? photoUrl;
  final String? ghanaCardPhotoUrl;

  const Mechanic({
    required this.id,
    required this.name,
    required this.phoneNumber,
    required this.workshopName,
    required this.stationArea,
    required this.yearsOfExperience,
    required this.vehicleTypes,
    required this.brandSpecialties,
    required this.servicesOffered,
    required this.offersRoadsideService,
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
      'workshopName': workshopName,
      'stationArea': stationArea,
      'yearsOfExperience': yearsOfExperience,
      'vehicleTypes': vehicleTypes,
      'brandSpecialties': brandSpecialties,
      'servicesOffered': servicesOffered,
      'offersRoadsideService': offersRoadsideService,
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

  factory Mechanic.fromMap(String id, Map<String, dynamic> map) {
    return Mechanic(
      id: id,
      name: map['name'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      workshopName: map['workshopName'] ?? '',
      stationArea: map['stationArea'] ?? '',
      yearsOfExperience: (map['yearsOfExperience'] ?? 0) as int,
      vehicleTypes: List<String>.from(map['vehicleTypes'] ?? const []),
      brandSpecialties: List<String>.from(map['brandSpecialties'] ?? const []),
      servicesOffered: List<String>.from(map['servicesOffered'] ?? const []),
      offersRoadsideService: map['offersRoadsideService'] == true,
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
