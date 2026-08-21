import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/listing.dart';
import '../services/activity_service.dart';

class ListingDetailScreen extends StatelessWidget {
  final Listing listing;
  const ListingDetailScreen({super.key, required this.listing});

  Future<void> _callNumber(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _whatsApp(String phone) async {
    // Ghana numbers stored as 0XXXXXXXXX -> convert to +233 for WhatsApp
    final formatted = phone.startsWith('0')
        ? '233${phone.substring(1)}'
        : phone;
    final uri = Uri.parse('https://wa.me/$formatted');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(listing.name),
        actions: [
          StreamBuilder<bool>(
            stream: ActivityService.instance.isSavedStream(itemId: listing.id, type: 'listing'),
            builder: (context, snapshot) {
              final saved = snapshot.data == true;
              return IconButton(
                tooltip: saved ? 'Remove from saved' : 'Save listing',
                icon: Icon(saved ? Icons.favorite : Icons.favorite_border),
                onPressed: () async {
                  if (saved) {
                    await ActivityService.instance.removeSavedItem(itemId: listing.id, type: 'listing');
                  } else {
                    await ActivityService.instance.saveItem(
                      itemId: listing.id,
                      type: 'listing',
                      title: listing.name,
                      subtitle: listing.category,
                      imageUrl: listing.photoUrl ?? '',
                      metadata: {'locationText': listing.locationText},
                    );
                  }
                },
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: CircleAvatar(
                radius: 44,
                backgroundColor: Colors.green[100],
                child: Text(
                  listing.name.isNotEmpty ? listing.name[0] : '?',
                  style: TextStyle(fontSize: 36, color: Colors.green[900]),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              listing.category,
              style: TextStyle(color: Colors.green[800], fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(listing.description, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.location_on, size: 18, color: Colors.grey),
                const SizedBox(width: 6),
                Text(listing.locationText),
              ],
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _callNumber(listing.phone),
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
                    onPressed: () => _whatsApp(listing.phone),
                    icon: const Icon(Icons.chat),
                    label: const Text('WhatsApp'),
                    style: OutlinedButton.styleFrom(
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
