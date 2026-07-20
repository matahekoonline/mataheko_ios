class OkadaRider {
  final String id;
  final String riderName;
  final String phoneNumber;
  final String numberPlate;
  final String stationName;
  final String ghanaCardNumber; // admin-only, never shown to public
  final bool isActive;

  const OkadaRider({
    required this.id,
    required this.riderName,
    required this.phoneNumber,
    required this.numberPlate,
    required this.stationName,
    required this.ghanaCardNumber,
    this.isActive = true,
  });

  factory OkadaRider.fromMap(Map<String, dynamic> map, String id) {
    return OkadaRider(
      id: id,
      riderName: map['riderName'] as String? ?? '',
      phoneNumber: map['phoneNumber'] as String? ?? '',
      numberPlate: map['numberPlate'] as String? ?? '',
      stationName: map['stationName'] as String? ?? '',
      ghanaCardNumber: map['ghanaCardNumber'] as String? ?? '',
      isActive: map['isActive'] as bool? ?? true,
    );
  }

  /// Full record, admin-only writes.
  Map<String, dynamic> toMap() {
    return {
      'riderName': riderName,
      'phoneNumber': phoneNumber,
      'numberPlate': numberPlate,
      'stationName': stationName,
      'ghanaCardNumber': ghanaCardNumber,
      'isActive': isActive,
    };
  }
}
