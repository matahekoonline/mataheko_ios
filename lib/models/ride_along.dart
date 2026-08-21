import 'package:cloud_firestore/cloud_firestore.dart';

/// Whether a ride is a single trip or a standing daily/weekly commute.
enum RideAlongType { oneTime, recurring }

RideAlongType rideAlongTypeFromString(String? value) {
  return value == 'recurring' ? RideAlongType.recurring : RideAlongType.oneTime;
}

class RideAlong {
  final String id;
  final String? driverUid; // null when added directly by an admin
  final String driverName;
  final String phoneNumber;

  final String fromArea;
  final String toArea;
  final String stationArea; // pickup landmark/area

  final RideAlongType rideType;
  final DateTime? departureDateTime; // set when rideType == oneTime
  final String? departureTime; // e.g. "6:30 AM", set when rideType == recurring
  final List<String> recurringDays; // e.g. ['Mon','Tue','Wed','Thu','Fri']

  final int seatsTotal;
  final int seatsAvailable;
  final double pricePerSeat;

  final String? carModel;
  final String? carColor;
  final String? plateNumber;
  final String? notes;

  final List<String> photoUrls;
  final double rating;
  final int reviewCount;

  final bool isApproved;
  final bool isPending;
  final bool isActive;

  final String ghanaCardNumber;
  final String? ghanaCardPhotoUrl;
  final DateTime? createdAt;

  const RideAlong({
    required this.id,
    this.driverUid,
    required this.driverName,
    required this.phoneNumber,
    required this.fromArea,
    required this.toArea,
    required this.stationArea,
    required this.rideType,
    this.departureDateTime,
    this.departureTime,
    this.recurringDays = const [],
    required this.seatsTotal,
    required this.seatsAvailable,
    required this.pricePerSeat,
    this.carModel,
    this.carColor,
    this.plateNumber,
    this.notes,
    this.photoUrls = const [],
    this.rating = 0.0,
    this.reviewCount = 0,
    this.isApproved = false,
    this.isPending = true,
    this.isActive = true,
    required this.ghanaCardNumber,
    this.ghanaCardPhotoUrl,
    this.createdAt,
  });

  bool get isRecurring => rideType == RideAlongType.recurring;
  bool get isFull => seatsAvailable <= 0;
  String get coverPhotoUrl => photoUrls.isNotEmpty ? photoUrls.first : '';
  String get routeLabel => '$fromArea  →  $toArea';

  /// Human-readable schedule line for list/detail cards, e.g.
  /// "Mon, Tue, Wed, Thu, Fri • 6:30 AM" or "12/8/2026 • 07:00".
  String get scheduleLabel {
    if (isRecurring) {
      final days = recurringDays.isEmpty ? 'Recurring' : recurringDays.join(', ');
      return departureTime != null ? '$days • $departureTime' : days;
    }
    if (departureDateTime == null) return 'One-time trip';
    final d = departureDateTime!;
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '${d.day}/${d.month}/${d.year} • $hh:$mm';
  }

  factory RideAlong.fromMap(String id, Map<String, dynamic> map) {
    return RideAlong(
      id: id,
      driverUid: map['driverUid'] as String?,
      driverName: (map['driverName'] as String?) ?? '',
      phoneNumber: (map['phoneNumber'] as String?) ?? '',
      fromArea: (map['fromArea'] as String?) ?? '',
      toArea: (map['toArea'] as String?) ?? '',
      stationArea: (map['stationArea'] as String?) ?? '',
      rideType: rideAlongTypeFromString(map['rideType'] as String?),
      departureDateTime: (map['departureDateTime'] as Timestamp?)?.toDate(),
      departureTime: map['departureTime'] as String?,
      recurringDays: List<String>.from(map['recurringDays'] ?? const []),
      seatsTotal: (map['seatsTotal'] ?? 0) as int,
      seatsAvailable: (map['seatsAvailable'] ?? 0) as int,
      pricePerSeat: ((map['pricePerSeat'] ?? 0) as num).toDouble(),
      carModel: map['carModel'] as String?,
      carColor: map['carColor'] as String?,
      plateNumber: map['plateNumber'] as String?,
      notes: map['notes'] as String?,
      photoUrls: List<String>.from(map['photoUrls'] ?? const []),
      rating: ((map['rating'] ?? 0.0) as num).toDouble(),
      reviewCount: (map['reviewCount'] ?? 0) as int,
      isApproved: (map['isApproved'] ?? false) as bool,
      isPending: (map['isPending'] ?? true) as bool,
      isActive: (map['isActive'] ?? true) as bool,
      ghanaCardNumber: (map['ghanaCardNumber'] as String?) ?? '',
      ghanaCardPhotoUrl: map['ghanaCardPhotoUrl'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  factory RideAlong.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    return RideAlong.fromMap(doc.id, doc.data() ?? const {});
  }
}
