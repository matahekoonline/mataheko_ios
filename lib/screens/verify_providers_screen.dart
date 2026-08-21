import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/admin_provider_record.dart';
import '../services/auth_service.dart';
import 'provider_edit_screen.dart';

class VerifyProvidersScreen extends StatefulWidget {
  const VerifyProvidersScreen({super.key});

  @override
  State<VerifyProvidersScreen> createState() => _VerifyProvidersScreenState();
}

class _VerifyProvidersScreenState extends State<VerifyProvidersScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _approveApplication(DocumentSnapshot<Map<String, dynamic>> application) async {
    final data = application.data() ?? {};
    final uid = (data['uid'] ?? application.id).toString();
    final category = (data['category'] ?? data['providerCategory'] ?? '').toString();
    final collection = (data['providerCollection'] ?? '').toString();
    final providerDocId = (data['providerDocId'] ?? uid).toString();
    final name = (data['displayName'] ?? data['fullName'] ?? 'Provider').toString();

    if (collection.isEmpty || providerDocId.isEmpty) {
      _toast('This application has not completed its provider profile yet. Ask the user to finish registration.', good: false);
      return;
    }

    setState(() => _busy = true);
    try {
      await AuthService.instance.setProviderApproved(collection, providerDocId, true);
      await FirebaseFirestore.instance.collection('provider_applications').doc(application.id).set({
        'status': 'approved',
        'reviewedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'role': 'provider',
        'accountType': 'provider',
        'providerCategory': category,
        'providerCategoryName': category,
        'providerStatus': 'approved',
        'verificationStatus': 'verified',
        'providerAvailable': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) _toast('$name is now verified.', good: true);
    } catch (e) {
      if (mounted) _toast('Verification failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openApplication(DocumentSnapshot<Map<String, dynamic>> application) async {
    final data = application.data() ?? {};
    final collection = (data['providerCollection'] ?? '').toString();
    final providerDocId = (data['providerDocId'] ?? '').toString();
    if (collection.isEmpty || providerDocId.isEmpty) {
      _toast('Provider profile is not complete yet.');
      return;
    }

    final snap = await FirebaseFirestore.instance.collection(collection).doc(providerDocId).get();
    if (!snap.exists) {
      _toast('Provider record could not be found.');
      return;
    }

    final record = AdminProviderRecord(
      id: snap.id,
      category: (data['category'] ?? _categoryForCollection(collection) ?? 'Provider').toString(),
      collection: collection,
      data: snap.data() ?? {},
    );

    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ProviderEditScreen(record: record)),
    );
    if (changed == true && mounted) setState(() {});
  }

  void _toast(String text, {bool good = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(backgroundColor: good ? const Color(0xFF166534) : null, content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Provider Verification', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF18212F),
        elevation: 0,
        bottom: TabBar(
          controller: _tabs,
          labelColor: const Color(0xFF166534),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF166534),
          tabs: const [Tab(text: 'New applications'), Tab(text: 'Category review')],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _ApplicationsTab(busy: _busy, onApprove: _approveApplication, onEdit: _openApplication),
          _CategoryReviewTab(onToast: _toast),
        ],
      ),
    );
  }
}

class _ApplicationsTab extends StatelessWidget {
  final bool busy;
  final Future<void> Function(DocumentSnapshot<Map<String, dynamic>>) onApprove;
  final Future<void> Function(DocumentSnapshot<Map<String, dynamic>>) onEdit;

