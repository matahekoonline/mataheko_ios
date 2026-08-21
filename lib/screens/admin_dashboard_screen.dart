import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/marketplace_service.dart';
import 'verify_providers_screen.dart';
import 'manage_providers_screen.dart';
import 'verify_marketplace_screen.dart';
import 'manage_hero_banners_screen.dart';
import 'manage_media_screen.dart';
import 'manage_sports_screen.dart';
import 'admin/manage_categories_screen.dart';
import 'admin_action_center_screen.dart';
import 'manage_emergency_contacts_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Future<_AdminStats> _statsFuture;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _statsFuture = _loadStats();
  }


  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<_AdminStats> _loadStats() async {
    final providerResults = await Future.wait(
      AuthService.providerCollections.entries.map(
        (entry) => FirebaseFirestore.instance.collection(entry.value).get(),
      ),
    );

    final providerTotal = providerResults.fold<int>(
      0,
      (sum, snap) => sum + snap.size,
    );

    final pendingProviders = providerResults.fold<int>(
      0,
      (sum, snap) {
        return sum +
            snap.docs.where((doc) {
              final data = doc.data();
              if (data['verificationStatus'] != null) {
                return data['verificationStatus'] == 'pending';
              }
              return data['isPending'] == true ||
                  data['isApproved'] != true;
            }).length;
      },
    );

    final pendingMarketplace = await FirebaseFirestore.instance
        .collection('marketplace_items')
        .where('isApproved', isEqualTo: false)
        .get();

    return _AdminStats(
      providerTotal: providerTotal,
      pendingProviders: pendingProviders,
      marketplaceTotal: pendingMarketplace.size,
    );
  }

  Future<void> _open(Widget page) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
    if (mounted) {
      setState(() {
        _statsFuture = _loadStats();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Admin Control Center',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF18212F),
        elevation: 0,
        actions: [
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('admin_notifications')
                .where('read', isEqualTo: false)
                .limit(20)
                .snapshots(),
            builder: (context, snap) {
              final count = snap.data?.docs.length ?? 0;
              return IconButton(
                tooltip: 'Admin action center',
                onPressed: () => _open(const AdminActionCenterScreen()),
                icon: Badge(
                  isLabelVisible: count > 0,
                  label: Text(count > 99 ? '99+' : '$count'),
                  child: const Icon(Icons.notifications_outlined),
                ),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() => _statsFuture = _loadStats());
          await _statsFuture;
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            FadeTransition(
              opacity: CurvedAnimation(
                parent: _controller,
                curve: const Interval(0, .55, curve: Curves.easeOut),
              ),
              child: _WelcomeHeader(),
            ),
            const SizedBox(height: 16),
            FutureBuilder<_AdminStats>(
              future: _statsFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SizedBox(
                    height: 110,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final stats = snapshot.data!;
                return SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, .12),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: _controller,
                      curve: const Interval(.15, .7, curve: Curves.easeOut),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          icon: Icons.groups_rounded,
                          label: 'Providers',
                          value: '${stats.providerTotal}',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.pending_actions_rounded,
                          label: 'Provider review',
                          value: '${stats.pendingProviders}',
                          alert: stats.pendingProviders > 0,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.storefront_rounded,
                          label: 'Market review',
                          value: '${stats.marketplaceTotal}',
                          alert: stats.marketplaceTotal > 0,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 22),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('account_deletion_requests')
                  .where('status', isEqualTo: 'pending')
                  .snapshots(),
              builder: (context, snap) {
                final count = snap.data?.docs.length ?? 0;
                if (count == 0) return const SizedBox.shrink();
                return _AnimatedActionCard(
                  controller: _controller,
                  index: 0,
                  icon: Icons.delete_forever_outlined,
                  title: 'Account deletion requests',
                  subtitle: '$count request${count == 1 ? '' : 's'} waiting for review.',
                  color: Colors.red.shade700,
                  badge: 'ACTION',
                  onTap: () => _open(const AdminActionCenterScreen()),
                );
              },
            ),
            const SizedBox(height: 8),
            Text(
              'Moderation',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: const Color(0xFF18212F),
              ),
            ),
            const SizedBox(height: 10),
            _AnimatedActionCard(
              controller: _controller,
              index: 0,
              icon: Icons.verified_user_rounded,
              title: 'Verify service providers',
              subtitle: 'Review identity details, photos and approve providers.',
              color: const Color(0xFF166534),
              badge: 'REVIEW',
              onTap: () => _open(const VerifyProvidersScreen()),
            ),
            _AnimatedActionCard(
              controller: _controller,
              index: 1,
              icon: Icons.manage_accounts_rounded,
              title: 'Manage all providers',
              subtitle: 'Search, edit, approve, suspend or delete provider records.',
              color: const Color(0xFF2563EB),
              onTap: () => _open(const ManageProvidersScreen()),
            ),
            _AnimatedActionCard(
              controller: _controller,
              index: 2,
              icon: Icons.storefront_rounded,
              title: 'Verify marketplace',
              subtitle: 'Approve, edit or delete marketplace listings and photos.',
              color: const Color(0xFF7C3AED),
              badge: 'MARKET',
              onTap: () => _open(const VerifyMarketplaceScreen()),
            ),
            const SizedBox(height: 18),
            Text(
              'Content & platform',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: const Color(0xFF18212F),
              ),
            ),
            const SizedBox(height: 10),
            _AdminGrid(
              onHero: () => _open(const ManageHeroBannersScreen()),
              onMedia: () => _open(const ManageMediaScreen()),
              onSports: () => _open(const ManageSportsScreen()),
              onCategories: () => _open(const ManageCategoriesScreen()),
              onEmergency: () => _open(const ManageEmergencyContactsScreen()),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminStats {
  final int providerTotal;
  final int pendingProviders;
  final int marketplaceTotal;

  const _AdminStats({
    required this.providerTotal,
    required this.pendingProviders,
    required this.marketplaceTotal,
  });
}

class _WelcomeHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF123B2A), Color(0xFF1F7A4C)],
        ),
        boxShadow: const [
          BoxShadow(
            blurRadius: 24,
            offset: Offset(0, 12),
            color: Color(0x24113B2A),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 58,
            width: 58,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.14),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.admin_panel_settings_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 15),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mataheko Admin',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Keep providers, listings and community content safe and up to date.',
                  style: TextStyle(
                    color: Colors.white70,
                    height: 1.35,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool alert;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    this.alert = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 104,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: alert ? const Color(0xFFF5C15D) : const Color(0xFFE8EDF3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: alert ? const Color(0xFFD97706) : const Color(0xFF166534)),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Color(0xFF18212F),
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10.5, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}

