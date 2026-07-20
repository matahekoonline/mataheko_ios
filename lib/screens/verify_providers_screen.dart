import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class VerifyProvidersScreen extends StatelessWidget {
  const VerifyProvidersScreen({super.key});

  Future<void> _setStatus(String uid, String status, String? category) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).set(
      {'verificationStatus': status},
      SetOptions(merge: true),
    );

    // The users doc's verificationStatus only drives this admin screen's
    // own query. Each provider category has its OWN doc (okada_riders/
    // mechanics/steel_benders/electricians/tailors/plumbers) with its OWN
    // isApproved/isPending flags, and those are what the public list
    // screens actually filter on — so without this, tapping "Verify" here
    // never makes anyone show up in OkadaRidersScreen / MechanicsScreen /
    // SteelBendersScreen / ElectriciansScreen / TailorsScreen / PlumbersScreen.
    if (status == 'verified') {
      switch (category) {
        case 'Okada':
          await AuthService.instance.approveOkadaRider(uid);
          break;
        case 'Mechanic':
          await AuthService.instance.approveMechanic(uid);
          break;
        case 'Steel Bender':
          await AuthService.instance.approveSteelBender(uid);
          break;
        case 'Electrician':
          await AuthService.instance.approveElectrician(uid);
          break;
        case 'Tailor':
          await AuthService.instance.approveTailor(uid);
          break;
        case 'Plumber':
          await AuthService.instance.approvePlumber(uid);
          break;
        case 'Teacher':
          await AuthService.instance.approveTeacher(uid);
          break;
        case 'Tiler':
          await AuthService.instance.approveTiler(uid);
          break;
      }
    }
  }

  void _viewFullPhoto(BuildContext context, String url, String label) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: Text(label),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            InteractiveViewer(
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Could not load photo.'),
                ),
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Maps a provider category to the Firestore collection holding its
  /// category-specific doc (and public-facing photo). Returns null for
  /// categories that only have a plain users doc with no dedicated
  /// collection.
  String? _providerCollectionFor(String? category) {
    switch (category) {
      case 'Okada':
        return 'okada_riders';
      case 'Mechanic':
        return 'mechanics';
      case 'Steel Bender':
        return 'steel_benders';
      case 'Electrician':
        return 'electricians';
      case 'Tailor':
        return 'tailors';
      case 'Plumber':
        return 'plumbers';
      case 'Teacher':
        return 'teachers';
      case 'Tiler':
        return 'tilers';
      default:
        return null;
    }
  }

  String _providerPhotoLabelFor(String? category) {
    switch (category) {
      case 'Okada':
        return 'Rider Photo';
      case 'Mechanic':
        return 'Mechanic Photo';
      case 'Steel Bender':
        return 'Steel Bender Photo';
      case 'Electrician':
        return 'Electrician Photo';
      case 'Tailor':
        return 'Tailor Photo';
      case 'Plumber':
        return 'Plumber Photo';
      case 'Teacher':
        return 'Teacher Photo';
      case 'Tiler':
        return 'Tiler Photo';
      default:
        return 'Provider Photo';
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Verify Providers'),
          centerTitle: true,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'New Signups'),
              Tab(text: 'Category Approvals'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildPendingUsersList(context),
            _CategoryApprovalsTab(
              providerCollectionFor: _providerCollectionFor,
              providerPhotoLabelFor: _providerPhotoLabelFor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingUsersList(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'provider')
          .where('verificationStatus', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          // Firestore often needs a composite index for two where() clauses.
          // If this fires, check Logcat/console for a link Firestore gives
          // you to auto-create the index, click it, wait a minute, retry.
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Could not load providers. If this is the first time running this screen, '
                    'Firestore may need a composite index — check your terminal/Logcat for a link to create it.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text('No pending providers to review.'));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();
            final uid = doc.id;
            final ghanaCardPhotoUrl = data['ghanaCardPhotoUrl'] as String?;
            final category = data['category'] as String?;

            return Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['fullName'] as String? ?? '(no name)',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text('Phone: ${data['phoneNumber'] ?? '-'}'),
                    Text('Area: ${data['area'] ?? '-'}'),
                    if (category != null) Text('Category: $category'),
                    Text('Ghana Card No: ${data['ghanaCardNumber'] ?? '-'}'),
                    const SizedBox(height: 12),

                    // Ghana Card photo — this is the whole point of the
                    // review, so show it inline (not just the number) and
                    // let the admin tap to inspect it full-screen before
                    // approving.
                    Text(
                      'Ghana Card Photo',
                      style: TextStyle(fontSize: 12, color: Colors.grey[700], fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    if (ghanaCardPhotoUrl == null || ghanaCardPhotoUrl.isEmpty)
                      Container(
                        height: 140,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'No photo uploaded',
                          style: TextStyle(color: Colors.grey[500], fontSize: 12),
                        ),
                      )
                    else
                      GestureDetector(
                        onTap: () => _viewFullPhoto(context, ghanaCardPhotoUrl, '${data['fullName'] ?? 'Provider'} — Ghana Card'),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            ghanaCardPhotoUrl,
                            height: 140,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              height: 140,
                              color: Colors.red[50],
                              alignment: Alignment.center,
                              child: Text(
                                'Could not load photo',
                                style: TextStyle(color: Colors.red[300], fontSize: 12),
                              ),
                            ),
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return Container(
                                height: 140,
                                alignment: Alignment.center,
                                child: const CircularProgressIndicator(strokeWidth: 2),
                              );
                            },
                          ),
                        ),
                      ),

                    const SizedBox(height: 12),

                    // Category-specific provider photo — lives in its own
                    // {category}_doc/{uid} record (created by
                    // registerAsOkadaRider / registerAsMechanic /
                    // registerAsSteelBender / registerAsElectrician), not
                    // on the users doc, so it needs its own fetch per
                    // category.
                    if (_providerCollectionFor(category) != null) ...[
                      Text(
                        _providerPhotoLabelFor(category),
                        style: TextStyle(fontSize: 12, color: Colors.grey[700], fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                        future: FirebaseFirestore.instance
                            .collection(_providerCollectionFor(category)!)
                            .doc(uid)
                            .get(),
                        builder: (context, providerSnap) {
                          if (providerSnap.connectionState == ConnectionState.waiting) {
                            return Container(
                              height: 140,
                              alignment: Alignment.center,
                              child: const CircularProgressIndicator(strokeWidth: 2),
                            );
                          }
                          final providerData = providerSnap.data?.data();
                          final photoField = category == 'Okada' ? 'riderPhotoUrl' : 'photoUrl';
                          final providerPhotoUrl = providerData == null ? null : providerData[photoField] as String?;
                          if (providerPhotoUrl == null || providerPhotoUrl.isEmpty) {
                            return Container(
                              height: 140,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(10),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'No photo uploaded',
                                style: TextStyle(color: Colors.grey[500], fontSize: 12),
                              ),
                            );
                          }
                          return GestureDetector(
                            onTap: () => _viewFullPhoto(context, providerPhotoUrl,
                                '${data['fullName'] ?? 'Provider'} — ${_providerPhotoLabelFor(category)}'),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(
                                providerPhotoUrl,
                                height: 140,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  height: 140,
                                  color: Colors.red[50],
                                  alignment: Alignment.center,
                                  child: Text(
                                    'Could not load photo',
                                    style: TextStyle(color: Colors.red[300], fontSize: 12),
                                  ),
                                ),
                                loadingBuilder: (context, child, progress) {
                                  if (progress == null) return child;
                                  return Container(
                                    height: 140,
                                    alignment: Alignment.center,
                                    child: const CircularProgressIndicator(strokeWidth: 2),
                                  );
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ],

                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _setStatus(uid, 'rejected', category),
                            icon: const Icon(Icons.close, size: 16, color: Colors.red),
                            label: const Text('Reject', style: TextStyle(color: Colors.red)),
                            style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _setStatus(uid, 'verified', category),
                            icon: const Icon(Icons.check, size: 16),
                            label: const Text('Verify'),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700]),
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
    );
  }
}

