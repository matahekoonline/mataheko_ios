import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/aboboyaa_rider.dart';
import 'aboboyaa_detail_screen.dart';

/// Dedicated directory for Aboboyaa operators.
///
/// Firestore collection:
///   aboboyaa_riders
///
/// This must match AuthService.providerCollections['Aboboyaa'] -- the
/// collection every self-registration (registerAsAboboyaa) and admin
/// approval (approveAboboyaaRider / setProviderApproved) call writes to.
/// Previously this screen pointed at a separate, unused 'aboboyaas'
/// collection, so approved riders never showed up here even though they
/// were correctly approved in 'aboboyaa_riders'.
///
/// Expected document fields (see models/aboboyaa_rider.dart):
///   riderName           String
///   businessName        String?
///   phoneNumber         String
///   stationName         String
///   yearsOfExperience   int
///   loadTypes           List<String>
///   servicesOffered     List<String>
///   isAvailable         bool
///   rating              num
///   reviewCount         int
///   riderPhotoUrl       String?
///   verificationStatus  String ('pending' | 'approved'), with legacy
///                       isApproved/isPending booleans also supported.
///
/// The screen filters approved records on the client so this does not
/// require a Firestore composite index.
class AboboyaaScreen extends StatefulWidget {
  const AboboyaaScreen({super.key});

  @override
  State<AboboyaaScreen> createState() => _AboboyaaScreenState();
}

class _AboboyaaScreenState extends State<AboboyaaScreen> {
  final _searchController = TextEditingController();
  String _search = '';

  static const _green = Color(0xFF1F6F4A);
  static const _greenDark = Color(0xFF155336);
  static const _gold = Color(0xFFE3A857);

  final CollectionReference<Map<String, dynamic>> _collection =
      FirebaseFirestore.instance.collection('aboboyaa_riders');

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (mounted) {
        setState(() => _search = _searchController.text.trim().toLowerCase());
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Stream<List<AboboyaaRider>> _aboboyaasStream() {
    return _collection.snapshots().map((snapshot) {
      final records = snapshot.docs
          .map((doc) => AboboyaaRider.fromMap(doc.id, doc.data()))
          .where((item) => item.isApproved)
          .toList();

      records.sort((a, b) {
        final ratingCompare = b.rating.compareTo(a.rating);
        if (ratingCompare != 0) return ratingCompare;
        return a.riderName.toLowerCase().compareTo(b.riderName.toLowerCase());
      });

      return records;
    });
  }

  List<AboboyaaRider> _filter(List<AboboyaaRider> records) {
    if (_search.isEmpty) return records;

    return records.where((item) {
      final searchable = [
        item.riderName,
        item.businessName,
        item.stationName,
        ...item.loadTypes,
        ...item.servicesOffered,
      ].join(' ').toLowerCase();

      return searchable.contains(_search);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8F7),
      appBar: AppBar(
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text(
          'Aboboyaa Services',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_greenDark, _green],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: StreamBuilder<List<AboboyaaRider>>(
        stream: _aboboyaasStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _ErrorState(error: snapshot.error.toString());
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final all = snapshot.data ?? const <AboboyaaRider>[];
          final records = _filter(all);

          return Column(
            children: [
              _HeaderCard(
                total: all.length,
                green: _green,
                gold: _gold,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search name, location or load service...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _search.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: _searchController.clear,
                          ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: _green, width: 1.3),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: records.isEmpty
                    ? _EmptyState(
                        hasSearch: _search.isNotEmpty,
                        onClear: _searchController.clear,
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: records.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          return _AboboyaaCard(item: records[index]);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final int total;
  final Color green;
  final Color gold;

  const _HeaderCard({
    required this.total,
    required this.green,
    required this.gold,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [green, const Color(0xFF2D855D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: green.withOpacity(0.18),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.22)),
            ),
            child: const Icon(
              Icons.local_shipping_outlined,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Aboboyaa & Load Transport',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  total == 1
                      ? '1 approved operator available'
                      : '$total approved operators available',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.88),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.inventory_2_outlined, color: gold, size: 27),
        ],
      ),
    );
  }
}

class _AboboyaaCard extends StatelessWidget {
  final AboboyaaRider item;

  const _AboboyaaCard({required this.item});

  static const _green = Color(0xFF1F6F4A);
  static const _gold = Color(0xFFE3A857);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1.5,
      margin: EdgeInsets.zero,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showDetails(context),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ProfileImage(photoUrl: item.riderPhotoUrl),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item.riderName.isEmpty ? 'Aboboyaa Operator' : item.riderName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _AvailabilityBadge(isAvailable: item.isAvailable),
                      ],
                    ),
                    if (item.businessName.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        item.businessName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 15,
                          color: _green,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            item.stationName.isEmpty
                                ? 'Location not provided'
                                : item.stationName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.star, size: 15, color: _gold),
                        const SizedBox(width: 3),
                        Text(
                          item.rating > 0
                              ? '${item.rating.toStringAsFixed(1)} (${item.reviewCount})'
                              : 'New',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 10),
                        if (item.yearsOfExperience > 0)
                          Text(
                            '${item.yearsOfExperience} yrs experience',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[700],
                            ),
                          ),
                      ],
                    ),
                    if (item.servicesOffered.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 5,
                        runSpacing: 5,
                        children: item.servicesOffered
                            .take(3)
                            .map(
                              (service) => _SmallTag(
                                label: service,
                                color: _green,
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetails(BuildContext context) {
    // Full profile screen (same pattern as Okada's RiderDetailScreen) --
    // real Call/WhatsApp actions and a reviews section, instead of the
    // previous lightweight bottom sheet that only showed the phone number
    // in a dialog with no working contact actions.
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AboboyaaDetailScreen(rider: item)),
    );
  }
}

