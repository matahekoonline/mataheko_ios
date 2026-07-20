import 'package:cloud_firestore/cloud_firestore.dart';

enum OrderStatus { active, completed, cancelled }

class OkadaOrder {
  final String id;
  final String riderId;
  final String riderName;
  final double customerLat;
  final double customerLng;
  final OrderStatus status;

  const OkadaOrder({
    required this.id,
    required this.riderId,
    required this.riderName,
    required this.customerLat,
    required this.customerLng,
    required this.status,
  });

  factory OkadaOrder.fromMap(String id, Map<String, dynamic> map) {
    return OkadaOrder(
      id: id,
      riderId: map['riderId'] as String? ?? '',
      riderName: map['riderName'] as String? ?? '',
      customerLat: (map['customerLat'] as num?)?.toDouble() ?? 0,
      customerLng: (map['customerLng'] as num?)?.toDouble() ?? 0,
      status: _statusFromString(map['status'] as String?),
    );
  }

  static OrderStatus _statusFromString(String? s) {
    switch (s) {
      case 'completed':
        return OrderStatus.completed;
      case 'cancelled':
        return OrderStatus.cancelled;
      default:
        return OrderStatus.active;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'riderId': riderId,
      'riderName': riderName,
      'customerLat': customerLat,
      'customerLng': customerLng,
      'status': status.name,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
