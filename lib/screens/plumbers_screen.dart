import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/plumber.dart';
import '../services/auth_service.dart';
import '../widgets/rating_display.dart';
import 'admin/add_plumber_screen.dart';
import 'plumber_detail_screen.dart';

class PlumbersScreen extends StatefulWidget {
  const PlumbersScreen({super.key});

  @override
  State<PlumbersScreen> createState() => _PlumbersScreenState();
}

class _PlumbersScreenState extends State<PlumbersScreen> {
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

  Future<void> _approve(Plumber plumber) async {
    try {
      await AuthService.instance.approvePlumber(plumber.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${plumber.name} approved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not approve plumber. Try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Plumbers')),
      floatingActionButton: _isAdmin
          ? FloatingActionButton.extended(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddPlumberScreen()),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Plumber'),
              backgroundColor: Colors.blue[700],
            )
          : null,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('plumbers')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            // ignore: avoid_print
            print('[PlumbersScreen] Stream error: ${snapshot.error}');
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Error loading plumbers:\n${snapshot.error}', textAlign: TextAlign.center),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];
          var plumbers = <Plumber>[];
          for (final d in docs) {
            try {
              plumbers.add(Plumber.fromMap(d.id, d.data() as Map<String, dynamic>));
            } catch (e) {
              // ignore: avoid_print
              print('[PlumbersScreen] Skipping bad plumber doc ${d.id}: $e');
            }
          }

          // Public users only ever see approved plumbers. Admins see
          // everything (including pending) so they can review and approve.
          if (!_isAdmin) {
            plumbers = plumbers.where((p) => p.isApproved).toList();
          }

          if (plumbers.isEmpty) {
            return const Center(child: Text('No plumbers added yet.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: plumbers.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final p = plumbers[index];
              return Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => PlumberDetailScreen(plumber: p)),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.green[100],
                          backgroundImage: (p.photoUrl != null && p.photoUrl!.isNotEmpty)
                              ? NetworkImage(p.photoUrl!)
                              : null,
                          child: (p.photoUrl == null || p.photoUrl!.isEmpty)
                              ? Icon(Icons.plumbing, color: Colors.green[800])
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
                                      p.businessName.isNotEmpty ? p.businessName : p.name,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (p.isPending) ...[
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
                                '${p.stationArea} · ${p.yearsOfExperience} yrs experience',
                                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                              ),
                              const SizedBox(height: 4),
                              if (p.servicesOffered.isNotEmpty)
                                Wrap(
                                  spacing: 4,
                                  runSpacing: 4,
                                  children: p.servicesOffered.take(3).map((s) {
                                    return Chip(
                                      label: Text(s, style: const TextStyle(fontSize: 10)),
                                      padding: EdgeInsets.zero,
                                      labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                                      backgroundColor: Colors.green[50],
                                      visualDensity: VisualDensity.compact,
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    );
                                  }).toList(),
                                ),
                              const SizedBox(height: 6),
                              RatingDisplay(rating: p.rating, reviewCount: p.reviewCount, starSize: 14),
                            ],
                          ),
                        ),
                        if (_isAdmin && p.isPending)
                          TextButton(
                            onPressed: () => _approve(p),
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
