import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/marketplace_item.dart';
import '../services/marketplace_service.dart';
import 'admin_marketplace_edit_screen.dart';

class VerifyMarketplaceScreen extends StatefulWidget {
  const VerifyMarketplaceScreen({super.key});

  @override
  State<VerifyMarketplaceScreen> createState() =>
      _VerifyMarketplaceScreenState();
}

class _VerifyMarketplaceScreenState extends State<VerifyMarketplaceScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;

  Future<bool> _isAdmin() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    return doc.data()?['isAdmin'] == true;
  }

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..forward();
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Marketplace Moderation',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF18212F),
        elevation: 0,
      ),
      body: FutureBuilder<bool>(
        future: _isAdmin(),
        builder: (context, adminSnap) {
          if (adminSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (adminSnap.data != true) {
            return const Center(
              child: Text('You do not have permission to view this page.'),
            );
          }

          return StreamBuilder<List<MarketplaceItem>>(
            stream: MarketplaceService.instance.streamPendingItems(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Could not load listings: ${snapshot.error}'));
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final items = snapshot.data ?? const [];
              if (items.isEmpty) {
                return const _EmptyMarket();
              }

              return ListView.builder(
                padding: const EdgeInsets.all(14),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];

                  return FadeTransition(
                    opacity: CurvedAnimation(
                      parent: _animation,
                      curve: Interval(
                        (index * .05).clamp(0, .75),
                        1,
                        curve: Curves.easeOut,
                      ),
                    ),
                    child: _MarketAdminCard(
                      item: item,
                      onChanged: () => setState(() {}),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _MarketAdminCard extends StatefulWidget {
  final MarketplaceItem item;
  final VoidCallback onChanged;

  const _MarketAdminCard({
    required this.item,
    required this.onChanged,
  });

  @override
  State<_MarketAdminCard> createState() => _MarketAdminCardState();
}

class _MarketAdminCardState extends State<_MarketAdminCard> {
  bool _busy = false;

  Future<void> _approve() async {
    setState(() => _busy = true);
    try {
      await MarketplaceService.instance.approveItem(widget.item.id);
      if (mounted) _toast('Listing approved.', good: true);
      widget.onChanged();
    } catch (e) {
      if (mounted) _toast('Could not approve: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete marketplace item?'),
        content: Text(
          'Delete "${widget.item.title}" permanently? '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red[700]),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    setState(() => _busy = true);
    try {
      await MarketplaceService.instance.deleteItem(widget.item.id);
      if (mounted) _toast('Listing deleted.');
      widget.onChanged();
    } catch (e) {
      if (mounted) _toast('Could not delete: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AdminMarketplaceEditScreen(item: widget.item),
      ),
    );
    if (changed == true) widget.onChanged();
  }

  void _toast(String text, {bool good = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: good ? const Color(0xFF166534) : null,
          content: Text(text),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final cover = item.photoUrls.isNotEmpty ? item.photoUrls.first : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFE4E9F0)),
      ),
      child: Column(
        children: [
          if (cover != null)
            Stack(
              children: [
                Image.network(
                  cover,
                  width: double.infinity,
                  height: 180,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _CoverPlaceholder(),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: _Pill(
                    text: '${item.photoUrls.length}/4 photos',
                  ),
                ),
              ],
            )
          else
            const _CoverPlaceholder(),
          Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.price,
                  style: const TextStyle(
                    color: Color(0xFF166534),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${item.locationText}  •  ${item.sellerPhone}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 11.5),
                ),
                if (item.description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    item.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(height: 1.35, fontSize: 12.5),
                  ),
                ],
                const SizedBox(height: 13),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : _edit,
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Edit'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _busy ? null : _approve,
                        icon: _busy
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check_rounded, size: 18),
                        label: const Text('Approve'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF166534),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _busy ? null : _delete,
                      tooltip: 'Delete',
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;

  const _Pill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 180,
      color: const Color(0xFFEAF2EC),
      alignment: Alignment.center,
      child: const Icon(
        Icons.inventory_2_rounded,
        size: 50,
        color: Color(0xFF6BA481),
      ),
    );
  }
}

class _EmptyMarket extends StatelessWidget {
  const _EmptyMarket();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_rounded,
              size: 60,
              color: Color(0xFF6BA481),
            ),
            SizedBox(height: 12),
            Text(
              'Marketplace is clear',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
            SizedBox(height: 5),
            Text(
              'There are no marketplace listings waiting for approval.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
