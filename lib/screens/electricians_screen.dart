import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/electrician.dart';
import '../services/auth_service.dart';
import '../widgets/rating_display.dart';
import 'admin/add_electrician_screen.dart';
import 'electrician_detail_screen.dart';

class ElectriciansScreen extends StatefulWidget {
  const ElectriciansScreen({super.key});

  @override
  State<ElectriciansScreen> createState() => _ElectriciansScreenState();
}

class _ElectriciansScreenState extends State<ElectriciansScreen> {
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

  Future<void> _approve(Electrician electrician) async {
    try {
      await AuthService.instance.approveElectrician(electrician.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${electrician.name} approved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not approve electrician. Try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Electricians')),
      floatingActionButton: _isAdmin
          ? FloatingActionButton.extended(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddElectricianScreen()),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Electrician'),
              backgroundColor: Colors.green[700],
            )
          : null,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('electricians')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            // ignore: avoid_print
            print('[ElectriciansScreen] Stream error: ${snapshot.error}');
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Error loading electricians:\n${snapshot.error}', textAlign: TextAlign.center),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];
          var electricians = <Electrician>[];
          for (final d in docs) {
            try {
              electricians.add(Electrician.fromMap(d.id, d.data() as Map<String, dynamic>));
            } catch (e) {
              // ignore: avoid_print
              print('[ElectriciansScreen] Skipping bad electrician doc ${d.id}: $e');
            }
          }

          if (!_isAdmin) {
            electricians = electricians.where((e) => e.isApproved).toList();
          }

          if (electricians.isEmpty) {
            return const Center(child: Text('No electricians added yet.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: electricians.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final e = electricians[index];
              return Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ElectricianDetailScreen(electrician: e)),
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
                          backgroundImage: (e.photoUrl != null && e.photoUrl!.isNotEmpty)
                              ? NetworkImage(e.photoUrl!)
                              : null,
                          child: (e.photoUrl == null || e.photoUrl!.isEmpty)
                              ? Icon(Icons.electrical_services, color: Colors.green[800])
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
                                      e.businessName.isNotEmpty ? e.businessName : e.name,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (e.isPending) ...[
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
                                '${e.stationArea} · ${e.yearsOfExperience} yrs experience',
                                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                              ),
                              const SizedBox(height: 4),
                              if (e.servicesOffered.isNotEmpty)
                                Wrap(
                                  spacing: 4,
                                  runSpacing: 4,
                                  children: e.servicesOffered.take(3).map((s) {
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
                              RatingDisplay(rating: e.rating, reviewCount: e.reviewCount, starSize: 14),
                            ],
                          ),
                        ),
                        if (_isAdmin && e.isPending)
                          TextButton(
                            onPressed: () => _approve(e),
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
