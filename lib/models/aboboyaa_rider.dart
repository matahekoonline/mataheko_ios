class AboboyaaRider {
  final String id;

  // Basic information
  final String riderName;
  final String businessName;
  final String phoneNumber;
  final String vehicleNumber;
  final String stationName;

  // Experience / services
  final int yearsOfExperience;
  final List<String> loadTypes;
  final List<String> servicesOffered;

  // Availability
  final bool isAvailable;

  // Identity
  final String ghanaCardNumber;

  // Photos
  final String? riderPhotoUrl;
  final String? ghanaCardPhotoUrl;

  // Verification
  final String verificationStatus;
  final bool legacyIsApproved;
  final bool legacyIsPending;

  // Rating
  final double rating;
  final int reviewCount;

  const AboboyaaRider({
    required this.id,
    required this.riderName,
    required this.businessName,
    required this.phoneNumber,
    required this.vehicleNumber,
    required this.stationName,
    required this.yearsOfExperience,
    required this.loadTypes,
    required this.servicesOffered,
    required this.isAvailable,
    required this.ghanaCardNumber,
    this.riderPhotoUrl,
    this.ghanaCardPhotoUrl,
    this.verificationStatus = 'approved',
    this.legacyIsApproved = false,
    this.legacyIsPending = false,
    this.rating = 0.0,
    this.reviewCount = 0,
  });

  /// Supports both the current verificationStatus schema and older
  /// admin-created records that used isApproved/isPending booleans.
  bool get isApproved =>
      verificationStatus.trim().toLowerCase() == 'approved' ||
      legacyIsApproved;

  bool get isPending =>
      verificationStatus.trim().toLowerCase() == 'pending' ||
      legacyIsPending;

  Map<String, dynamic> toMap() {
    return {
      'riderName': riderName,
      'businessName': businessName,
      'phoneNumber': phoneNumber,
      'vehicleNumber': vehicleNumber,
      'stationName': stationName,
      'yearsOfExperience': yearsOfExperience,
      'loadTypes': loadTypes,
      'servicesOffered': servicesOffered,
      'isAvailable': isAvailable,
      'ghanaCardNumber': ghanaCardNumber,
      'riderPhotoUrl': riderPhotoUrl,
      'ghanaCardPhotoUrl': ghanaCardPhotoUrl,
      'verificationStatus': verificationStatus,
      'isApproved': legacyIsApproved,
      'isPending': legacyIsPending,
      'rating': rating,
      'reviewCount': reviewCount,
    };
  }

  static int _toInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  factory AboboyaaRider.fromMap(
    String id,
    Map<String, dynamic> map,
  ) {
    final rawVerificationStatus =
        (map['verificationStatus'] ?? '').toString().trim();

    final legacyApproved = map['isApproved'] == true;
    final legacyPending = map['isPending'] == true;

    final verificationStatus = rawVerificationStatus.isNotEmpty
        ? rawVerificationStatus
        : (legacyPending
            ? 'pending'
            : (legacyApproved ? 'approved' : 'approved'));

    return AboboyaaRider(
      id: id,
      riderName: (map['riderName'] ?? map['name'] ?? '').toString(),
      businessName: (map['businessName'] ?? '').toString(),
      phoneNumber: (map['phoneNumber'] ?? map['phone'] ?? '').toString(),
      vehicleNumber:
          (map['vehicleNumber'] ?? map['numberPlate'] ?? '').toString(),
      stationName: (map['stationName'] ?? map['stationArea'] ?? '').toString(),
      yearsOfExperience: _toInt(map['yearsOfExperience']),
      loadTypes: map['loadTypes'] is List
          ? List<String>.from(
              (map['loadTypes'] as List).map((e) => e.toString()),
            )
          : <String>[],
      servicesOffered: map['servicesOffered'] is List
          ? List<String>.from(
              (map['servicesOffered'] as List).map((e) => e.toString()),
            )
          : <String>[],
      isAvailable: map['isAvailable'] == true,
      ghanaCardNumber:
          (map['ghanaCardNumber'] ?? '').toString(),
      riderPhotoUrl:
          (map['riderPhotoUrl'] ?? map['photoUrl'])?.toString(),
      ghanaCardPhotoUrl:
          (map['ghanaCardPhotoUrl'] ?? '').toString(),
      verificationStatus: verificationStatus,
      legacyIsApproved: legacyApproved,
      legacyIsPending: legacyPending,
      rating: _toDouble(map['rating']),
      reviewCount: _toInt(map['reviewCount']),
    );
  }
}
