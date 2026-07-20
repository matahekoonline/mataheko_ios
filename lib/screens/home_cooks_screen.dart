import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/home_cook.dart';
import '../services/auth_service.dart';
import '../widgets/rating_display.dart';
import 'admin/add_home_cook_screen.dart';
import 'home_cook_detail_screen.dart';

class HomeCooksScreen extends StatefulWidget {
  const HomeCooksScreen({super.key});

  @override
  State<HomeCooksScreen> createState() => _HomeCooksScreenState();
}

class _HomeCooksScreenState extends State<HomeCooksScreen> {
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadAdminStatus();
  }

  Future<void> _loadAdminStatus() async {
    final isAdmin = await AuthService.instance.isAdmin();
    if (mounted) setState(() => _isAdmin = isAdmin);
  }

  Future<void> _approve(HomeCook cook) async {
    try {
      // NOTE: mirrors AuthService.approveTiler — add a matching
      // approveHomeCook(id) method to AuthService if it doesn't exist yet:
      //
      //   Future<void> approveHomeCook(String id) async {
      //     await _db.collection('home_cooks').doc(id).update({
      //       'isApproved': true,
      //       'isPending': false,
      //     });
      //   }
      await AuthService.instance.approveHomeCook(cook.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${cook.name} approved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not approve home cook. Try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home Food Delivery')),
      floatingActionButton: _isAdmin
          ? FloatingActionButton.extended(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddHomeCookScreen()),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Home Cook'),
              backgroundColor: Colors.deepOrange[700],
            )
          : null,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('home_cooks')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            // ignore: avoid_print
            print('[HomeCooksScreen] Stream error: ${snapshot.error}');
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Error loading home cooks:\n${snapshot.error}', textAlign: TextAlign.center),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];
          var cooks = <HomeCook>[];
          for (final d in docs) {
            try {
              cooks.add(HomeCook.fromMap(d.id, d.data() as Map<String, dynamic>));
            } catch (e) {
              // ignore: avoid_print
              print('[HomeCooksScreen] Skipping bad home cook doc ${d.id}: $e');
            }
          }

          if (!_isAdmin) {
            cooks = cooks.where((c) => c.isApproved).toList();
          }

          if (cooks.isEmpty) {
            return const Center(child: Text('No home cooks added yet.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: cooks.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final c = cooks[index];
              return Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => HomeCookDetailScreen(cook: c)),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.deepOrange[100],
                          backgroundImage: (c.photoUrl != null && c.photoUrl!.isNotEmpty)
                              ? NetworkImage(c.photoUrl!)
                              : null,
                          child: (c.photoUrl == null || c.photoUrl!.isEmpty)
                              ? Icon(Icons.restaurant, color: Colors.deepOrange[800])
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      c.businessName.isNotEmpty ? c.businessName : c.name,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (c.isPending) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.orange[100],
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text('Pending',
                                          style: TextStyle(fontSize: 11, color: Colors.orange[900])),
                                    ),
                                  ],
                                  if (!c.offersDelivery) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.blueGrey[50],
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text('Pickup only',
                                          style: TextStyle(fontSize: 10, color: Colors.blueGrey[700])),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${c.stationArea} · ${c.menu.length} dish${c.menu.length == 1 ? '' : 'es'} on menu',
                                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                              ),
                              const SizedBox(height: 4),
                              if (c.cuisineTypes.isNotEmpty)
                                Wrap(
                                  spacing: 4,
                                  runSpacing: 4,
                                  children: c.cuisineTypes.take(3).map((v) {
                                    return Chip(
                                      label: Text(v, style: const TextStyle(fontSize: 10)),
                                      padding: EdgeInsets.zero,
                                      labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                                      backgroundColor: Colors.deepOrange[50],
                                      visualDensity: VisualDensity.compact,
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    );
                                  }).toList(),
                                ),
                              const SizedBox(height: 6),
                              RatingDisplay(rating: c.rating, reviewCount: c.reviewCount, starSize: 14),
                            ],
                          ),
                        ),
                        if (_isAdmin && c.isPending)
                          TextButton(
                            onPressed: () => _approve(c),
                            child: const Text('Approve'),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