  const _ApplicationsTab({required this.busy, required this.onApprove, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('provider_applications').where('status', isEqualTo: 'pending').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Could not load applications: ${snapshot.error}'));
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Padding(padding: EdgeInsets.all(30), child: Text('No provider applications are waiting for review.', textAlign: TextAlign.center)));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(14),
          itemCount: docs.length,
          itemBuilder: (_, index) {
            final doc = docs[index];
            final d = doc.data();
            final name = (d['displayName'] ?? d['fullName'] ?? 'Provider').toString();
            final category = (d['category'] ?? d['providerCategory'] ?? 'Provider').toString();
            final collection = (d['providerCollection'] ?? '').toString();
            final complete = collection.isNotEmpty && (d['providerDocId'] ?? '').toString().isNotEmpty;
            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: Colors.grey.shade200)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    CircleAvatar(backgroundColor: Colors.green.shade50, child: Icon(Icons.person_outline, color: Colors.green.shade700)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      const SizedBox(height: 3),
                      Text(category, style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w600)),
                    ])),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6), decoration: BoxDecoration(color: complete ? Colors.orange.shade50 : Colors.red.shade50, borderRadius: BorderRadius.circular(20)), child: Text(complete ? 'Pending' : 'Incomplete', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: complete ? Colors.orange.shade800 : Colors.red.shade700))),
                  ]),
                  const SizedBox(height: 12),
                  Text(complete ? 'Provider profile is ready for admin review.' : 'Category selected, but detailed provider registration is not complete.', style: TextStyle(color: Colors.grey.shade700)),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: OutlinedButton.icon(onPressed: () => onEdit(doc), icon: const Icon(Icons.edit_outlined), label: const Text('Review'))),
                    const SizedBox(width: 10),
                    Expanded(child: FilledButton.icon(onPressed: busy || !complete ? null : () => onApprove(doc), icon: const Icon(Icons.verified_rounded), label: const Text('Verify'))),
                  ]),
                ]),
              ),
            );
          },
        );
      },
    );
  }
}

class _CategoryReviewTab extends StatelessWidget {
  final void Function(String) onToast;
  const _CategoryReviewTab({required this.onToast});

  static const categories = <String, String>{
    'Okada': 'okada_riders', 'Aboboyaa': 'aboboyaa_riders', 'Mechanic': 'mechanics', 'Motor Mechanic': 'motor_mechanics',
    'Steel Bender': 'steel_benders', 'Carpenter': 'carpenters', 'Tailor': 'tailors', 'Plumber': 'plumbers', 'Electrician': 'electricians',
    'Mason': 'masons', 'Tiler': 'tilers', 'Welder': 'welders', 'Teacher': 'teachers', 'Home Food': 'home_cooks', 'Hotel': 'hotels',
    'Room for Rent': 'rooms_for_rent', 'Event Planner': 'event_planners', 'Ride Along': 'ride_along',
  };

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: categories.entries.map((entry) => Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 8),
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: entry.value == 'okada_riders' || entry.value == 'aboboyaa_riders'
              ? FirebaseFirestore.instance.collection(entry.value).where('verificationStatus', isEqualTo: 'pending').snapshots()
              : FirebaseFirestore.instance.collection(entry.value).where('isPending', isEqualTo: true).snapshots(),
          builder: (_, snap) {
            final count = snap.data?.docs.length ?? 0;
            return ListTile(
              leading: CircleAvatar(backgroundColor: Colors.green.shade50, child: Icon(Icons.work_outline, color: Colors.green.shade700)),
              title: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('$count pending provider${count == 1 ? '' : 's'}'),
              trailing: count == 0 ? const Icon(Icons.check_circle_outline, color: Colors.green) : Badge(label: Text('$count')),
            );
          },
        ),
      )).toList(),
    );
  }
}

String? _categoryForCollection(String collection) {
  const map = {
    'okada_riders': 'Okada', 'aboboyaa_riders': 'Aboboyaa', 'mechanics': 'Mechanic', 'motor_mechanics': 'Motor Mechanic',
    'steel_benders': 'Steel Bender', 'carpenters': 'Carpenter', 'tailors': 'Tailor', 'plumbers': 'Plumber', 'electricians': 'Electrician',
    'masons': 'Mason', 'tilers': 'Tiler', 'welders': 'Welder', 'teachers': 'Teacher', 'home_cooks': 'Home Food', 'hotels': 'Hotel',
    'rooms_for_rent': 'Room for Rent', 'event_planners': 'Event Planner', 'ride_along': 'Ride Along',
  };
  return map[collection];
}
