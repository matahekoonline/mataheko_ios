import 'package:cloud_firestore/cloud_firestore.dart';

/// Option lists for AddMotorMechanicScreen's chip sections.
/// Kept separate from mechanic.dart's lists so the two categories can
/// diverge (e.g. Motor Mechanic skews toward full vehicles/engines vs.
/// whatever your existing Mechanic category covers).
const List<String> motorVehicleTypeOptions = [
  'Saloon Car',
  'SUV',
  '4x4 / Pickup',
  'Minivan',
  'Bus / Coaster',
  'Truck',
  'Tractor / Heavy Equipment',
];

const List<String> motorBrandSpecialtyOptions = [
  'Toyota',
  'Honda',
  'Nissan',
  'Hyundai',
  'Kia',
  'Ford',
  'Mercedes-Benz',
  'BMW',
  'Volkswagen',
];

const List<String> motorServiceOptions = [
  'Engine Overhaul',
  'Electrical / Diagnostics',
  'Suspension & Steering',
  'Brake Service',
  'AC Repair',
  'Transmission / Gearbox',
  'Tyre & Wheel Service',
  'Oil Change & Servicing',
  'Bodywork / Panel Beating',
  'Towing',
];

class MotorMechanic {
  final String id;
  final String name;
  final String phoneNumber;
  final String workshopName;
  final String stationArea;
  final int yearsOfExperience;
  final List<String> vehicleTypes;
  final List<String> brandSpecialties;
  final List<String> servicesOffered;
  final bool offersRoadsideService;
  final double rating;
  final int reviewCount;
  final bool isApproved;
  final bool isPending;
  final String ghanaCardNumber;
  final String? photoUrl;
  final String? ghanaCardPhotoUrl;
  final DateTime? createdAt;

  const MotorMechanic({
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
    this.createdAt,
  });

  factory MotorMechanic.fromMap(String id, Map<String, dynamic> map) {
    return MotorMechanic(
      id: id,
      name: (map['name'] ?? '') as String,
      phoneNumber: (map['phoneNumber'] ?? '') as String,
      workshopName: (map['workshopName'] ?? '') as String,
      stationArea: (map['stationArea'] ?? '') as String,
      yearsOfExperience: (map['yearsOfExperience'] ?? 0) as int,
      vehicleTypes: List<String>.from(map['vehicleTypes'] ?? const []),
      brandSpecialties: List<String>.from(map['brandSpecialties'] ?? const []),
      servicesOffered: List<String>.from(map['servicesOffered'] ?? const []),
      offersRoadsideService: (map['offersRoadsideService'] ?? false) as bool,
      rating: ((map['rating'] ?? 0) as num).toDouble(),
      reviewCount: (map['reviewCount'] ?? 0) as int,
      isApproved: (map['isApproved'] ?? false) as bool,
      isPending: (map['isPending'] ?? true) as bool,
      ghanaCardNumber: (map['ghanaCardNumber'] ?? '') as String,
      photoUrl: map['photoUrl'] as String?,
      ghanaCardPhotoUrl: map['ghanaCardPhotoUrl'] as String?,
      createdAt: (map['createdAt'] is Timestamp)
          ? (map['createdAt'] as Timestamp).toDate()
          : null,
    );
  }

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
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
