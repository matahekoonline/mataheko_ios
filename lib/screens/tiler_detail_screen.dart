import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/tiler.dart';
import '../widgets/rating_display.dart';

class TilerDetailScreen extends StatelessWidget {
  final Tiler tiler;
  const TilerDetailScreen({super.key, required this.tiler});

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
      appBar: AppBar(title: Text(tiler.businessName.isNotEmpty ? tiler.businessName : tiler.name)),
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
                  backgroundColor: Colors.teal[100],
                  backgroundImage: (tiler.photoUrl != null && tiler.photoUrl!.isNotEmpty)
                      ? NetworkImage(tiler.photoUrl!)
                      : null,
                  child: (tiler.photoUrl == null || tiler.photoUrl!.isEmpty)
                      ? Icon(Icons.grid_on, color: Colors.teal[800], size: 32)
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tiler.businessName.isNotEmpty ? tiler.businessName : tiler.name,
                        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                      ),
                      Text(tiler.name, style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                      const SizedBox(height: 6),
                      RatingDisplay(rating: tiler.rating, reviewCount: tiler.reviewCount),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.verified, size: 16, color: Colors.teal[700]),
                const SizedBox(width: 4),
                Text('ID Verified', style: TextStyle(fontSize: 12, color: Colors.teal[700], fontWeight: FontWeight.w600)),
                const SizedBox(width: 16),
                Icon(Icons.location_on_outlined, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(tiler.stationArea, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),

            const SizedBox(height: 24),
            _SectionCard(
              title: 'Experience',
              child: Row(
                children: [
                  Icon(Icons.work_history_outlined, color: Colors.teal[700], size: 22),
                  const SizedBox(width: 10),
                  Text(
                    '${tiler.yearsOfExperience} years in the trade',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  if (tiler.offersOnSiteConsultation)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.home_work_outlined, size: 14, color: Colors.orange[800]),
                          const SizedBox(width: 4),
                          Text('On-Site Consultation', style: TextStyle(fontSize: 11, color: Colors.orange[800], fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            _SectionCard(
              title: 'Specialties Serviced',
              child: tiler.specialtiesServiced.isEmpty
                  ? const Text('Not specified', style: TextStyle(color: Colors.grey))
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: tiler.specialtiesServiced
                          .map((v) => Chip(
                                label: Text(v, style: const TextStyle(fontSize: 12)),
                                backgroundColor: Colors.teal[50],
                                side: BorderSide(color: Colors.teal[200]!),
                              ))
                          .toList(),
                    ),
            ),

            if (tiler.materialsWorkedWith.isNotEmpty) ...[
              const SizedBox(height: 16),
              _SectionCard(
                title: 'Materials Worked With',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: tiler.materialsWorkedWith
                      .map((b) => Chip(
                            label: Text(b, style: const TextStyle(fontSize: 12)),
                            backgroundColor: Colors.blueGrey[50],
                            side: BorderSide(color: Colors.blueGrey[200]!),
                            avatar: const Icon(Icons.layers_outlined, size: 14),
                          ))
                      .toList(),
                ),
              ),
            ],

            const SizedBox(height: 16),
            _SectionCard(
              title: 'Services Offered',
              child: tiler.servicesOffered.isEmpty
                  ? const Text('Not specified', style: TextStyle(color: Colors.grey))
                  : Column(
                      children: tiler.servicesOffered
                          .map((s) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 3),
                                child: Row(
                                  children: [
                                    Icon(Icons.check_circle, size: 16, color: Colors.teal[700]),
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
                    onPressed: () => _callNumber(tiler.phoneNumber),
                    icon: const Icon(Icons.call),
                    label: const Text('Call'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: Colors.teal[700],
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _whatsApp(tiler.phoneNumber),
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
