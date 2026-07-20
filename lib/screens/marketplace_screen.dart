import 'package:flutter/material.dart';
import '../models/marketplace_item.dart';
import '../services/marketplace_service.dart';
import '../utils/auth_helper.dart';
import 'account_screen.dart';
import 'post_marketplace_item_screen.dart';
import 'marketplace_item_detail_screen.dart';

/// Formats a seller-entered price string with the Ghana cedi symbol.
/// - "GHS 65 / bag" -> "₵65 / bag" (swaps GHS for ₵, no duplicate symbol)
/// - "65" or "800"  -> "₵65" / "₵800" (prepends ₵)
/// - "Negotiable" or any non-numeric text -> left as-is (no ₵ prepended
///   to text that isn't actually a price)
String formatCediPrice(String price) {
  final trimmed = price.trim();
  if (trimmed.isEmpty) return trimmed;

  // Already has GHS -> swap it for ₵ instead of stacking both symbols.
  final ghsMatch = RegExp(r'^GHS\s*', caseSensitive: false);
  if (ghsMatch.hasMatch(trimmed)) {
    return '₵${trimmed.replaceFirst(ghsMatch, '')}';
  }

  // Already has ₵ -> leave it alone.
  if (trimmed.startsWith('₵')) return trimmed;

  // Starts with a digit -> it's a number/range, prepend ₵.
  if (RegExp(r'^\d').hasMatch(trimmed)) return '₵$trimmed';

  // Anything else (e.g. "Negotiable", "Call for price") -> leave as-is.
  return trimmed;
}

class MarketplaceScreen extends StatelessWidget {
  const MarketplaceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Marketplace'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AccountScreen()),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final loggedIn = await requireLogin(context, actionLabel: 'post an item for sale');
          if (!loggedIn || !context.mounted) return;

          final posted = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const PostMarketplaceItemScreen()),
          );
          if (posted == true && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Item posted! It will appear once an admin approves it.')),
            );
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Sell Item'),
        backgroundColor: Colors.green[700],
      ),
      body: StreamBuilder<List<MarketplaceItem>>(
        stream: MarketplaceService.instance.streamItems(),
        builder: (context, snapshot) {
          // TEMP DEBUG — remove once the visibility bug is confirmed fixed.
          debugPrint(
            'MARKETPLACE DEBUG: state=${snapshot.connectionState}, '
                'count=${snapshot.data?.length}, error=${snapshot.error}',
          );

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text('Could not load the marketplace: ${snapshot.error}', textAlign: TextAlign.center),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final items = snapshot.data ?? const [];
          if (items.isEmpty) {
            return const Center(child: Text('No items posted yet. Be the first!'));
          }

          return GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.72,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return _MarketplaceCard(item: item);
            },
          );
        },
      ),
    );
  }
}

class _MarketplaceCard extends StatelessWidget {
  final MarketplaceItem item;

  const _MarketplaceCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => MarketplaceItemDetailScreen(item: item)),
          );
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Full-bleed photo fills the whole card.
            item.photoUrls.isEmpty
                ? Container(
              color: Colors.green[50],
              alignment: Alignment.center,
              child: Icon(Icons.inventory_2_outlined, color: Colors.green[300], size: 48),
            )
                : Image.network(
              item.photoUrls.first,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: Colors.green[50],
                alignment: Alignment.center,
                child: Icon(Icons.inventory_2_outlined, color: Colors.green[300], size: 48),
              ),
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return Container(
                  color: Colors.green[50],
                  alignment: Alignment.center,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                );
              },
            ),

            // Verified badge, top-left.
            if (item.isVerified)
              Positioned(
                left: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: Icon(Icons.verified, size: 16, color: Colors.blue[600]),
                ),
              ),

            // Photo-count badge, top-right.
            if (item.photoUrls.length > 1)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.photo_camera, size: 11, color: Colors.white),
                      const SizedBox(width: 3),
                      Text('${item.photoUrls.length}', style: const TextStyle(color: Colors.white, fontSize: 10)),
                    ],
                  ),
                ),
              ),

            // Bottom gradient + name, price, rating.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 24, 10, 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black.withValues(alpha: 0.0), Colors.black.withValues(alpha: 0.75)],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            formatCediPrice(item.price),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        if (item.reviewCount > 0) ...[
                          const Icon(Icons.star, size: 13, color: Colors.amber),
                          const SizedBox(width: 2),
                          Text(
                            item.rating.toStringAsFixed(1),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}