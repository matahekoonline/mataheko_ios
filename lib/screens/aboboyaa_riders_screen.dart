import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/aboboyaa_rider.dart';
import '../services/auth_service.dart';
import 'admin/add_aboboyaa_rider_screen.dart';
import 'aboboyaa_detail_screen.dart';
import 'aboboyaa_rider_mode_screen.dart';

class AboboyaaRidersScreen extends StatefulWidget {
  const AboboyaaRidersScreen({super.key});

  @override
  State<AboboyaaRidersScreen> createState() =>
      _AboboyaaRidersScreenState();
}

class _AboboyaaRidersScreenState extends State<AboboyaaRidersScreen> {
  bool _isAdmin = false;
  bool _loadingAdmin = true;

  @override
  void initState() {
    super.initState();
    _loadAdminStatus();
  }

  Future<void> _loadAdminStatus() async {
    try {
      final uid = AuthService.instance.currentUser?.uid;
      debugPrint('[Aboboyaa] uid: $uid');

      final isAdmin = await AuthService.instance.isAdmin();
      debugPrint('[Aboboyaa] isAdmin resolved to: $isAdmin');

      if (mounted) {
        setState(() {
          _isAdmin = isAdmin;
          _loadingAdmin = false;
        });
      }
    } catch (e) {
      debugPrint('[Aboboyaa] isAdmin() threw: $e');
      if (mounted) {
        setState(() {
          _isAdmin = false;
          _loadingAdmin = false;
        });
      }
    }
  }

  Future<void> _approve(AboboyaaRider rider) async {
    try {
      await AuthService.instance.approveAboboyaaRider(rider.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${rider.riderName} approved successfully.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not approve rider. Please try again.'),
          ),
        );
      }
    }
  }

  Future<void> _openAddRiderScreen() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AddAboboyaaRiderScreen(),
      ),
    );
  }

  Future<void> _openRiderMode() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AboboyaaRiderModeScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Aboboyaa Riders'),
        actions: [
          TextButton.icon(
            onPressed: _openRiderMode,
            icon: const Icon(
              Icons.two_wheeler,
              color: Colors.white,
            ),
            label: const Text(
              'Rider Mode',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),

      // Only admins can add riders manually.
      floatingActionButton: _loadingAdmin
          ? null
          : (_isAdmin
          ? FloatingActionButton.extended(
        onPressed: _openAddRiderScreen,
        icon: const Icon(Icons.add),
        label: const Text('Add Rider'),
        backgroundColor: Colors.green,
      )
          : null),

      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('aboboyaa_riders')
            .snapshots(),

        builder: (context, snapshot) {
          // Loading
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          // Error
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 50,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Error loading Aboboyaa riders.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          // Sort locally so older provider records without createdAt are not
          // silently excluded by a Firestore orderBy query.
          final sortedDocs = [...docs]
            ..sort((a, b) {
              DateTime? toDate(dynamic value) {
                if (value is Timestamp) return value.toDate();
                if (value is DateTime) return value;
                return DateTime.tryParse(value?.toString() ?? '');
              }

              final aDate = toDate(a.data()['createdAt']);
              final bDate = toDate(b.data()['createdAt']);

              if (aDate == null && bDate == null) return 0;
              if (aDate == null) return 1;
              if (bDate == null) return -1;
              return bDate.compareTo(aDate);
            });

          var riders = <AboboyaaRider>[];

          for (final doc in sortedDocs) {
            try {
              riders.add(
                AboboyaaRider.fromMap(
                  doc.id,
                  doc.data(),
                ),
              );
            } catch (e) {
              debugPrint(
                '[AboboyaaRidersScreen] '
                    'Skipping bad rider ${doc.id}: $e',
              );
            }
          }

          // Normal users only see approved riders.
          // Admins see pending riders as well.
          if (!_isAdmin) {
            riders = riders
                .where((rider) => rider.isApproved)
                .toList();
          }

          if (riders.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.two_wheeler,
                    size: 60,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'No Aboboyaa riders available.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: riders.length,
            separatorBuilder: (_, __) =>
            const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final rider = riders[index];

              final hasPhoto = rider.riderPhotoUrl != null &&
                  rider.riderPhotoUrl!.trim().isNotEmpty;

              return Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(10),

                  // Rider photo
                  leading: CircleAvatar(
                    radius: 27,
                    backgroundColor: Colors.green.shade100,
                    backgroundImage: hasPhoto
                        ? NetworkImage(rider.riderPhotoUrl!)
                        : null,
                    child: !hasPhoto
                        ? Icon(
                      Icons.two_wheeler,
                      color: Colors.green.shade800,
                    )
                        : null,
                  ),

                  // Rider name + pending badge
                  title: Row(
                    children: [
                      Flexible(
                        child: Text(
                          rider.riderName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      if (rider.isPending) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Pending',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.orange.shade900,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),

                  subtitle: Text(
                    '${rider.vehicleNumber} · ${rider.stationName}',
                  ),

                  // Admin can approve pending riders.
                  trailing: _isAdmin && rider.isPending
                      ? TextButton(
                    onPressed: () => _approve(rider),
                    child: const Text('Approve'),
                  )
                      : const Icon(
                    Icons.chevron_right,
                  ),

                  // Open rider details
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AboboyaaDetailScreen(
                          rider: rider,
                        ),
                      ),
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