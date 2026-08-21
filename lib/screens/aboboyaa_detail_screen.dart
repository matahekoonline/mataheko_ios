import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/aboboyaa_rider.dart';
import '../widgets/provider_reviews_section.dart';

/// Aboboyaa rider profile.
///
/// Mirrors RiderDetailScreen (Okada) so both categories give customers the
/// same experience: photo, name, key details, reviews, and working
/// Call / WhatsApp actions -- previously this screen's "Contact Rider"
/// button just showed a "coming soon" snackbar instead of actually
/// launching the phone dialer or WhatsApp.
class AboboyaaDetailScreen extends StatefulWidget {
  final AboboyaaRider rider;

  const AboboyaaDetailScreen({
    super.key,
    required this.rider,
  });

  @override
  State<AboboyaaDetailScreen> createState() => _AboboyaaDetailScreenState();
}

class _AboboyaaDetailScreenState extends State<AboboyaaDetailScreen> {
  Future<void> _callNumber(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    try {
      final launched = await launchUrl(uri);
      if (!launched && mounted) {
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
      if (!launched && mounted) {
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

  @override
  Widget build(BuildContext context) {
    final rider = widget.rider;
    final hasPhoto = rider.riderPhotoUrl != null && rider.riderPhotoUrl!.trim().isNotEmpty;

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
                          print('[AboboyaaDetailScreen] Bad photo URL: $e');
                        }
                      : null,
                  child: !hasPhoto
                      ? Icon(Icons.local_shipping_outlined, color: Colors.green[800], size: 40)
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  rider.riderName,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(
                  'Aboboyaa Rider',
                  style: TextStyle(color: Colors.green[800], fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 24),
              _InfoRow(
                icon: Icons.confirmation_number_outlined,
                label: 'Number Plate',
                value: rider.vehicleNumber.isEmpty ? 'Not provided' : rider.vehicleNumber,
              ),
              const SizedBox(height: 12),
              _InfoRow(
                icon: Icons.location_on_outlined,
                label: 'Station',
                value: rider.stationName.isEmpty ? 'Not provided' : rider.stationName,
              ),
              const SizedBox(height: 12),
              _InfoRow(
                icon: Icons.verified_user_outlined,
                label: 'Status',
                value: rider.isApproved ? 'ID Verified' : 'Pending Approval',
              ),
              if (rider.businessName.isNotEmpty) ...[
                const SizedBox(height: 12),
                _InfoRow(
                  icon: Icons.storefront_outlined,
                  label: 'Business',
                  value: rider.businessName,
                ),
              ],
              if (rider.yearsOfExperience > 0) ...[
                const SizedBox(height: 12),
                _InfoRow(
                  icon: Icons.workspace_premium_outlined,
                  label: 'Experience',
                  value: '${rider.yearsOfExperience} years',
                ),
              ],
              if (rider.loadTypes.isNotEmpty) ...[
                const SizedBox(height: 18),
                const Text('Loads handled', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: rider.loadTypes
                      .map((t) => Chip(label: Text(t), backgroundColor: Colors.green[50]))
                      .toList(),
                ),
              ],
              const SizedBox(height: 18),
              ProviderReviewsSection(
                collection: 'aboboyaa_riders',
                providerId: rider.id,
                initialRating: rider.rating,
                initialReviewCount: rider.reviewCount,
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: rider.phoneNumber.trim().isEmpty
                          ? null
                          : () => _callNumber(rider.phoneNumber),
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
                      onPressed: rider.phoneNumber.trim().isEmpty
                          ? null
                          : () => _whatsApp(rider.phoneNumber),
                      icon: const Icon(Icons.chat),
                      label: const Text('WhatsApp'),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                    ),
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
