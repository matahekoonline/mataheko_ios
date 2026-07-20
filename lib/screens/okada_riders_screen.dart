import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/okada_rider.dart';
import '../services/auth_service.dart';
import 'admin/add_okada_rider_screen.dart';
import 'rider_detail_screen.dart';
import 'rider_mode_screen.dart';

class OkadaRidersScreen extends StatefulWidget {
  const OkadaRidersScreen({super.key});

  @override
  State<OkadaRidersScreen> createState() => _OkadaRidersScreenState();
}

class _OkadaRidersScreenState extends State<OkadaRidersScreen> {
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

  Future<void> _approve(OkadaRider rider) async {
    try {
      await AuthService.instance.approveOkadaRider(rider.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${rider.riderName} approved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not approve rider. Try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Okada Riders'),
        actions: [
          // Entry point for a rider to go online and share their live
          // location. Anyone can tap this — identity is confirmed inside
          // RiderModeScreen via their signed-in Firebase account.
          TextButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RiderModeScreen()),
              );
            },
            icon: const Icon(Icons.two_wheeler, color: Colors.white),
            label: const Text('Rider Mode', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      floatingActionButton: _isAdmin
          ? FloatingActionButton.extended(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddOkadaRiderScreen()),
                );
                // StreamBuilder below updates automatically — no manual refresh needed
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Rider'),
              backgroundColor: Colors.green[700],
            )
          : null,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('okada_riders')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            // Firestore security-rule denials and missing-index errors both
            // land here. Printing the raw error is the fastest way to tell
            // them apart (a missing-index error contains a console link).
            // ignore: avoid_print
            print('[OkadaRidersScreen] Stream error: ${snapshot.error}');
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Error loading riders:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final docs = snapshot.data?.docs ?? [];

          var riders = <OkadaRider>[];
          for (final d in docs) {
            try {
              riders.add(
                OkadaRider.fromMap(d.id, d.data() as Map<String, dynamic>),
              );
            } catch (e) {
              // A malformed doc shouldn't take down the whole list — skip
              // it and log which doc failed so it can be fixed in Firestore.
              // ignore: avoid_print
              print('[OkadaRidersScreen] Skipping bad rider doc ${d.id}: $e');
            }
          }

          // Non-admins only ever see approved riders. Admins see everyone
          // so they can review and approve pending self-registrations.
          if (!_isAdmin) {
            riders = riders.where((r) => r.isApproved).toList();
          }

          if (riders.isEmpty) {
            return const Center(child: Text('No riders added yet.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: riders.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final rider = riders[index];
              return Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(10),
                  leading: CircleAvatar(
                    radius: 26,
                    backgroundColor: Colors.green[100],
                    backgroundImage: (rider.riderPhotoUrl != null && rider.riderPhotoUrl!.isNotEmpty)
                        ? NetworkImage(rider.riderPhotoUrl!)
                        : null,
                    onBackgroundImageError: (rider.riderPhotoUrl != null && rider.riderPhotoUrl!.isNotEmpty)
                        ? (e, stack) {
                            // ignore: avoid_print
                            print('[OkadaRidersScreen] Bad photo URL for '
                                '${rider.riderName}: ${rider.riderPhotoUrl} — $e');
                          }
                        : null,
                    child: (rider.riderPhotoUrl == null || rider.riderPhotoUrl!.isEmpty)
                        ? Icon(Icons.two_wheeler, color: Colors.green[800])
                        : null,
                  ),
                  title: Row(
                    children: [
                      Flexible(
                        child: Text(rider.riderName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (rider.isPending) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Pending',
                            style: TextStyle(fontSize: 11, color: Colors.orange[900]),
                          ),
                        ),
                      ],
                    ],
                  ),
                  subtitle: Text('${rider.numberPlate} · ${rider.stationName}'),
                  trailing: (_isAdmin && rider.isPending)
                      ? TextButton(
                          onPressed: () => _approve(rider),
                          child: const Text('Approve'),
                        )
                      : const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => RiderDetailScreen(rider: rider)),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
