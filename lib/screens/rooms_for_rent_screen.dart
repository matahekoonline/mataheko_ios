import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/room_for_rent.dart';
import 'room_for_rent_detail_screen.dart';
import 'admin/add_room_for_rent_screen.dart';

/// Public list of approved, available rooms for rent. Mirrors the
/// structure of TilersScreen/HotelsScreen — a simple approved-only
/// StreamBuilder list with a floating "+" for admins to add a listing
/// directly (landlord self-registration happens via BioDataScreen).
class RoomsForRentScreen extends StatelessWidget {
  const RoomsForRentScreen({super.key});

  static const _palmGreen = Color(0xFF1F6F4A);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rooms for Rent'),
        backgroundColor: _palmGreen,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _palmGreen,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddRoomForRentScreen()),
          );
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('rooms_for_rent')
            .where('isApproved', isEqualTo: true)
            .where('isAvailable', isEqualTo: true)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            // Firestore often needs a composite index for this combination
            // of where() + orderBy(). Check terminal/Logcat for a link to
            // auto-create it if this fires the first time this screen runs.
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Could not load rooms. If this is the first run, Firestore may need '
                  'a composite index — check your terminal/Logcat for a link to create it.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('No rooms available right now.'));
          }

          final rooms = docs
              .map((doc) => RoomForRent.fromMap(doc.id, doc.data()))
              .toList();

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: rooms.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final room = rooms[index];
              return _RoomCard(room: room);
            },
          );
        },
      ),
    );
  }
}

class _RoomCard extends StatelessWidget {
  final RoomForRent room;
  const _RoomCard({required this.room});

  static const _palmGreen = Color(0xFF1F6F4A);

  @override
  Widget build(BuildContext context) {
    final firstPhoto = room.photoUrls.isNotEmpty ? room.photoUrls.first : null;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => RoomForRentDetailScreen(room: room)),
          );
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              height: 110,
              child: firstPhoto == null
                  ? Container(
                      color: _palmGreen.withOpacity(0.1),
                      child: Icon(Icons.home_outlined, color: _palmGreen, size: 32),
                    )
                  : Image.network(
                      firstPhoto,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: _palmGreen.withOpacity(0.1),
                        child: Icon(Icons.home_outlined, color: _palmGreen, size: 32),
                      ),
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          color: _palmGreen.withOpacity(0.05),
                          child: const Center(
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      room.propertyTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      room.roomType,
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 12, color: Colors.grey),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            room.stationArea,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'GHS ${room.price.toStringAsFixed(0)} / ${room.rentPeriod}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: _palmGreen,
                      ),
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
