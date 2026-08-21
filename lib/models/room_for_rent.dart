/// Reference lists used for selection chips in the Add Room for Rent form.
/// Kept here so both the registration/admin form and detail screen stay
/// in sync — same pattern as Mechanic's vehicleTypeOptions etc.

const List<String> roomTypeOptions = [
  'Single Room',
  'Chamber & Hall',
  '1 Bedroom',
  '2 Bedroom',
  '3 Bedroom+',
  'Self-Contained',
  'Shared Room',
];

const List<String> roomAmenityOptions = [
  'Water (Running)',
  'Electricity (Prepaid)',
  'Furnished',
  'Kitchen',
  'Private Bathroom',
  'Shared Bathroom',
  'Fenced/Gated',
  'Security',
  'Parking',
  'Wardrobe',
  'Fan',
  'AC',
];

const List<String> roomRentPeriodOptions = [
  'Monthly',
  'Quarterly (3 months)',
  'Bi-Annually (6 months)',
  'Yearly',
];

class RoomForRent {
  final String id;
  final String landlordName;
  final String phoneNumber;
  final String propertyTitle; // e.g. "Nice self-contained near market"
  final String stationArea; // location/area in Mataheko-Afienya
  final String roomType; // from roomTypeOptions
  final double price;
  final String rentPeriod; // from roomRentPeriodOptions
  final List<String> amenities; // from roomAmenityOptions
  final String description;
  final List<String> photoUrls; // multiple property photos
  final bool isApproved;
  final bool isPending;
  final bool isAvailable; // landlord/admin can toggle off once rented
  final String ghanaCardNumber;
  final String? ghanaCardPhotoUrl;
  final DateTime createdAt;

  const RoomForRent({
    required this.id,
    required this.landlordName,
    required this.phoneNumber,
    required this.propertyTitle,
    required this.stationArea,
    required this.roomType,
    required this.price,
    required this.rentPeriod,
    required this.amenities,
    required this.description,
    required this.photoUrls,
    required this.isApproved,
    required this.isPending,
    required this.isAvailable,
    required this.ghanaCardNumber,
    this.ghanaCardPhotoUrl,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'landlordName': landlordName,
      'phoneNumber': phoneNumber,
      'propertyTitle': propertyTitle,
      'stationArea': stationArea,
      'roomType': roomType,
      'price': price,
      'rentPeriod': rentPeriod,
      'amenities': amenities,
      'description': description,
      'photoUrls': photoUrls,
      'isApproved': isApproved,
      'isPending': isPending,
      'isAvailable': isAvailable,
      'ghanaCardNumber': ghanaCardNumber,
      'ghanaCardPhotoUrl': ghanaCardPhotoUrl,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory RoomForRent.fromMap(String id, Map<String, dynamic> map) {
    return RoomForRent(
      id: id,
      landlordName: map['landlordName'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      propertyTitle: map['propertyTitle'] ?? '',
      stationArea: map['stationArea'] ?? '',
      roomType: map['roomType'] ?? '',
      price: (map['price'] ?? 0.0).toDouble(),
      rentPeriod: map['rentPeriod'] ?? '',
      amenities: List<String>.from(map['amenities'] ?? const []),
      description: map['description'] ?? '',
      photoUrls: List<String>.from(map['photoUrls'] ?? const []),
      isApproved: map['isApproved'] == true,
      isPending: map['isPending'] == true,
      isAvailable: map['isAvailable'] ?? true,
      ghanaCardNumber: map['ghanaCardNumber'] ?? '',
      ghanaCardPhotoUrl: map['ghanaCardPhotoUrl'],
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
    );
  }
}
