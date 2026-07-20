import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/tiler.dart';
import '../services/auth_service.dart';
import '../widgets/rating_display.dart';
import 'admin/add_tiler_screen.dart';
import 'tiler_detail_screen.dart';

class TilersScreen extends StatefulWidget {
  const TilersScreen({super.key});

  @override
  State<TilersScreen> createState() => _TilersScreenState();
}

class _TilersScreenState extends State<TilersScreen> {
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

  Future<void> _approve(Tiler tiler) async {
    try {
      // NOTE: mirrors AuthService.approveTailor — add a matching
      // approveTiler(id) method to AuthService if it doesn't exist yet:
      //
      //   Future<void> approveTiler(String id) async {
      //     await _db.collection('tilers').doc(id).update({
      //       'isApproved': true,
      //       'isPending': false,
      //     });
      //   }
      await AuthService.instance.approveTiler(tiler.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${tiler.name} approved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not approve tiler. Try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tilers')),
      floatingActionButton: _isAdmin
          ? FloatingActionButton.extended(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddTilerScreen()),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Tiler'),
              backgroundColor: Colors.teal[700],
            )
          : null,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('tilers')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            // ignore: avoid_print
            print('[TilersScreen] Stream error: ${snapshot.error}');
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Error loading tilers:\n${snapshot.error}', textAlign: TextAlign.center),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];
          var tilers = <Tiler>[];
          for (final d in docs) {
            try {
              tilers.add(Tiler.fromMap(d.id, d.data() as Map<String, dynamic>));
            } catch (e) {
              // ignore: avoid_print
              print('[TilersScreen] Skipping bad tiler doc ${d.id}: $e');
            }
          }

          if (!_isAdmin) {
            tilers = tilers.where((t) => t.isApproved).toList();
          }

          if (tilers.isEmpty) {
            return const Center(child: Text('No tilers added yet.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: tilers.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final t = tilers[index];
              return Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => TilerDetailScreen(tiler: t)),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.teal[100],
                          backgroundImage: (t.photoUrl != null && t.photoUrl!.isNotEmpty)
                              ? NetworkImage(t.photoUrl!)
                              : null,
                          child: (t.photoUrl == null || t.photoUrl!.isEmpty)
                              ? Icon(Icons.grid_on, color: Colors.teal[800])
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
                                      t.businessName.isNotEmpty ? t.businessName : t.name,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (t.isPending) ...[
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
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${t.stationArea} · ${t.yearsOfExperience} yrs experience',
                                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                              ),
                              const SizedBox(height: 4),
                              if (t.specialtiesServiced.isNotEmpty)
                                Wrap(
                                  spacing: 4,
                                  runSpacing: 4,
                                  children: t.specialtiesServiced.take(3).map((v) {
                                    return Chip(
                                      label: Text(v, style: const TextStyle(fontSize: 10)),
                                      padding: EdgeInsets.zero,
                                      labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                                      backgroundColor: Colors.teal[50],
                                      visualDensity: VisualDensity.compact,
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    );
                                  }).toList(),
                                ),
                              const SizedBox(height: 6),
                              RatingDisplay(rating: t.rating, reviewCount: t.reviewCount, starSize: 14),
                            ],
                          ),
                        ),
                        if (_isAdmin && t.isPending)
                          TextButton(
                            onPressed: () => _approve(t),
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
