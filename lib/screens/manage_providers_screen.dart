import 'package:flutter/material.dart';
import '../models/admin_provider_record.dart';
import '../services/auth_service.dart';
import 'provider_edit_screen.dart';

/// Admin-only screen: shows every service provider across all 7 category
/// collections (okada_riders, mechanics, steel_benders, carpenters,
/// tailors, plumbers, electricians) in one searchable, filterable list.
/// Tapping a provider opens ProviderEditScreen where the admin can edit
/// any field, approve/unapprove, or delete the listing (and optionally
/// the linked user account data).
class ManageProvidersScreen extends StatefulWidget {
  const ManageProvidersScreen({super.key});

  @override
  State<ManageProvidersScreen> createState() => _ManageProvidersScreenState();
}

class _ManageProvidersScreenState extends State<ManageProvidersScreen> {
  late Future<List<AdminProviderRecord>> _future;
  String _query = '';
  String _categoryFilter = 'All';

  @override
  void initState() {
    super.initState();
    _future = AuthService.instance.fetchAllProviders();
  }

  void _reload() {
    setState(() {
      _future = AuthService.instance.fetchAllProviders();
    });
  }

  List<AdminProviderRecord> _applyFilters(List<AdminProviderRecord> all) {
    return all.where((p) {
      final matchesCategory =
          _categoryFilter == 'All' || p.category == _categoryFilter;
      final q = _query.trim().toLowerCase();
      final matchesQuery = q.isEmpty ||
          p.displayName.toLowerCase().contains(q) ||
          p.phoneNumber.toLowerCase().contains(q);
      return matchesCategory && matchesQuery;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final categories = ['All', ...AuthService.providerCollections.keys];

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Providers'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by name or phone...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey[200],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final cat = categories[index];
                final selected = cat == _categoryFilter;
                return ChoiceChip(
                  label: Text(cat),
                  selected: selected,
                  onSelected: (_) => setState(() => _categoryFilter = cat),
                  selectedColor: Colors.green[600],
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: FutureBuilder<List<AdminProviderRecord>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final all = snapshot.data ?? [];
                final filtered = _applyFilters(all);

                if (all.isEmpty) {
                  return const Center(child: Text('No providers found.'));
                }
                if (filtered.isEmpty) {
                  return const Center(child: Text('No matches.'));
                }

                return RefreshIndicator(
                  onRefresh: () async => _reload(),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final p = filtered[index];
                      return _ProviderTile(
                        record: p,
                        onTap: () async {
                          final changed = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProviderEditScreen(record: p),
                            ),
                          );
                          if (changed == true) _reload();
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ProviderTile extends StatelessWidget {
  final AdminProviderRecord record;
  final VoidCallback onTap;
  const _ProviderTile({required this.record, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: Colors.green[100],
          backgroundImage:
              record.photoUrl != null ? NetworkImage(record.photoUrl!) : null,
          child: record.photoUrl == null
              ? Text(
                  record.displayName.isNotEmpty
                      ? record.displayName[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                      color: Colors.green[900], fontWeight: FontWeight.bold),
                )
              : null,
        ),
        title: Text(record.displayName,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          '${record.category} · ${record.phoneNumber.isEmpty ? 'No phone' : record.phoneNumber}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: record.isApproved ? Colors.green[100] : Colors.orange[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            record.isApproved ? 'Approved' : 'Pending',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: record.isApproved ? Colors.green[800] : Colors.orange[800],
            ),
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}