class _AnimatedActionCard extends StatelessWidget {
  final AnimationController controller;
  final int index;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final String? badge;
  final VoidCallback onTap;

  const _AnimatedActionCard({
    required this.controller,
    required this.index,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final start = .22 + (index * .08);
    final end = (start + .55).clamp(0.0, 1.0);

    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0.08, 0),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: controller,
          curve: Interval(start, end, curve: Curves.easeOutCubic),
        ),
      ),
      child: FadeTransition(
        opacity: CurvedAnimation(
          parent: controller,
          curve: Interval(start, end, curve: Curves.easeOut),
        ),
        child: Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 10),
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(19),
            side: const BorderSide(color: Color(0xFFE8EDF3)),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(19),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Row(
                children: [
                  Container(
                    height: 50,
                    width: 50,
                    decoration: BoxDecoration(
                      color: color.withOpacity(.10),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(icon, color: color, size: 26),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: Color(0xFF18212F),
                                ),
                              ),
                            ),
                            if (badge != null) ...[
                              const SizedBox(width: 7),
                              _Badge(text: badge!, color: color),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Colors.grey[600],
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: Colors.grey[400]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;

  const _Badge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(.09),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }
}

class _AdminGrid extends StatelessWidget {
  final VoidCallback onHero;
  final VoidCallback onMedia;
  final VoidCallback onSports;
  final VoidCallback onCategories;
  final VoidCallback onEmergency;

  const _AdminGrid({
    required this.onHero,
    required this.onMedia,
    required this.onSports,
    required this.onCategories,
    required this.onEmergency,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Hero banners', Icons.view_carousel_rounded, onHero),
      ('Media', Icons.photo_library_rounded, onMedia),
      ('Sports', Icons.sports_soccer_rounded, onSports),
      ('Categories', Icons.category_rounded, onCategories),
      ('Emergency contacts', Icons.emergency_rounded, onEmergency),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.7,
      ),
      itemBuilder: (_, i) {
        final item = items[i];
        return InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: item.$3,
          child: Ink(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE8EDF3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(item.$2, color: const Color(0xFF2563EB)),
                Text(
                  item.$1,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
