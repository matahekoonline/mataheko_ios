import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/room_for_rent.dart';
import '../widgets/provider_reviews_section.dart';

/// Full details for one room-for-rent listing. Mirrors the pattern of
/// other provider detail screens (e.g. RiderDetailScreen) — a photo
/// carousel-ish header (simple PageView), then property details, then a
/// "Call Landlord" button using url_launcher (already in pubspec.yaml).
class RoomForRentDetailScreen extends StatelessWidget {
  final RoomForRent room;
  const RoomForRentDetailScreen({super.key, required this.room});

  static const _palmGreen = Color(0xFF1F6F4A);

  Future<void> _callLandlord(BuildContext context) async {
    final uri = Uri(scheme: 'tel', path: room.phoneNumber);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the phone dialer.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            backgroundColor: _palmGreen,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: room.photoUrls.isEmpty
                  ? Container(
                      color: _palmGreen.withOpacity(0.15),
                      child: Icon(Icons.home_outlined, color: _palmGreen, size: 56),
                    )
                  : PageView(
                      children: room.photoUrls
                          .map(
                            (url) => Image.network(
                              url,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: _palmGreen.withOpacity(0.15),
                                child: Icon(Icons.broken_image_outlined, color: _palmGreen, size: 40),
                              ),
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return Container(
                                  color: _palmGreen.withOpacity(0.08),
                                  child: const Center(child: CircularProgressIndicator()),
                                );
                              },
                            ),
                          )
                          .toList(),
                    ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    room.propertyTitle,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(room.stationArea, style: TextStyle(color: Colors.grey[700])),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: _palmGreen.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'GHS ${room.price.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: _palmGreen,
                          ),
                        ),
                        Text(
                          '/ ${room.rentPeriod}',
                          style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text('Room Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 6),
                  Chip(label: Text(room.roomType)),

                  if (room.amenities.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    const Text('Amenities', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: room.amenities
                          .map((a) => Chip(
                                label: Text(a, style: const TextStyle(fontSize: 12)),
                                backgroundColor: _palmGreen.withOpacity(0.08),
                              ))
                          .toList(),
                    ),
                  ],

                  if (room.description.trim().isNotEmpty) ...[
                    const SizedBox(height: 18),
                    const Text('Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 6),
                    Text(room.description, style: TextStyle(color: Colors.grey[800], height: 1.4)),
                  ],

                  const SizedBox(height: 18),
                  ProviderReviewsSection(collection: 'rooms_for_rent', providerId: room.id),

                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: _palmGreen.withOpacity(0.12),
                        child: Text(
                          room.landlordName.isNotEmpty ? room.landlordName[0] : '?',
                          style: const TextStyle(color: _palmGreen, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(room.landlordName, style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text('Landlord', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _callLandlord(context),
                      icon: const Icon(Icons.call),
                      label: const Text('Call Landlord'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _palmGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
