import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/okada_order.dart';
import '../models/okada_rider.dart';
import '../services/location_service.dart';
import 'order_tracking_screen.dart';
import '../widgets/provider_reviews_section.dart';

class RiderDetailScreen extends StatefulWidget {
  final OkadaRider rider;
  const RiderDetailScreen({super.key, required this.rider});

  @override
  State<RiderDetailScreen> createState() => _RiderDetailScreenState();
}

class _RiderDetailScreenState extends State<RiderDetailScreen> {
  bool _hasContacted = false; // true once Call or WhatsApp was tapped
  bool _confirmed = false; // customer explicitly ticks this
  bool _placingOrder = false;
  String? _orderError;

  Future<void> _callNumber(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    try {
      final launched = await launchUrl(uri);
      if (launched) {
        setState(() => _hasContacted = true);
      } else if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Could not open dialer.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not open dialer: $e')));
      }
    }
  }

  Future<void> _whatsApp(String phone) async {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    final formatted = digits.startsWith('0') ? '233${digits.substring(1)}' : digits;
    final uri = Uri.parse('https://wa.me/$formatted');
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (launched) {
        setState(() => _hasContacted = true);
      } else if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Could not open WhatsApp.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not open WhatsApp: $e')));
      }
    }
  }

  Future<void> _placeOrder() async {
    setState(() {
      _placingOrder = true;
      _orderError = null;
    });
    try {
      final position = await LocationService.getCurrentPosition();

      final docRef = FirebaseFirestore.instance.collection('okada_orders').doc();
      final order = OkadaOrder(
        id: docRef.id,
        riderId: widget.rider.id,
        riderName: widget.rider.riderName,
        customerLat: position.latitude,
        customerLng: position.longitude,
        status: OrderStatus.active,
      );
      await docRef.set(order.toMap());

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OrderTrackingScreen(order: order, rider: widget.rider),
        ),
      );
    } catch (e) {
      setState(() => _orderError = 'Could not place order: $e');
    } finally {
      if (mounted) setState(() => _placingOrder = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rider = widget.rider;
    final hasPhoto = rider.riderPhotoUrl != null && rider.riderPhotoUrl!.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: Text(rider.riderName)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.green[100],
                  backgroundImage: hasPhoto ? NetworkImage(rider.riderPhotoUrl!) : null,
                  onBackgroundImageError: hasPhoto
                      ? (e, stack) {
                          // ignore: avoid_print
                          print('[RiderDetailScreen] Bad photo URL: $e');
                        }
                      : null,
                  child: !hasPhoto
                      ? Icon(Icons.two_wheeler, color: Colors.green[800], size: 40)
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(rider.riderName,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text('Okada Rider',
                    style: TextStyle(color: Colors.green[800], fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 24),
              _InfoRow(icon: Icons.confirmation_number_outlined, label: 'Number Plate', value: rider.numberPlate),
              const SizedBox(height: 12),
              _InfoRow(icon: Icons.location_on_outlined, label: 'Station', value: rider.stationName),
              const SizedBox(height: 12),
              _InfoRow(icon: Icons.verified_user_outlined, label: 'Status', value: 'ID Verified'),
              const SizedBox(height: 18),
              ProviderReviewsSection(collection: 'okada_riders', providerId: rider.id),

              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _callNumber(rider.phoneNumber),
                      icon: const Icon(Icons.call),
                      label: const Text('Call'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: Colors.green[700],
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _whatsApp(rider.phoneNumber),
                      icon: const Icon(Icons.chat),
                      label: const Text('WhatsApp'),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                    ),
                  ),
                ],
              ),

              // Order flow only appears after the customer has made contact.
              if (_hasContacted) ...[
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _confirmed,
                  onChanged: (v) => setState(() => _confirmed = v ?? false),
                  title: const Text(
                    "I've spoken with the rider and confirmed the trip",
                    style: TextStyle(fontSize: 13),
                  ),
                ),
                if (_orderError != null) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(_orderError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                  ),
                ],
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: (_confirmed && !_placingOrder) ? _placeOrder : null,
                    icon: _placingOrder
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.motorcycle),
                    label: Text(_placingOrder ? 'Placing order…' : 'Order & Track Rider'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: Colors.orange[800],
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: Colors.grey[600])),
        const Spacer(),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}
