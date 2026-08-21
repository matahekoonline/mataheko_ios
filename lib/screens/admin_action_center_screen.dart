import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminActionCenterScreen extends StatelessWidget {
  const AdminActionCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          title: const Text('Admin Action Center'),
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF18212F),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.notifications_outlined), text: 'Notifications'),
              Tab(icon: Icon(Icons.delete_outline), text: 'Delete requests'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _AdminNotificationsTab(),
            _DeleteRequestsTab(),
          ],
        ),
      ),
    );
  }
}

class _AdminNotificationsTab extends StatelessWidget {
  const _AdminNotificationsTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('admin_notifications')
          .orderBy('createdAt', descending: true)
          .limit(100)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Could not load notifications: ${snapshot.error}'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text('No admin notifications yet.'));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(14),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();
            final read = data['read'] == true;
            final title = data['title']?.toString() ?? 'Mataheko action';
            final body = data['body']?.toString() ?? '';
            final category = data['category']?.toString() ?? 'admin';
            final created = data['createdAt'];

            return Card(
              elevation: 0,
              color: read ? Colors.white : Colors.orange.shade50,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: read ? Colors.blue.shade50 : Colors.orange.shade100,
                  child: Icon(
                    read ? Icons.notifications_none : Icons.notifications_active,
                    color: read ? Colors.blue.shade700 : Colors.orange.shade800,
                  ),
                ),
                title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('$body\nCategory: $category\n${_time(created)}'),
                ),
                isThreeLine: true,
                trailing: read
                    ? null
                    : const Icon(Icons.circle, size: 10, color: Colors.red),
                onTap: () async {
                  await doc.reference.set({
                    'read': true,
                    'readAt': FieldValue.serverTimestamp(),
                  }, SetOptions(merge: true));
                },
              ),
            );
          },
        );
      },
    );
  }
}

class _DeleteRequestsTab extends StatelessWidget {
  const _DeleteRequestsTab();

  Future<void> _setStatus(
    BuildContext context,
    DocumentSnapshot<Map<String, dynamic>> doc,
    String status,
  ) async {
    try {
      await doc.reference.set({
        'status': status,
        'reviewedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Request marked $status.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update request: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('account_deletion_requests')
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Could not load deletion requests: ${snapshot.error}'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text('No pending account deletion requests.'));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(14),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();
            final name = data['displayName']?.toString() ?? 'User';
            final email = data['email']?.toString() ?? '';
            final uid = data['uid']?.toString() ?? doc.id;

            return Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const CircleAvatar(child: Icon(Icons.person_outline)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: const TextStyle(fontWeight: FontWeight.w800)),
                              if (email.isNotEmpty) Text(email, style: TextStyle(color: Colors.grey.shade700)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text('User ID: $uid', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _setStatus(context, doc, 'rejected'),
                            child: const Text('Reject'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => _setStatus(context, doc, 'approved'),
                            child: const Text('Approve'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Approval records the request for deletion. Actual Firebase Authentication deletion requires a trusted backend/Admin SDK.',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

String _time(dynamic value) {
  if (value is Timestamp) return value.toDate().toLocal().toString();
  return '';
}
