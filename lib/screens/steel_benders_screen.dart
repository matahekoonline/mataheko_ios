// lib/screens/steel_benders_screen.dart
//
// Dynamic Firestore-backed list of approved Steel Benders, mirroring
// mechanics_screen.dart. Reads from the 'steel_benders' collection,
// showing only isApproved == true (admin-reviewed) providers. Supports
// filtering by specialty and highlights on-site/mobile availability
// since that's the key differentiator for this trade.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/steel_bender.dart';
import '../models/user_role.dart';
import '../widgets/bio_data_screen.dart';
import 'steel_bender_detail_screen.dart';

class SteelBendersScreen extends StatefulWidget {
  const SteelBendersScreen({super.key});

  @override
  State<SteelBendersScreen> createState() => _SteelBendersScreenState();
}

class _SteelBendersScreenState extends State<SteelBendersScreen> {
  String? _specialtyFilter; // null == 'All'

  @override
  Widget build(BuildContext context) {
    final query = FirebaseFirestore.instance
        .collection('steel_benders')
        .where('isApproved', isEqualTo: true);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Steel Benders'),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.green[700],
        icon: const Icon(Icons.add),
        label: const Text('Register'),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const BioDataScreen(role: UserRole.provider),
            ),
          );
        },
      ),
      body: Column(
        children: [
          _SpecialtyFilterRow(
            selected: _specialtyFilter,
            onSelected: (value) => setState(() => _specialtyFilter = value),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: query.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Something went wrong: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                var benders = snapshot.data!.docs
                    .map((doc) => SteelBender.fromMap(doc.id, doc.data()))
                    .toList();

                if (_specialtyFilter != null) {
                  benders = benders.where((b) => b.specialties.contains(_specialtyFilter)).toList();
                }

                if (benders.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _specialtyFilter == null
                            ? 'No Steel Benders registered yet. Be the first!'
                            : 'No Steel Benders found for "$_specialtyFilter" yet.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                  );
                }

                // Highest-rated / most-experienced first.
                benders.sort((a, b) {
                  final ratingCompare = b.rating.compareTo(a.rating);
                  if (ratingCompare != 0) return ratingCompare;
                  return b.yearsOfExperience.compareTo(a.yearsOfExperience);
                });

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                  itemCount: benders.length,
                  itemBuilder: (context, index) => _SteelBenderCard(bender: benders[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SpecialtyFilterRow extends StatelessWidget {
  final String? selected;
  final ValueChanged<String?> onSelected;
  const _SpecialtyFilterRow({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: [
          _chip(context, label: 'All', value: null),
          ...SteelBender.specialtyOptions.map((s) => _chip(context, label: s, value: s)),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, {required String label, required String? value}) {
    final isSelected = selected == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: isSelected,
        onSelected: (_) => onSelected(value),
        selectedColor: Colors.green[100],
        labelStyle: TextStyle(color: isSelected ? Colors.green[900] : Colors.black87),
      ),
    );
  }
}

class _SteelBenderCard extends StatelessWidget {
  final SteelBender bender;
  const _SteelBenderCard({required this.bender});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => SteelBenderDetailScreen(bender: bender)),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6, offset: const Offset(0, 3)),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: Colors.green[50],
              backgroundImage: bender.photoUrl != null ? NetworkImage(bender.photoUrl!) : null,
              child: bender.photoUrl == null
                  ? Icon(Icons.construction, color: Colors.green[700], size: 28)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          bender.workshopName.isNotEmpty ? bender.workshopName : bender.fullName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (bender.offersOnSiteService)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange[100],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.directions_car, size: 10, color: Colors.orange[800]),
                              const SizedBox(width: 3),
                              Text(
                                'On-Site',
                                style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.orange[800]),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 12, color: Colors.grey),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          bender.stationArea,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.star, size: 13, color: Colors.amber[700]),
                      const SizedBox(width: 2),
                      Text(
                        bender.rating > 0 ? bender.rating.toStringAsFixed(1) : 'New',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: bender.specialties.take(3).map((s) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green[200]!),
                        ),
                        child: Text(
                          s,
                          style: TextStyle(fontSize: 10, color: Colors.green[800], fontWeight: FontWeight.w600),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
