import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/mason.dart';
import '../widgets/rating_display.dart';

class MasonDetailScreen extends StatelessWidget {
  final Mason mason;
  const MasonDetailScreen({super.key, required this.mason});

  Future<void> _callNumber(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _whatsApp(String phone) async {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    final formatted = digits.startsWith('0') ? '233${digits.substring(1)}' : digits;
    final uri = Uri.parse('https://wa.me/$formatted');
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(mason.businessName.isNotEmpty ? mason.businessName : mason.name)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.green[100],
                  backgroundImage: (mason.photoUrl != null && mason.photoUrl!.isNotEmpty)
                      ? NetworkImage(mason.photoUrl!)
                      : null,
                  child: (mason.photoUrl == null || mason.photoUrl!.isEmpty)
                      ? Icon(Icons.foundation, color: Colors.green[800], size: 32)
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mason.businessName.isNotEmpty ? mason.businessName : mason.name,
                        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                      ),
                      Text(mason.name, style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                      const SizedBox(height: 6),
                      RatingDisplay(rating: mason.rating, reviewCount: mason.reviewCount),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.verified, size: 16, color: Colors.green[700]),
                const SizedBox(width: 4),
                Text('ID Verified', style: TextStyle(fontSize: 12, color: Colors.green[700], fontWeight: FontWeight.w600)),
                const SizedBox(width: 16),
                Icon(Icons.location_on_outlined, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(mason.stationArea, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),

            const SizedBox(height: 24),
            _SectionCard(
              title: 'Experience',
              child: Row(
                children: [
                  Icon(Icons.work_history_outlined, color: Colors.green[700], size: 22),
                  const SizedBox(width: 10),
                  Text(
                    '${mason.yearsOfExperience} years in the trade',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  if (mason.offersEmergencyRepairs)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.build_circle_outlined, size: 14, color: Colors.blue[800]),
                          const SizedBox(width: 4),
                          Text('Emergency Repairs', style: TextStyle(fontSize: 11, color: Colors.blue[800], fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            _SectionCard(
              title: 'Building Types Served',
              child: mason.buildingTypes.isEmpty
                  ? const Text('Not specified', style: TextStyle(color: Colors.grey))
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: mason.buildingTypes
                          .map((v) => Chip(
                                label: Text(v, style: const TextStyle(fontSize: 12)),
                                backgroundColor: Colors.green[50],
                                side: BorderSide(color: Colors.green[200]!),
                              ))
                          .toList(),
                    ),
            ),

            if (mason.specialties.isNotEmpty) ...[
              const SizedBox(height: 16),
              _SectionCard(
                title: 'Masonry Specialties',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: mason.specialties
                      .map((s) => Chip(
                            label: Text(s, style: const TextStyle(fontSize: 12)),
                            backgroundColor: Colors.blue[50],
                            side: BorderSide(color: Colors.blue[200]!),
                            avatar: const Icon(Icons.construction, size: 14),
                          ))
                      .toList(),
                ),
              ),
            ],

            const SizedBox(height: 16),
            _SectionCard(
              title: 'Services Offered',
              child: mason.servicesOffered.isEmpty
                  ? const Text('Not specified', style: TextStyle(color: Colors.grey))
                  : Column(
                      children: mason.servicesOffered
                          .map((s) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 3),
                                child: Row(
                                  children: [
                                    Icon(Icons.check_circle, size: 16, color: Colors.green[700]),
                                    const SizedBox(width: 8),
                                    Text(s, style: const TextStyle(fontSize: 13)),
                                  ],
                                ),
                              ))
                          .toList(),
                    ),
            ),

            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _callNumber(mason.phoneNumber),
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
                    onPressed: () => _whatsApp(mason.phoneNumber),
                    icon: const Icon(Icons.chat),
                    label: const Text('WhatsApp'),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey[800])),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
