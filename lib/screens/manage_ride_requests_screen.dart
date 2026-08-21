import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/ride_request.dart';
import '../services/auth_service.dart';

/// Driver's inbox for a single posted ride -- approve/decline seat
/// requests. Seat counts are adjusted server-side (see
/// AuthService.respondToRideRequest), so this screen just reflects
/// whatever comes back from the stream.
class ManageRideRequestsScreen extends StatelessWidget {
  final String rideId;
  final String rideLabel;

  const ManageRideRequestsScreen({
    super.key,
    required this.rideId,
    required this.rideLabel,
  });

  Future<void> _respond(BuildContext context, String requestId, bool approve) async {
    try {
      await AuthService.instance.respondToRideRequest(
        rideId: rideId,
        requestId: requestId,
        approve: approve,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not respond: $e')));
      }
    }
  }

  Future<void> _call(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Requests · $rideLabel')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: AuthService.instance.rideJoinRequestsStream(rideId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final requests = snapshot.data!.docs.map(RideRequest.fromDoc).toList();
          if (requests.isEmpty) {
            return const Center(child: Text('No requests yet.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final req = requests[index];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(req.passengerName,
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          _StatusChip(status: req.status),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('${req.seatsRequested} seat(s) requested'),
                      if (req.note != null && req.note!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text('"${req.note}"',
                            style: const TextStyle(fontStyle: FontStyle.italic)),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          TextButton.icon(
                            onPressed: () => _call(req.passengerPhone),
                            icon: const Icon(Icons.call, size: 18),
                            label: const Text('Call'),
                          ),
                          const Spacer(),
                          if (req.isPending) ...[
                            TextButton(
                              onPressed: () => _respond(context, req.id, false),
                              child: const Text('Decline'),
                            ),
                            const SizedBox(width: 4),
                            FilledButton(
                              onPressed: () => _respond(context, req.id, true),
                              child: const Text('Approve'),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final RideRequestStatus status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    late Color color;
    late String label;
    switch (status) {
      case RideRequestStatus.approved:
        color = Colors.green;
        label = 'Approved';
        break;
      case RideRequestStatus.declined:
        color = Colors.red;
        label = 'Declined';
        break;
      case RideRequestStatus.cancelled:
        color = Colors.grey;
        label = 'Cancelled';
        break;
      case RideRequestStatus.pending:
        color = Colors.orange;
        label = 'Pending';
        break;
    }
    return Chip(
      label: Text(label, style: TextStyle(color: color, fontSize: 12)),
      backgroundColor: color.withOpacity(0.1),
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
