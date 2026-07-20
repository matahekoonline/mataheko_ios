import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/carpenter.dart';
import '../services/auth_service.dart';
import 'admin/add_carpenter_screen.dart';
import 'carpenter_detail_screen.dart';

/// Public directory of carpenters. Shows the approved list to everyone;
/// admins additionally see a "Pending Approval" section at the top with
/// an inline approve button, exactly like MechanicsScreen / PlumbersScreen.
class CarpentersScreen extends StatelessWidget {
  const CarpentersScreen({super.key});

  static final _collection = FirebaseFirestore.instance.collection('carpenters');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Carpenters'), centerTitle: true),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.green[700],
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddCarpenterScreen()),
        ),
        child: const Icon(Icons.add),
      ),
      body: FutureBuilder<bool>(
        future: AuthService.instance.isAdmin(),
        builder: (context, adminSnapshot) {
          final isAdmin = adminSnapshot.data ?? false;
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _collection.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data?.docs ?? [];
              final all = docs.map((d) => Carpenter.fromMap(d.id, d.data())).toList();
              final approved = all.where((c) => c.isApproved).toList();
              final pending = all.where((c) => c.isPending && !c.isApproved).toList();

              if (approved.isEmpty && (!isAdmin || pending.isEmpty)) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No carpenters registered yet.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (isAdmin && pending.isNotEmpty) ...[
                    Text(
                      'Pending Approval',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange[800]),
                    ),
                    const SizedBox(height: 8),
                    ...pending.map((c) => _CarpenterTile(carpenter: c, isAdmin: true)),
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 8),
                  ],
                  if (approved.isNotEmpty)
                    ...approved.map((c) => _CarpenterTile(carpenter: c, isAdmin: isAdmin)),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _CarpenterTile extends StatelessWidget {
  final Carpenter carpenter;
  final bool isAdmin;
  const _CarpenterTile({required this.carpenter, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    final hasImage = carpenter.photoUrl != null && carpenter.photoUrl!.isNotEmpty;
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(10),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => CarpenterDetailScreen(carpenter: carpenter)),
        ),
        leading: CircleAvatar(
          radius: 28,
          backgroundColor: Colors.green[100],
          backgroundImage: hasImage ? NetworkImage(carpenter.photoUrl!) : null,
          child: hasImage
              ? null
              : Icon(Icons.carpenter, color: Colors.green[800]),
        ),
        title: Text(carpenter.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          '${carpenter.workshopName}\n${carpenter.stationArea} • ${carpenter.yearsOfExperience} yrs experience'
              '${!carpenter.isApproved ? '\nPending admin approval' : ''}',
          maxLines: 3,
          style: !carpenter.isApproved ? TextStyle(color: Colors.orange[800]) : null,
        ),
        isThreeLine: true,
        trailing: isAdmin && !carpenter.isApproved
            ? ElevatedButton(
          onPressed: () => AuthService.instance.approveCarpenter(carpenter.id),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green[700],
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
          child: const Text('Approve', style: TextStyle(fontSize: 12)),
        )
            : const Icon(Icons.chevron_right),
      ),
    );
  }
}