class _ProfileImage extends StatelessWidget {
  final String? photoUrl;
  final double size;

  const _ProfileImage({
    required this.photoUrl,
    this.size = 72,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoUrl != null && photoUrl!.trim().isNotEmpty;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFEAF4EE),
        shape: BoxShape.circle,
        border: Border.all(
          color: const Color(0xFF1F6F4A).withOpacity(0.12),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: hasPhoto
          ? Image.network(
              photoUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.local_shipping_outlined,
                color: Color(0xFF1F6F4A),
                size: 32,
              ),
            )
          : const Icon(
              Icons.local_shipping_outlined,
              color: Color(0xFF1F6F4A),
              size: 32,
            ),
    );
  }
}

class _AvailabilityBadge extends StatelessWidget {
  final bool isAvailable;

  const _AvailabilityBadge({required this.isAvailable});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: isAvailable ? Colors.green[50] : Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: isAvailable ? Colors.green[700] : Colors.grey[500],
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            isAvailable ? 'Available' : 'Unavailable',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: isAvailable ? Colors.green[800] : Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallTag extends StatelessWidget {
  final String label;
  final Color color;
  final Color? textColor;

  const _SmallTag({
    required this.label,
    required this.color,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          color: textColor ?? color,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasSearch;
  final VoidCallback onClear;

  const _EmptyState({
    required this.hasSearch,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasSearch
                  ? Icons.search_off_rounded
                  : Icons.local_shipping_outlined,
              size: 54,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 14),
            Text(
              hasSearch
                  ? 'No Aboboyaa operators found'
                  : 'No Aboboyaa operators yet.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              hasSearch
                  ? 'Try another name, location or service.'
                  : 'Approved Aboboyaa operators will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
            if (hasSearch) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: onClear,
                child: const Text('Clear search'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String error;

  const _ErrorState({required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 50,
              color: Colors.redAccent,
            ),
            const SizedBox(height: 12),
            const Text(
              'Unable to load Aboboyaa operators',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
