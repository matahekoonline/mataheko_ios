import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../models/ride_along.dart';
import '../../services/auth_service.dart';
import 'add_ride_along_screen.dart';
import 'ride_along_detail_screen.dart';

/// Public browse screen -- "Ride Along" tile on HomeScreen opens here.
/// Lists every approved + active ride, newest first. Tap a card for
/// details/contact/request; tap the FAB to offer a ride as a driver.
class RideAlongScreen extends StatelessWidget {
  const RideAlongScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ride Along')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: AuthService.instance.rideAlongStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Something went wrong: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final rides = snapshot.data!.docs.map(RideAlong.fromDoc).toList();

          if (rides.isEmpty) {
            return const _EmptyState();
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: rides.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _RideCard(ride: rides[index]),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddRideAlongScreen()),
        ),
        icon: const Icon(Icons.directions_car),
        label: const Text('Offer a Ride'),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.directions_car_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'No rides posted yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Have a car and drive the same route every day? Be the first to offer a ride.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

class _RideCard extends StatelessWidget {
  final RideAlong ride;
  const _RideCard({required this.ride});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => RideAlongDetailScreen(rideId: ride.id)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: theme.colorScheme.primaryContainer,
                backgroundImage:
                    ride.coverPhotoUrl.isNotEmpty ? NetworkImage(ride.coverPhotoUrl) : null,
                child: ride.coverPhotoUrl.isEmpty
                    ? const Icon(Icons.directions_car)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ride.routeLabel,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          ride.isRecurring ? Icons.repeat : Icons.event,
                          size: 14,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            ride.scheduleLabel,
                            style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Driver: ${ride.driverName}',
                      style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'GH₵${ride.pricePerSeat.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                      fontSize: 16,
                    ),
                  ),
                  const Text('per seat', style: TextStyle(fontSize: 11)),
                  const SizedBox(height: 6),
                  Chip(
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    label: Text(
                      ride.isFull ? 'Full' : '${ride.seatsAvailable} seat(s)',
                      style: const TextStyle(fontSize: 11),
                    ),
                    backgroundColor:
                        ride.isFull ? Colors.red.shade50 : Colors.green.shade50,
                    labelStyle: TextStyle(
                      color: ride.isFull ? Colors.red.shade700 : Colors.green.shade700,
                    ),
                    side: BorderSide.none,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
