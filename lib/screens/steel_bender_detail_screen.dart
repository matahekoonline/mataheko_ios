// lib/screens/steel_bender_detail_screen.dart
//
// Full profile for a single Steel Bender: specialties, rebar sizes
// handled, on-site/mobile availability, experience, rating, and
// call/WhatsApp actions. Mirrors the detail-screen pattern used
// elsewhere in the app (e.g. listing_detail_screen.dart).

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/steel_bender.dart';

class SteelBenderDetailScreen extends StatelessWidget {
  final SteelBender bender;
  const SteelBenderDetailScreen({super.key, required this.bender});

  Future<void> _call() async {
    final uri = Uri(scheme: 'tel', path: bender.phoneNumber);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _whatsapp() async {
    final digits = bender.phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse('https://wa.me/$digits');
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Steel Bender Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.green[50],
                    backgroundImage: bender.photoUrl != null ? NetworkImage(bender.photoUrl!) : null,
                    child: bender.photoUrl == null
                        ? Icon(Icons.construction, color: Colors.green[700], size: 40)
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    bender.workshopName.isNotEmpty ? bender.workshopName : bender.fullName,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  if (bender.workshopName.isNotEmpty)
                    Text(bender.fullName, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star, size: 16, color: Colors.amber[700]),
                      const SizedBox(width: 4),
                      Text(
                        bender.rating > 0
                            ? '${bender.rating.toStringAsFixed(1)} (${bender.reviewCount} reviews)'
                            : 'No reviews yet',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            if (bender.offersOnSiteService)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange[100]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.directions_car, color: Colors.orange[800], size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Available for on-site / mobile service at construction sites',
                        style: TextStyle(fontSize: 12.5, color: Colors.orange[900], fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(child: _InfoTile(icon: Icons.location_on, label: 'Area', value: bender.stationArea)),
                const SizedBox(width: 12),
                Expanded(
                  child: _InfoTile(
                    icon: Icons.badge_outlined,
                    label: 'Experience',
                    value: '${bender.yearsOfExperience} yrs',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            const Text('Specialties', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: bender.specialties.map((s) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: Text(s, style: TextStyle(fontSize: 12.5, color: Colors.green[800], fontWeight: FontWeight.w600)),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            const Text('Rebar Sizes Handled', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 10),
            bender.rebarSizesHandled.isEmpty
                ? Text('Not specified', style: TextStyle(fontSize: 12.5, color: Colors.grey[600]))
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: bender.rebarSizesHandled.map((size) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(size, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                      );
                    }).toList(),
                  ),
            const SizedBox(height: 32),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _call,
                    icon: const Icon(Icons.call),
                    label: const Text('Call'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _whatsapp,
                    icon: const Icon(Icons.chat),
                    label: const Text('WhatsApp'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green[800],
                      side: BorderSide(color: Colors.green[700]!),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoTile({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.green[700]),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
