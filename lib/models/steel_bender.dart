// lib/models/steel_bender.dart
//
// Mirrors the structure of models/mechanic.dart. Steel Benders are a
// construction-trade provider category: rebar bending, welding, gates &
// grills, staircases, roofing trusses, structural fabrication. Unlike
// Mechanics/Okada riders they often work at the customer's construction
// site rather than a fixed shop, so `offersOnSiteService` is a first-class
// field surfaced prominently in both the listing card and detail screen.

class SteelBender {
  final String uid;
  final String fullName;
  final String phoneNumber;
  final String workshopName; // "Workshop / Site Name"
  final String stationArea;
  final int yearsOfExperience;
  final List<String> specialties;
  final List<String> rebarSizesHandled;
  final bool offersOnSiteService;
  final String? ghanaCardNumber;
  final String? ghanaCardPhotoUrl;
  final String? photoUrl;
  final double rating;
  final int reviewCount;
  final bool isPending;
  final bool isApproved;
  final DateTime? dateRegistered;

  const SteelBender({
    required this.uid,
    required this.fullName,
    required this.phoneNumber,
    required this.workshopName,
    required this.stationArea,
    required this.yearsOfExperience,
    required this.specialties,
    required this.rebarSizesHandled,
    required this.offersOnSiteService,
    this.ghanaCardNumber,
    this.ghanaCardPhotoUrl,
    this.photoUrl,
    this.rating = 0.0,
    this.reviewCount = 0,
    this.isPending = true,
    this.isApproved = false,
    this.dateRegistered,
  });

  factory SteelBender.fromMap(String uid, Map<String, dynamic> map) {
    return SteelBender(
      uid: uid,
      fullName: map['fullName'] as String? ?? '',
      phoneNumber: map['phoneNumber'] as String? ?? '',
      workshopName: map['workshopName'] as String? ?? '',
      stationArea: map['stationArea'] as String? ?? '',
      yearsOfExperience: (map['yearsOfExperience'] as num?)?.toInt() ?? 0,
      specialties: List<String>.from(map['specialties'] as List? ?? const []),
      rebarSizesHandled: List<String>.from(map['rebarSizesHandled'] as List? ?? const []),
      offersOnSiteService: map['offersOnSiteService'] as bool? ?? false,
      ghanaCardNumber: map['ghanaCardNumber'] as String?,
      ghanaCardPhotoUrl: map['ghanaCardPhotoUrl'] as String?,
      photoUrl: map['photoUrl'] as String?,
      rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: (map['reviewCount'] as num?)?.toInt() ?? 0,
      isPending: map['isPending'] as bool? ?? true,
      isApproved: map['isApproved'] as bool? ?? false,
      dateRegistered: map['createdAt'] is String
          ? DateTime.tryParse(map['createdAt'] as String)
          : null,
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
      'rebarSizesHandled': rebarSizesHandled,
      'offersOnSiteService': offersOnSiteService,
      'ghanaCardNumber': ghanaCardNumber,
      'ghanaCardPhotoUrl': ghanaCardPhotoUrl,
      'photoUrl': photoUrl,
      'rating': rating,
      'reviewCount': reviewCount,
      'isPending': isPending,
      'isApproved': isApproved,
    };
  }

  // Shared option lists — used by BioDataScreen's chip pickers and by the
  // list screen's filter row, so both stay in sync automatically.
  static const List<String> specialtyOptions = [
    'Rebar Bending',
    'Welding',
    'Gates & Grills',
    'Staircases',
    'Roofing Trusses',
    'Structural Fabrication',
  ];

  static const List<String> rebarSizeOptions = [
    '8mm',
    '10mm',
    '12mm',
    '16mm',
    '20mm',
    '25mm',
  ];
}
