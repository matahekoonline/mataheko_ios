import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/activity_service.dart';

class MyActivityScreen extends StatefulWidget {
  final String initialSection;

  const MyActivityScreen({
    super.key,
    this.initialSection = 'all',
  });

  @override
  State<MyActivityScreen> createState() => _MyActivityScreenState();
}

class _MyActivityScreenState extends State<MyActivityScreen> {
  late String _section;

  @override
  void initState() {
    super.initState();
    _section = widget.initialSection;
  }

  @override
  Widget build(BuildContext context) {
    if (ActivityService.instance.uid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Activity')),
        body: const Center(child: Text('Please sign in to view your activity.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Activity'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => setState(() {}),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            _buildIntro(),
            const SizedBox(height: 14),
            _buildSectionSelector(),
            const SizedBox(height: 18),
            if (_section == 'all' || _section == 'saved') _buildSavedSection(),
            if (_section == 'all' || _section == 'enquiries') _buildEnquiriesSection(),
            if (_section == 'all' || _section == 'viewed') _buildRecentlyViewedSection(),
            if (_section == 'all' || _section == 'reviews') _buildReviewsSection(),
            if (_section == 'all' || _section == 'posts') _buildPostsSection(),
            if (_section == 'all' || _section == 'rides') _buildRideRequestsSection(),
            if (_section == 'all' || _section == 'provider') _buildProviderSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildIntro() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [Colors.green.shade800, Colors.green.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Row(
        children: [
          CircleAvatar(
            radius: 27,
            backgroundColor: Colors.white24,
            child: Icon(Icons.timeline_rounded, color: Colors.white, size: 28),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Everything you do in one place',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                ),
                SizedBox(height: 5),
                Text(
                  'Saved items, enquiries, views, reviews and your own posts update automatically.',
                  style: TextStyle(color: Colors.white70, height: 1.35, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionSelector() {
    const sections = <Map<String, String>>[
      {'id': 'all', 'label': 'All'},
      {'id': 'saved', 'label': 'Saved'},
      {'id': 'enquiries', 'label': 'Enquiries'},
      {'id': 'viewed', 'label': 'Viewed'},
      {'id': 'reviews', 'label': 'Reviews'},
      {'id': 'posts', 'label': 'My Posts'},
      {'id': 'rides', 'label': 'Ride Requests'},
      {'id': 'provider', 'label': 'Provider'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final section in sections) ...[
            ChoiceChip(
              label: Text(section['label']!),
              selected: _section == section['id'],
              onSelected: (_) => setState(() => _section = section['id']!),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.grey.withOpacity(.14)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: color.withOpacity(.10),
                  child: Icon(icon, color: color, size: 19),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
              ],
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildSavedSection() {
    return _sectionCard(
      title: 'Saved',
      icon: Icons.favorite_border,
      color: Colors.red,
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: ActivityService.instance.savedStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const _ActivityLoading();
          final docs = _sortDocs(snapshot.data?.docs ?? const [], 'createdAt', descending: true);
          if (docs.isEmpty) return const _EmptyActivity(text: 'You have no saved items yet.');
          return Column(children: docs.take(10).map((doc) => _genericActivityTile(doc, Icons.favorite, 'saved')).toList());
        },
      ),
    );
  }

  Widget _buildEnquiriesSection() {
    return _sectionCard(
      title: 'Enquiries',
      icon: Icons.chat_bubble_outline,
      color: Colors.blue,
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: ActivityService.instance.enquiriesStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const _ActivityLoading();
          final docs = _sortDocs(snapshot.data?.docs ?? const [], 'createdAt', descending: true);
          if (docs.isEmpty) return const _EmptyActivity(text: 'Your enquiries will appear here.');
          return Column(children: docs.take(10).map((doc) => _enquiryTile(doc)).toList());
        },
      ),
    );
  }

  Widget _buildRecentlyViewedSection() {
    return _sectionCard(
      title: 'Recently Viewed',
      icon: Icons.history,
      color: Colors.deepPurple,
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: ActivityService.instance.recentlyViewedStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const _ActivityLoading();
          final docs = _sortDocs(snapshot.data?.docs ?? const [], 'viewedAt', descending: true);
          if (docs.isEmpty) return const _EmptyActivity(text: 'Items you view will appear here.');
          return Column(children: docs.take(10).map((doc) => _genericActivityTile(doc, Icons.history, 'viewed')).toList());
        },
      ),
    );
  }

  Widget _buildReviewsSection() {
    return _sectionCard(
      title: 'Reviews You Have Written',
      icon: Icons.star_border,
      color: Colors.amber.shade800,
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: ActivityService.instance.reviewsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const _ActivityLoading();
          if (snapshot.hasError) return Text('Could not load reviews: ${snapshot.error}');
          final docs = _sortDocs(snapshot.data?.docs ?? const [], 'createdAt', descending: true);
          if (docs.isEmpty) return const _EmptyActivity(text: 'Reviews you write will appear here.');
          return Column(children: docs.take(10).map((doc) => _reviewTile(doc)).toList());
        },
      ),
    );
  }

  Widget _buildPostsSection() {
    return _sectionCard(
      title: 'My Marketplace Items',
      icon: Icons.storefront_outlined,
      color: Colors.green,
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: ActivityService.instance.myMarketplaceItemsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const _ActivityLoading();
          final docs = _sortDocs(snapshot.data?.docs ?? const [], 'createdAt', descending: true);
          if (docs.isEmpty) return const _EmptyActivity(text: 'Your marketplace posts will appear here.');
          return Column(children: docs.take(10).map((doc) => _marketplaceTile(doc)).toList());
        },
      ),
    );
  }

  Widget _buildRideRequestsSection() {
    return _sectionCard(
      title: 'My Ride Along Requests',
      icon: Icons.directions_car_outlined,
      color: Colors.teal,
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: ActivityService.instance.myRideRequestsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const _ActivityLoading();
          final docs = _sortDocs(snapshot.data?.docs ?? const [], 'createdAt', descending: true);
          if (docs.isEmpty) return const _EmptyActivity(text: 'Ride requests you make will appear here.');
          return Column(children: docs.take(10).map((doc) => _rideRequestTile(doc)).toList());
        },
      ),
    );
  }

  Widget _buildProviderSection() {
    return _sectionCard(
      title: 'Provider Registration',
      icon: Icons.verified_user_outlined,
      color: Colors.orange.shade800,
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: ActivityService.instance.providerApplicationStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const _ActivityLoading();
          final data = snapshot.data?.data();
          if (data == null) return const _EmptyActivity(text: 'You have not started a provider registration.');

          final category = (data['categoryName'] ?? data['category'] ?? 'Provider').toString();
          final status = (data['status'] ?? data['providerStatus'] ?? 'pending').toString();
          final submitted = data['profileSubmitted'] == true;

          final statusColor = status.toLowerCase() == 'approved'
              ? Colors.green
              : status.toLowerCase() == 'rejected'
                  ? Colors.red
                  : Colors.orange;

          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: statusColor.withOpacity(.10),
              child: Icon(Icons.work_outline, color: statusColor),
            ),
            title: Text(category, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(submitted ? 'Registration submitted for review.' : 'Registration draft is not complete.'),
            trailing: Chip(
              label: Text(_pretty(status), style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w700)),
              backgroundColor: statusColor.withOpacity(.08),
              side: BorderSide.none,
            ),
          );
        },
      ),
    );
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _sortDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    String field, {
    required bool descending,
  }) {
    final result = [...docs];
    result.sort((a, b) {
      final av = _dateValue(a.data()[field]);
      final bv = _dateValue(b.data()[field]);
      final comparison = av.compareTo(bv);
      return descending ? -comparison : comparison;
    });
    return result;
  }

  DateTime _dateValue(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  Widget _genericActivityTile(DocumentSnapshot<Map<String, dynamic>> doc, IconData fallbackIcon, String type) {
    final data = doc.data() ?? {};
    final title = (data['title'] ?? 'Activity').toString();
    final subtitle = (data['subtitle'] ?? data['type'] ?? '').toString();
    final imageUrl = (data['imageUrl'] ?? '').toString();

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: _thumb(imageUrl, fallbackIcon),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle.isEmpty ? type : subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.chevron_right),
    );
  }

  Widget _enquiryTile(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final subject = (data['subject'] ?? 'Enquiry').toString();
    final message = (data['message'] ?? '').toString();
    final status = (data['status'] ?? 'open').toString();
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const CircleAvatar(child: Icon(Icons.chat_bubble_outline)),
      title: Text(subject, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(message, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: Chip(label: Text(_pretty(status), style: const TextStyle(fontSize: 10)), visualDensity: VisualDensity.compact),
    );
  }

  Widget _reviewTile(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final rating = (data['rating'] as num?)?.toDouble() ?? 0;
    final comment = (data['comment'] ?? '').toString();
    final provider = (data['providerName'] ?? data['providerCollection'] ?? 'Provider').toString();
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: Colors.amber.withOpacity(.12),
        child: const Icon(Icons.star, color: Colors.amber),
      ),
      title: Row(children: [Text(rating.toStringAsFixed(1)), const SizedBox(width: 4), const Icon(Icons.star, size: 15, color: Colors.amber)]),
      subtitle: Text('$provider${comment.isEmpty ? '' : '\n$comment'}', maxLines: 3, overflow: TextOverflow.ellipsis),
    );
  }

  Widget _marketplaceTile(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final title = (data['title'] ?? 'Marketplace item').toString();
    final approved = data['isApproved'] == true;
    final price = (data['price'] ?? '').toString();
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const CircleAvatar(child: Icon(Icons.storefront_outlined)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(price.isEmpty ? 'Marketplace post' : price),
      trailing: Chip(
        label: Text(approved ? 'Live' : 'Pending', style: TextStyle(fontSize: 10, color: approved ? Colors.green : Colors.orange)),
        backgroundColor: (approved ? Colors.green : Colors.orange).withOpacity(.08),
        side: BorderSide.none,
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _rideRequestTile(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final status = (data['status'] ?? 'pending').toString();
    final rideId = (data['rideId'] ?? '').toString();
    final seats = (data['seatsRequested'] ?? 1).toString();
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const CircleAvatar(child: Icon(Icons.event_seat_outlined)),
      title: Text('Ride ${rideId.isEmpty ? '' : rideId}', style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text('$seats seat${seats == '1' ? '' : 's'} requested'),
      trailing: Text(_pretty(status), style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }

  Widget _thumb(String imageUrl, IconData icon) {
    if (imageUrl.isEmpty) return CircleAvatar(child: Icon(icon));
    return CircleAvatar(backgroundImage: NetworkImage(imageUrl), onBackgroundImageError: (_, __) {});
  }

  String _pretty(String value) => value.isEmpty
      ? 'Unknown'
      : value[0].toUpperCase() + value.substring(1).replaceAll('_', ' ');
}

class _EmptyActivity extends StatelessWidget {
  final String text;
  const _EmptyActivity({required this.text});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            Icon(Icons.inbox_outlined, color: Colors.grey.shade400),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: TextStyle(color: Colors.grey.shade600))),
          ],
        ),
      );
}

class _ActivityLoading extends StatelessWidget {
  const _ActivityLoading();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
      );
}
