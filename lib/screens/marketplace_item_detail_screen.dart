// lib/screens/marketplace_item_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/marketplace_item.dart';
import '../services/marketplace_service.dart';
import '../services/activity_service.dart';
import '../screens/marketplace_screen.dart' show formatCediPrice;

class MarketplaceItemDetailScreen extends StatefulWidget {
  final MarketplaceItem item;
  const MarketplaceItemDetailScreen({super.key, required this.item});

  @override
  State<MarketplaceItemDetailScreen> createState() => _MarketplaceItemDetailScreenState();
}

class _MarketplaceItemDetailScreenState extends State<MarketplaceItemDetailScreen> {
  @override
  void initState() {
    super.initState();
    // Fire-and-forget — a failed view-count bump shouldn't block viewing the item.
    MarketplaceService.instance.incrementViewCount(widget.item.id);
    ActivityService.instance.recordRecentlyViewed(
      itemId: widget.item.id,
      type: 'marketplace',
      title: widget.item.title,
      subtitle: widget.item.price,
      imageUrl: widget.item.photoUrls.isNotEmpty ? widget.item.photoUrls.first : '',
      metadata: {'locationText': widget.item.locationText},
    );
  }

  Future<void> _call() async {
    final uri = Uri(scheme: 'tel', path: widget.item.sellerPhone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _whatsapp() async {
    final digits = widget.item.sellerPhone.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse('https://wa.me/$digits');
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return Scaffold(
      appBar: AppBar(
        title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          StreamBuilder<bool>(
            stream: ActivityService.instance.isSavedStream(itemId: item.id, type: 'marketplace'),
            builder: (context, snapshot) {
              final saved = snapshot.data == true;
              return IconButton(
                tooltip: saved ? 'Remove from saved' : 'Save item',
                icon: Icon(saved ? Icons.favorite : Icons.favorite_border),
                onPressed: () async {
                  if (saved) {
                    await ActivityService.instance.removeSavedItem(itemId: item.id, type: 'marketplace');
                  } else {
                    await ActivityService.instance.saveItem(
                      itemId: item.id,
                      type: 'marketplace',
                      title: item.title,
                      subtitle: item.price,
                      imageUrl: item.photoUrls.isNotEmpty ? item.photoUrls.first : '',
                      metadata: {'locationText': item.locationText},
                    );
                  }
                },
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 260,
              child: item.photoUrls.isEmpty
                  ? Container(
                      color: Colors.green[50],
                      alignment: Alignment.center,
                      child: Icon(Icons.inventory_2_outlined, color: Colors.green[300], size: 60),
                    )
                  : PageView.builder(
                      itemCount: item.photoUrls.length,
                      itemBuilder: (context, index) => Image.network(
                        item.photoUrls[index],
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey[100],
                          alignment: Alignment.center,
                          child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
                        ),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(item.title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
                      ),
                      if (item.isVerified) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.verified, size: 18, color: Colors.blue[600]),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    formatCediPrice(item.price),
                    style: TextStyle(color: Colors.green[800], fontWeight: FontWeight.bold, fontSize: 17),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(item.locationText, style: const TextStyle(fontSize: 13, color: Colors.grey)),
                      const SizedBox(width: 14),
                      const Icon(Icons.visibility_outlined, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text('${item.viewCount} views', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                    ],
                  ),
                  if (item.areaDetail != null && item.areaDetail!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.signpost_outlined, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Expanded(child: Text(item.areaDetail!, style: const TextStyle(fontSize: 13, color: Colors.grey))),
                      ],
                    ),
                  ],
                  if (item.reviewCount > 0) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.star, size: 15, color: Colors.amber),
                        const SizedBox(width: 4),
                        Text('${item.rating.toStringAsFixed(1)} (${item.reviewCount} reviews)',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                  const Divider(height: 32),
                  const Text('Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 8),
                  Text(item.description, style: const TextStyle(fontSize: 14, height: 1.4)),
                  const SizedBox(height: 28),
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
          ],
        ),
      ),
    );
  }
}
