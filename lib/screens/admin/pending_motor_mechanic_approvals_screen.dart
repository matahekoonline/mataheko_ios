import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../models/motor_mechanic.dart';
import '../../services/auth_service.dart';

/// Admin-only screen listing motor mechanics awaiting approval.
/// Reached via the PendingMotorMechanicApprovalsBadge bell icon.
class PendingMotorMechanicApprovalsScreen extends StatelessWidget {
  const PendingMotorMechanicApprovalsScreen({super.key});

  Future<void> _confirmReject(BuildContext context, MotorMechanic m) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Reject ${m.name}?'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            labelText: 'Reason (optional)',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Reject', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await AuthService.instance.rejectMotorMechanic(m.id, reason: reasonController.text.trim());
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${m.name} rejected')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pending Motor Mechanic Approvals')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('motorMechanics')
            .where('isPending', isEqualTo: true)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error loading requests:\n${snapshot.error}'));
          }

          final docs = snapshot.data?.docs ?? [];
          final mechanics = <MotorMechanic>[];
          for (final d in docs) {
            try {
              mechanics.add(MotorMechanic.fromMap(d.id, d.data() as Map<String, dynamic>));
            } catch (_) {
              // skip malformed doc
            }
          }

          if (mechanics.isEmpty) {
            return const Center(child: Text('No pending requests. All caught up!'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: mechanics.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final m = mechanics[index];
              return Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m.workshopName.isNotEmpty ? m.workshopName : m.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 2),
                      Text('${m.name} · ${m.stationArea}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                      const SizedBox(height: 2),
                      Text('${m.yearsOfExperience} yrs experience · ${m.phoneNumber}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _confirmReject(context, m),
                              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                              child: const Text('Reject'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                await AuthService.instance.approveMotorMechanic(m.id);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('${m.name} approved')),
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700]),
                              child: const Text('Approve'),
                            ),
                          ),
                        ],
                      ),
                    ],
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
