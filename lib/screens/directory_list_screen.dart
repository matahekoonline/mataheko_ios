import 'package:flutter/material.dart';
import '../data/sample_listings.dart';
import '../models/listing.dart';
import 'listing_detail_screen.dart';

class DirectoryListScreen extends StatelessWidget {
  final String? category; // null means show everything

  const DirectoryListScreen({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    final List<Listing> filtered = category == null
        ? sampleListings
        : sampleListings.where((l) => l.category == category).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(category ?? 'All Listings'),
      ),
      body: filtered.isEmpty
          ? const Center(child: Text('No listings yet in this category.'))
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final listing = filtered[index];
                return _ListingCard(listing: listing);
              },
            ),
    );
  }
}

class _ListingCard extends StatelessWidget {
  final Listing listing;
  const _ListingCard({required this.listing});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: CircleAvatar(
          radius: 26,
          backgroundColor: Colors.green[100],
          child: Text(
            listing.name.isNotEmpty ? listing.name[0] : '?',
            style: TextStyle(color: Colors.green[900], fontSize: 20),
          ),
        ),
        title: Text(
          listing.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(listing.description),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.location_on, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(child: Text(listing.locationText, style: const TextStyle(fontSize: 12))),
              ],
            ),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ListingDetailScreen(listing: listing),
            ),
          );
        },
      ),
    );
  }
}