/// Catches providers stuck between the two approval systems: their
/// `users/{uid}.verificationStatus` may already say 'verified' (so they no
/// longer show up in the "New Signups" tab), but their category doc
/// (mechanics/steel_benders/okada_riders/electricians/tailors/plumbers) is
/// still isPending/unapproved — which is what the public list screens
/// actually check. Queries each category collection directly, independent
/// of the users doc, so nothing can permanently fall through the gap again.
class _CategoryApprovalsTab extends StatelessWidget {
  final String? Function(String? category) providerCollectionFor;
  final String Function(String? category) providerPhotoLabelFor;

  const _CategoryApprovalsTab({
    required this.providerCollectionFor,
    required this.providerPhotoLabelFor,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _CategorySection(
          collection: 'mechanics',
          categoryLabel: 'Mechanic',
          pendingField: 'isPending',
          onApprove: (uid) => AuthService.instance.approveMechanic(uid),
        ),
        const SizedBox(height: 8),
        _CategorySection(
          collection: 'electricians',
          categoryLabel: 'Electrician',
          pendingField: 'isPending',
          onApprove: (uid) => AuthService.instance.approveElectrician(uid),
        ),
        const SizedBox(height: 8),
        _CategorySection(
          collection: 'tailors',
          categoryLabel: 'Tailor',
          pendingField: 'isPending',
          onApprove: (uid) => AuthService.instance.approveTailor(uid),
        ),
        const SizedBox(height: 8),
        _CategorySection(
          collection: 'plumbers',
          categoryLabel: 'Plumber',
          pendingField: 'isPending',
          onApprove: (uid) => AuthService.instance.approvePlumber(uid),
        ),
        const SizedBox(height: 8),
        _CategorySection(
          collection: 'teachers',
          categoryLabel: 'Teacher',
          pendingField: 'isPending',
          onApprove: (uid) => AuthService.instance.approveTeacher(uid),
        ),
        const SizedBox(height: 8),
        _CategorySection(
          collection: 'tilers',
          categoryLabel: 'Tiler',
          pendingField: 'isPending',
          onApprove: (uid) => AuthService.instance.approveTiler(uid),
        ),
        const SizedBox(height: 8),
        _CategorySection(
          collection: 'steel_benders',
          categoryLabel: 'Steel Bender',
          pendingField: 'isPending',
          onApprove: (uid) => AuthService.instance.approveSteelBender(uid),
        ),
        const SizedBox(height: 8),
        _CategorySection(
          collection: 'okada_riders',
          categoryLabel: 'Okada Rider',
          // okada_riders uses a 'verificationStatus' string field instead
          // of a boolean isPending — same shape as the users doc.
          pendingField: 'verificationStatus',
          pendingFieldValue: 'pending',
          onApprove: (uid) => AuthService.instance.approveOkadaRider(uid),
        ),
      ],
    );
  }
}

