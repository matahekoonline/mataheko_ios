class OkadaRider {
  final String id;
  final String riderName;
  final String phoneNumber;
  final String numberPlate;
  final String stationName;
  final String ghanaCardNumber;
  final String? riderPhotoUrl; // public-facing photo, shown to app users
  final String? ghanaCardPhotoUrl; // SENSITIVE — admin-only, never shown publicly

  /// 'pending' | 'approved'. Self-registered riders (via BioDataScreen)
  /// start as 'pending' and need an admin to approve them before they show
  /// up publicly in OkadaRidersScreen. Missing/null is treated as
  /// 'approved' for backward compatibility with riders added by admins
  /// before this field existed.
  final String verificationStatus;

  bool get isApproved => verificationStatus == 'approved';
  bool get isPending => verificationStatus == 'pending';

  const OkadaRider({
    required this.id,
    required this.riderName,
    required this.phoneNumber,
    required this.numberPlate,
    required this.stationName,
    required this.ghanaCardNumber,
    this.riderPhotoUrl,
    this.ghanaCardPhotoUrl,
    this.verificationStatus = 'approved',
  });

  Map<String, dynamic> toMap() {
    return {
      'riderName': riderName,
      'phoneNumber': phoneNumber,
      'numberPlate': numberPlate,
      'stationName': stationName,
      'ghanaCardNumber': ghanaCardNumber,
      'riderPhotoUrl': riderPhotoUrl,
      'ghanaCardPhotoUrl': ghanaCardPhotoUrl,
      'verificationStatus': verificationStatus,
      'createdAt': DateTime.now().toIso8601String(),
    };
  }

  factory OkadaRider.fromMap(String id, Map<String, dynamic> map) {
    return OkadaRider(
      id: id,
      riderName: map['riderName'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      numberPlate: map['numberPlate'] ?? '',
      stationName: map['stationName'] ?? '',
      ghanaCardNumber: map['ghanaCardNumber'] ?? '',
      riderPhotoUrl: map['riderPhotoUrl'],
      ghanaCardPhotoUrl: map['ghanaCardPhotoUrl'],
      verificationStatus: map['verificationStatus'] ?? 'approved',
    );
  }
}
