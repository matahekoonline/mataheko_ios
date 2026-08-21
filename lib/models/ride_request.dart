import 'package:cloud_firestore/cloud_firestore.dart';

enum RideRequestStatus { pending, approved, declined, cancelled }

RideRequestStatus rideRequestStatusFromString(String? value) {
  switch (value) {
    case 'approved':
      return RideRequestStatus.approved;
    case 'declined':
      return RideRequestStatus.declined;
    case 'cancelled':
      return RideRequestStatus.cancelled;
    default:
      return RideRequestStatus.pending;
  }
}

class RideRequest {
  /// Same as passengerUid -- one active request per passenger per ride.
  final String id;
  final String rideId;
  final String passengerUid;
  final String passengerName;
  final String passengerPhone;
  final int seatsRequested;
  final String? note;
  final RideRequestStatus status;
  final DateTime? createdAt;

  const RideRequest({
    required this.id,
    required this.rideId,
    required this.passengerUid,
    required this.passengerName,
    required this.passengerPhone,
    required this.seatsRequested,
    this.note,
    this.status = RideRequestStatus.pending,
    this.createdAt,
  });

  bool get isPending => status == RideRequestStatus.pending;
  bool get isApproved => status == RideRequestStatus.approved;

  factory RideRequest.fromMap(String id, Map<String, dynamic> map) {
    return RideRequest(
      id: id,
      rideId: (map['rideId'] as String?) ?? '',
      passengerUid: (map['passengerUid'] as String?) ?? '',
      passengerName: (map['passengerName'] as String?) ?? 'Passenger',
      passengerPhone: (map['passengerPhone'] as String?) ?? '',
      seatsRequested: (map['seatsRequested'] ?? 1) as int,
      note: map['note'] as String?,
      status: rideRequestStatusFromString(map['status'] as String?),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  factory RideRequest.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    return RideRequest.fromMap(doc.id, doc.data() ?? const {});
  }
}
