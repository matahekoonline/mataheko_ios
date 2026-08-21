import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/ride_along.dart';
import '../../services/auth_service.dart';
import '../widgets/provider_reviews_section.dart';

/// Shows full ride details. Passengers get BOTH a direct contact card
/// (call / WhatsApp the driver) and an in-app "Request Seat" flow that
/// notifies the driver and reserves a seat once approved.
class RideAlongDetailScreen extends StatefulWidget {
  final String rideId;
  const RideAlongDetailScreen({super.key, required this.rideId});

  @override
  State<RideAlongDetailScreen> createState() => _RideAlongDetailScreenState();
}

class _RideAlongDetailScreenState extends State<RideAlongDetailScreen> {
  Map<String, dynamic>? _myRequest;
  bool _loadingMyRequest = true;

  @override
  void initState() {
    super.initState();
    _loadMyRequest();
  }

  Future<void> _loadMyRequest() async {
    final req = await AuthService.instance.getMyRideRequest(widget.rideId);
    if (mounted) setState(() {
      _myRequest = req;
      _loadingMyRequest = false;
    });
  }

  Future<void> _callDriver(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _whatsAppDriver(String phone, String rideRoute) async {
    // Strip anything but digits, then assume Ghana local format if it
    // starts with 0 (e.g. 0244xxxxxx -> 233244xxxxxx).
    var digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('0')) digits = '233${digits.substring(1)}';
    final text = Uri.encodeComponent(
      "Hi, I saw your ride ($rideRoute) on Mataheko App and I'd like to join.",
    );
    final uri = Uri.parse('https://wa.me/$digits?text=$text');
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _requestSeat(RideAlong ride) async {
    int seats = 1;
    final noteController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Request a seat'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${ride.routeLabel}\n${ride.scheduleLabel}'),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Seats needed'),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: seats > 1
                            ? () => setDialogState(() => seats--)
                            : null,
                      ),
                      Text('$seats', style: const TextStyle(fontSize: 16)),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: seats < ride.seatsAvailable
                            ? () => setDialogState(() => seats++)
                            : null,
                      ),
                    ],
                  ),
                ],
              ),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(
                  labelText: 'Note to driver (optional)',
                  hintText: 'e.g. pickup point, timing',
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Send Request'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    try {
      await AuthService.instance.requestToJoinRide(
        rideId: ride.id,
        seatsRequested: seats,
        note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
      );
      await _loadMyRequest();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request sent to the driver.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not send request: $e')),
        );
      }
    }
  }

  Future<void> _cancelRequest() async {
    if (_myRequest == null) return;
    await AuthService.instance.cancelRideRequest(widget.rideId, _myRequest!['passengerUid']);
    await _loadMyRequest();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ride Details')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('ride_along')
            .doc(widget.rideId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.data!.exists) {
            return const Center(child: Text('This ride is no longer available.'));
          }

          final ride = RideAlong.fromDoc(snapshot.data!);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (ride.photoUrls.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    height: 180,
                    child: PageView(
                      children: ride.photoUrls
                          .map((url) => Image.network(url, fit: BoxFit.cover))
                          .toList(),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Text(ride.routeLabel,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Pickup: ${ride.stationArea}',
                  style: TextStyle(color: Colors.grey.shade700)),
              const SizedBox(height: 12),
              _InfoRow(icon: Icons.schedule, label: ride.scheduleLabel),
              _InfoRow(
                icon: Icons.event_seat,
                label: ride.isFull
                    ? 'Fully booked'
                    : '${ride.seatsAvailable} of ${ride.seatsTotal} seats available',
              ),
              _InfoRow(
                icon: Icons.payments_outlined,
                label: 'GH₵${ride.pricePerSeat.toStringAsFixed(2)} per seat',
              ),
              if (ride.carModel != null || ride.carColor != null || ride.plateNumber != null)
                _InfoRow(
                  icon: Icons.directions_car_filled_outlined,
                  label: [ride.carColor, ride.carModel, ride.plateNumber]
                      .where((e) => e != null && e.isNotEmpty)
                      .join(' • '),
                ),
              if (ride.notes != null && ride.notes!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(ride.notes!, style: const TextStyle(fontStyle: FontStyle.italic)),
              ],
              const Divider(height: 32),
              Text('Driver: ${ride.driverName}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              if (ride.rating > 0)
                Row(
                  children: [
                    const Icon(Icons.star, size: 16, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text('${ride.rating.toStringAsFixed(1)} (${ride.reviewCount})'),
                  ],
                ),
              const SizedBox(height: 18),
              ProviderReviewsSection(collection: 'ride_along', providerId: ride.id, initialRating: ride.rating, initialReviewCount: ride.reviewCount),


              const SizedBox(height: 16),

              // Direct contact card -- always available.
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _callDriver(ride.phoneNumber),
                      icon: const Icon(Icons.call),
                      label: const Text('Call'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _whatsAppDriver(ride.phoneNumber, ride.routeLabel),
                      icon: const Icon(Icons.chat),
                      label: const Text('WhatsApp'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // In-app request flow.
              if (_loadingMyRequest)
                const Center(child: Padding(
                  padding: EdgeInsets.all(8),
                  child: SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                ))
              else
                _RequestStatusButton(
                  ride: ride,
                  myRequest: _myRequest,
                  onRequest: () => _requestSeat(ride),
                  onCancel: _cancelRequest,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade700),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}

class _RequestStatusButton extends StatelessWidget {
  final RideAlong ride;
  final Map<String, dynamic>? myRequest;
  final VoidCallback onRequest;
  final VoidCallback onCancel;

  const _RequestStatusButton({
    required this.ride,
    required this.myRequest,
    required this.onRequest,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final status = myRequest?['status'] as String?;

    if (status == null || status == 'declined' || status == 'cancelled') {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: ride.isFull ? null : onRequest,
          icon: const Icon(Icons.event_seat),
          label: Text(ride.isFull ? 'Ride Full' : 'Request Seat'),
        ),
      );
    }

    if (status == 'pending') {
      return Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Icon(Icons.hourglass_top, color: Colors.orange),
                SizedBox(width: 8),
                Expanded(child: Text('Request pending — waiting for the driver to respond.')),
              ],
            ),
          ),
          TextButton(onPressed: onCancel, child: const Text('Cancel request')),
        ],
      );
    }

    // approved
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Expanded(child: Text('Seat reserved! Contact the driver to confirm pickup.')),
            ],
          ),
        ),
        TextButton(onPressed: onCancel, child: const Text('Cancel my seat')),
      ],
    );
  }
}