class _CategorySection extends StatelessWidget {
  final String collection;
  final String categoryLabel;
  final String pendingField;
  final Object pendingFieldValue; // true for isPending, 'pending' for verificationStatus
  final Future<void> Function(String uid) onApprove;

  const _CategorySection({
    required this.collection,
    required this.categoryLabel,
    required this.pendingField,
    this.pendingFieldValue = true,
    required this.onApprove,
  });

  @override
  Widget build(BuildContext context) {
    final query = FirebaseFirestore.instance
        .collection(collection)
        .where(pendingField, isEqualTo: pendingFieldValue);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              '$categoryLabel: could not load (${snapshot.error})',
              style: TextStyle(color: Colors.red[400], fontSize: 12),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '$categoryLabel ${docs.isEmpty ? '' : '(${docs.length})'}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
            if (docs.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('Nothing waiting here.', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              )
            else
              ...docs.map((doc) {
                final data = doc.data();
                final uid = doc.id;
                final name = (data['fullName'] as String?) ?? (data['riderName'] as String?) ?? (data['name'] as String?) ?? '(no name)';
                final phone = data['phoneNumber'] as String? ?? '-';
                final isApproved = data['isApproved'] == true;

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: ListTile(
                    dense: true,
                    title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    subtitle: Text(
                      isApproved ? 'Approved, but still marked pending — tap to fix' : 'Phone: $phone',
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: ElevatedButton(
                      onPressed: () async {
                        await onApprove(uid);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('$name approved')),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      child: const Text('Approve', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
  }
}
