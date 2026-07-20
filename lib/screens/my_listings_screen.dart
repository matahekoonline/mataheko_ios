// lib/screens/my_listings_screen.dart
//
// Lets a signed-in seller see every item they've posted, regardless of
// approval status — unlike MarketplaceScreen, which only shows approved
// items. Each card carries a status badge so sellers know why an item
// isn't showing up publicly yet, instead of wondering if it got lost.

import 'package:flutter/material.dart';
import '../models/marketplace_item.dart';
import '../services/marketplace_service.dart';
import 'marketplace_item_detail_screen.dart';

class MyListingsScreen extends StatelessWidget {
  const MyListingsScreen({super.key});

  Future<void> _confirmDelete(BuildContext context, MarketplaceItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete listing?'),
        content: Text('This will permanently remove "${item.title}". This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await MarketplaceService.instance.deleteItem(item.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"${item.title}" deleted')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Listings'), centerTitle: true),
      body: StreamBuilder<List<MarketplaceItem>>(
        stream: MarketplaceService.instance.streamMyItems(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text('Could not load your listings: ${snapshot.error}', textAlign: TextAlign.center),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final items = snapshot.data ?? const [];
          if (items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  "You haven't posted anything yet. Tap \"Sell Item\" on the Marketplace tab to get started.",
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return _MyListingCard(
                item: item,
                onDelete: () => _confirmDelete(context, item),
              );
            },
          );
        },
      ),
    );
  }
}

class _MyListingCard extends StatelessWidget {
  final MarketplaceItem item;
  final VoidCallback onDelete;

  const _MyListingCard({required this.item, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final isApproved = item.isApproved;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => MarketplaceItemDetailScreen(item: item)),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 78,
                  height: 78,
                  child: item.photoUrls.isEmpty
                      ? Container(
                    color: Colors.green[50],
                    alignment: Alignment.center,
                    child: Icon(Icons.inventory_2_outlined, color: Colors.green[300], size: 30),
                  )
                      : Image.network(
                    item.photoUrls.first,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.grey[100],
                      alignment: Alignment.center,
                      child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.price,
                      style: TextStyle(color: Colors.green[800], fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    _StatusBadge(isApproved: isApproved),
                    if (isApproved) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.visibility_outlined, size: 13, color: Colors.grey),
                          const SizedBox(width: 3),
                          Text('${item.viewCount} views', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                onPressed: onDelete,
                tooltip: 'Delete listing',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isApproved;

  const _StatusBadge({required this.isApproved});

  @override
  Widget build(BuildContext context) {
    final color = isApproved ? Colors.green : Colors.orange;
    final label = isApproved ? 'Live' : 'Pending Review';
    final icon = isApproved ? Icons.check_circle : Icons.hourglass_top;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color[50],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color[200]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color[700]),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color[700])),
        ],
      ),
    );
  }
}