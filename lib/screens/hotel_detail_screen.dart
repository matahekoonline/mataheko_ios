import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/hotel.dart';
import '../widgets/rating_display.dart';

/// Shows everything someone would want to check before calling to book:
/// photos, price range, room types, amenities, check-in/out times, and
/// whether walk-ins are accepted -- so the phone call is just to confirm
/// availability, not to ask twenty questions first.
class HotelDetailScreen extends StatefulWidget {
  final Hotel hotel;
  const HotelDetailScreen({super.key, required this.hotel});

  @override
  State<HotelDetailScreen> createState() => _HotelDetailScreenState();
}

class _HotelDetailScreenState extends State<HotelDetailScreen> {
  final _pageController = PageController();
  int _currentPhoto = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _copyPhoneNumber(BuildContext context) async {
    final hotel = widget.hotel;
    await Clipboard.setData(ClipboardData(text: hotel.phoneNumber));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${hotel.phoneNumber} copied — dial to call')),
    );
    // NOTE: one-tap dialing needs the url_launcher package, which isn't in
    // pubspec.yaml yet (see the TODO for banner URLs in home_screen.dart).
    // Once it's added, swap this for:
    //   launchUrl(Uri(scheme: 'tel', path: hotel.phoneNumber));
  }

  @override
  Widget build(BuildContext context) {
    final hotel = widget.hotel;
    final photos = hotel.photoUrls;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: photos.isEmpty
                  ? Container(
                      color: Colors.indigo[50],
                      child: Icon(Icons.hotel, size: 64, color: Colors.indigo[200]),
                    )
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        PageView.builder(
                          controller: _pageController,
                          itemCount: photos.length,
                          onPageChanged: (i) => setState(() => _currentPhoto = i),
                          itemBuilder: (context, i) {
                            return Image.network(
                              photos[i],
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: Colors.indigo[50],
                                child: Icon(Icons.broken_image_outlined, color: Colors.indigo[200]),
                              ),
                            );
                          },
                        ),
                        if (photos.length > 1)
                          Positioned(
                            bottom: 12,
                            left: 0,
                            right: 0,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(photos.length, (i) {
                                final active = i == _currentPhoto;
                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  margin: const EdgeInsets.symmetric(horizontal: 3),
                                  width: active ? 18 : 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: active ? Colors.white : Colors.white.withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                );
                              }),
                            ),
                          ),
                      ],
                    ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          hotel.businessName.isNotEmpty ? hotel.businessName : hotel.name,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                        ),
                      ),
                      if (hotel.isPending)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.orange[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text('Pending', style: TextStyle(fontSize: 11, color: Colors.orange[900])),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 15, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(child: Text(hotel.stationArea, style: TextStyle(color: Colors.grey[700]))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  RatingDisplay(rating: hotel.rating, reviewCount: hotel.reviewCount, starSize: 16),

                  const SizedBox(height: 20),
                  _InfoCard(
                    icon: Icons.payments_outlined,
                    title: hotel.priceRangeLabel,
                    subtitle: 'Price per night',
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _InfoCard(
                          icon: Icons.login,
                          title: hotel.checkInTime.isEmpty ? 'Not set' : hotel.checkInTime,
                          subtitle: 'Check-in',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _InfoCard(
                          icon: Icons.logout,
                          title: hotel.checkOutTime.isEmpty ? 'Not set' : hotel.checkOutTime,
                          subtitle: 'Check-out',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _InfoCard(
                    icon: Icons.meeting_room_outlined,
                    title: '${hotel.numberOfRooms} room${hotel.numberOfRooms == 1 ? '' : 's'}',
                    subtitle: hotel.acceptsWalkIns
                        ? 'Walk-ins accepted — no booking required'
                        : 'Booking ahead recommended',
                  ),

                  if (hotel.roomTypes.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Text('Room Types', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: hotel.roomTypes
                          .map((v) => Chip(label: Text(v), backgroundColor: Colors.indigo[50]))
                          .toList(),
                    ),
                  ],

                  if (hotel.amenities.isNotEmpty || hotel.offersFreeBreakfast || hotel.offersAirportPickup) ...[
                    const SizedBox(height: 24),
                    const Text('Amenities', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (hotel.offersFreeBreakfast)
                          Chip(
                            avatar: const Icon(Icons.free_breakfast, size: 16),
                            label: const Text('Free Breakfast'),
                            backgroundColor: Colors.green[50],
                          ),
                        if (hotel.offersAirportPickup)
                          Chip(
                            avatar: const Icon(Icons.airport_shuttle, size: 16),
                            label: const Text('Airport Pickup'),
                            backgroundColor: Colors.green[50],
                          ),
                        ...hotel.amenities.map((v) => Chip(label: Text(v))),
                      ],
                    ),
                  ],

                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _copyPhoneNumber(context),
                      icon: const Icon(Icons.call),
                      label: Text('Call ${hotel.phoneNumber}'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo[700],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _InfoCard({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.indigo[700], size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
