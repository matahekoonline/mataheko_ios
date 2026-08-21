import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/motor_mechanic.dart';
import '../services/auth_service.dart';
import '../widgets/rating_display.dart';
import '../widgets/admin/pending_motor_mechanic_approvals_badge.dart';
import 'admin/add_motor_mechanic_screen.dart';
import 'motor_mechanic_detail_screen.dart';

class MotorMechanicsScreen extends StatefulWidget {
  const MotorMechanicsScreen({super.key});

  @override
  State<MotorMechanicsScreen> createState() => _MotorMechanicsScreenState();
}

class _MotorMechanicsScreenState extends State<MotorMechanicsScreen> {
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

  Future<void> _approve(MotorMechanic mechanic) async {
    try {
      await AuthService.instance.approveMotorMechanic(mechanic.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${mechanic.name} approved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not approve motor mechanic. Try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Motor Mechanics'),
        actions: _isAdmin ? const [PendingMotorMechanicApprovalsBadge()] : null,
      ),
      floatingActionButton: _isAdmin
          ? FloatingActionButton.extended(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddMotorMechanicScreen()),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Motor Mechanic'),
              backgroundColor: Colors.green[700],
            )
          : null,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('motorMechanics')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            // ignore: avoid_print
            print('[MotorMechanicsScreen] Stream error: ${snapshot.error}');
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Error loading motor mechanics:\n${snapshot.error}', textAlign: TextAlign.center),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];
          var mechanics = <MotorMechanic>[];
          for (final d in docs) {
            try {
              mechanics.add(MotorMechanic.fromMap(d.id, d.data() as Map<String, dynamic>));
            } catch (e) {
              // ignore: avoid_print
              print('[MotorMechanicsScreen] Skipping bad motor mechanic doc ${d.id}: $e');
            }
          }

          if (!_isAdmin) {
            mechanics = mechanics.where((m) => m.isApproved).toList();
          }

          if (mechanics.isEmpty) {
            return const Center(child: Text('No motor mechanics added yet.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: mechanics.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final m = mechanics[index];
              return Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => MotorMechanicDetailScreen(mechanic: m)),
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
                          backgroundImage: (m.photoUrl != null && m.photoUrl!.isNotEmpty)
                              ? NetworkImage(m.photoUrl!)
                              : null,
                          child: (m.photoUrl == null || m.photoUrl!.isEmpty)
                              ? Icon(Icons.build, color: Colors.green[800])
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
                                      m.workshopName.isNotEmpty ? m.workshopName : m.name,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (m.isPending) ...[
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
                                '${m.stationArea} · ${m.yearsOfExperience} yrs experience',
                                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                              ),
                              const SizedBox(height: 4),
                              if (m.vehicleTypes.isNotEmpty)
                                Wrap(
                                  spacing: 4,
                                  runSpacing: 4,
                                  children: m.vehicleTypes.take(3).map((v) {
                                    return Chip(
                                      label: Text(v, style: const TextStyle(fontSize: 10)),
                                      padding: EdgeInsets.zero,
                                      labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                                      backgroundColor: Colors.green[50],
                                      visualDensity: VisualDensity.compact,
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    );
                                  }).toList(),
                                ),
                              const SizedBox(height: 6),
                              RatingDisplay(rating: m.rating, reviewCount: m.reviewCount, starSize: 14),
                            ],
                          ),
                        ),
                        if (_isAdmin && m.isPending)
                          TextButton(
                            onPressed: () => _approve(m),
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
