import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/home_cook.dart';
import '../widgets/rating_display.dart';
import 'marketplace_screen.dart' show formatCediPrice;

class HomeCookDetailScreen extends StatelessWidget {
  final HomeCook cook;
  const HomeCookDetailScreen({super.key, required this.cook});

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
      appBar: AppBar(title: Text(cook.businessName.isNotEmpty ? cook.businessName : cook.name)),
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
                  backgroundColor: Colors.deepOrange[100],
                  backgroundImage: (cook.photoUrl != null && cook.photoUrl!.isNotEmpty)
                      ? NetworkImage(cook.photoUrl!)
                      : null,
                  child: (cook.photoUrl == null || cook.photoUrl!.isEmpty)
                      ? Icon(Icons.restaurant, color: Colors.deepOrange[800], size: 32)
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cook.businessName.isNotEmpty ? cook.businessName : cook.name,
                        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                      ),
                      Text(cook.name, style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                      const SizedBox(height: 6),
                      RatingDisplay(rating: cook.rating, reviewCount: cook.reviewCount),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.verified, size: 16, color: Colors.deepOrange[700]),
                const SizedBox(width: 4),
                Text('ID Verified', style: TextStyle(fontSize: 12, color: Colors.deepOrange[700], fontWeight: FontWeight.w600)),
                const SizedBox(width: 16),
                Icon(Icons.location_on_outlined, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(cook.stationArea, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),

            const SizedBox(height: 24),
            _SectionCard(
              title: 'Delivery',
              child: Row(
                children: [
                  Icon(
                    cook.offersDelivery ? Icons.delivery_dining : Icons.storefront_outlined,
                    color: Colors.deepOrange[700],
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      cook.offersDelivery ? 'Delivers to your area' : 'Pickup only',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),

            if (cook.offersDelivery && cook.deliveryAreas.isNotEmpty) ...[
              const SizedBox(height: 16),
              _SectionCard(
                title: 'Delivery Areas',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: cook.deliveryAreas
                      .map((v) => Chip(
                            label: Text(v, style: const TextStyle(fontSize: 12)),
                            backgroundColor: Colors.deepOrange[50],
                            side: BorderSide(color: Colors.deepOrange[200]!),
                            avatar: const Icon(Icons.pin_drop_outlined, size: 14),
                          ))
                      .toList(),
                ),
              ),
            ],

            const SizedBox(height: 16),
            _SectionCard(
              title: 'Cuisine',
              child: cook.cuisineTypes.isEmpty
                  ? const Text('Not specified', style: TextStyle(color: Colors.grey))
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: cook.cuisineTypes
                          .map((v) => Chip(
                                label: Text(v, style: const TextStyle(fontSize: 12)),
                                backgroundColor: Colors.deepOrange[50],
                                side: BorderSide(color: Colors.deepOrange[200]!),
                              ))
                          .toList(),
                    ),
            ),

            const SizedBox(height: 16),
            _SectionCard(
              title: 'Menu',
              child: cook.menu.isEmpty
                  ? const Text('No menu items added yet', style: TextStyle(color: Colors.grey))
                  : Column(
                      children: cook.menu.map((item) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            item.name,
                                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                          ),
                                        ),
                                        if (!item.available) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: Colors.grey[200],
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text('Sold out',
                                                style: TextStyle(fontSize: 10, color: Colors.grey[700])),
                                          ),
                                        ],
                                      ],
                                    ),
                                    if (item.description != null && item.description!.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        item.description!,
                                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                formatCediPrice(item.price),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: item.available ? Colors.deepOrange[700] : Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
            ),

            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Call or WhatsApp to place an order',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _callNumber(cook.phoneNumber),
                    icon: const Icon(Icons.call),
                    label: const Text('Call'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: Colors.deepOrange[700],
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _whatsApp(cook.phoneNumber),
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
