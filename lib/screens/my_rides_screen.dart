import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/ride_along.dart';
import '../services/auth_service.dart';
import 'manage_ride_requests_screen.dart';

/// A driver's own posted rides -- approval status, pause/resume toggle,
/// delete, and a shortcut into that ride's incoming seat requests.
class MyRidesScreen extends StatelessWidget {
  const MyRidesScreen({super.key});

  Future<void> _confirmDelete(BuildContext context, String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this ride?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) {
      await AuthService.instance.deleteRideAlong(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Rides')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: AuthService.instance.myPostedRidesStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final rides = snapshot.data!.docs.map(RideAlong.fromDoc).toList();
          if (rides.isEmpty) {
            return const Center(child: Text("You haven't posted any rides yet."));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: rides.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final ride = rides[index];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(ride.routeLabel,
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          _StatusPill(ride: ride),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(ride.scheduleLabel, style: TextStyle(color: Colors.grey.shade600)),
                      const SizedBox(height: 4),
                      Text('${ride.seatsAvailable}/${ride.seatsTotal} seats free · GH₵${ride.pricePerSeat.toStringAsFixed(0)}/seat'),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ManageRideRequestsScreen(
                                    rideId: ride.id,
                                    rideLabel: ride.routeLabel,
                                  ),
                                ),
                              ),
                              icon: const Icon(Icons.inbox_outlined, size: 18),
                              label: const Text('Requests'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (ride.isApproved)
                            IconButton(
                              tooltip: ride.isActive ? 'Pause' : 'Resume',
                              onPressed: () => AuthService.instance
                                  .setRideAlongActive(ride.id, !ride.isActive),
                              icon: Icon(ride.isActive ? Icons.pause_circle_outline : Icons.play_circle_outline),
                            ),
                          IconButton(
                            tooltip: 'Delete',
                            onPressed: () => _confirmDelete(context, ride.id),
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                          ),
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

class _StatusPill extends StatelessWidget {
  final RideAlong ride;
  const _StatusPill({required this.ride});

  @override
  Widget build(BuildContext context) {
    late Color color;
    late String label;
    if (ride.isPending) {
      color = Colors.orange;
      label = 'Pending review';
    } else if (!ride.isActive) {
      color = Colors.grey;
      label = 'Paused';
    } else {
      color = Colors.green;
      label = 'Live';
    }
    return Chip(
      label: Text(label, style: TextStyle(color: color, fontSize: 11)),
      backgroundColor: color.withOpacity(0.1),
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
