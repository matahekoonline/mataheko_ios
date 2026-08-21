import 'dart:async';
import 'package:flutter/material.dart';
import '../models/hero_banner.dart';
import '../models/hero_banner_settings.dart';
import '../services/hero_banner_service.dart';
import '../data/sample_banners.dart';
import 'add_edit_hero_banner_screen.dart';

/// Admin screen for managing home-screen hero banners. Lists every banner
/// (active + inactive), lets the admin drag to reorder, flip active on/off,
/// edit, or delete. New banners are added via AddEditHeroBannerScreen.
class ManageHeroBannersScreen extends StatefulWidget {
  const ManageHeroBannersScreen({super.key});

  @override
  State<ManageHeroBannersScreen> createState() => _ManageHeroBannersScreenState();
}

class _ManageHeroBannersScreenState extends State<ManageHeroBannersScreen> {
  List<HeroBanner> _banners = [];
  bool _loading = true;
  bool _seeding = false;
  HeroBannerSettings _settings = const HeroBannerSettings();
  bool _savingSettings = false;
  StreamSubscription<List<HeroBanner>>? _sub;

  @override
  void initState() {
    super.initState();
    _loadHeroSettings();
    // Kept as a local list (rather than built straight off a StreamBuilder)
    // so drag-to-reorder can update the UI instantly while the Firestore
    // batch write happens in the background.
    _sub = HeroBannerService.instance.allBannersStream().listen((banners) {
      setState(() {
        _banners = banners;
        _loading = false;
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _loadHeroSettings() async {
    try {
      final settings = await HeroBannerService.instance.getSettings();
      if (mounted) setState(() => _settings = settings);
    } catch (e) {
      debugPrint('Hero settings load error: $e');
    }
  }

  Future<void> _saveHeroSettings(HeroBannerSettings settings) async {
    setState(() {
      _settings = settings;
      _savingSettings = true;
    });
    try {
      await HeroBannerService.instance.updateSettings(settings);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hero display settings updated.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update hero settings: $e')),
      );
    } finally {
      if (mounted) setState(() => _savingSettings = false);
    }
  }

  Widget _buildHeroSettingsCard() {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.tune_rounded),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Hero display settings',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
                if (_savingSettings)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Control how long each banner stays visible and how quickly it changes.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 14),
            Text(
              'Time between slides: ${_settings.slideIntervalSeconds} seconds',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Slider(
              min: 3,
              max: 30,
              divisions: 27,
              value: _settings.slideIntervalSeconds.toDouble(),
              label: '${_settings.slideIntervalSeconds}s',
              onChanged: _savingSettings
                  ? null
                  : (v) => setState(() {
                        _settings = _settings.copyWith(
                          slideIntervalSeconds: v.round(),
                        );
                      }),
              onChangeEnd: (v) => _saveHeroSettings(
                _settings.copyWith(slideIntervalSeconds: v.round()),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Transition animation: ${_settings.transitionDurationMilliseconds} ms',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Slider(
              min: 200,
              max: 1500,
              divisions: 26,
              value: _settings.transitionDurationMilliseconds.toDouble(),
              label: '${_settings.transitionDurationMilliseconds}ms',
              onChanged: _savingSettings
                  ? null
                  : (v) => setState(() {
                        _settings = _settings.copyWith(
                          transitionDurationMilliseconds: v.round(),
                        );
                      }),
              onChangeEnd: (v) => _saveHeroSettings(
                _settings.copyWith(
                  transitionDurationMilliseconds: v.round(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _seedSamples() async {
    setState(() => _seeding = true);
    try {
      await HeroBannerService.instance.seedBanners(sampleBanners);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load sample banners: $e')),
      );
    } finally {
      if (mounted) setState(() => _seeding = false);
    }
  }

  Future<void> _confirmDelete(HeroBanner banner) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete banner?'),
        content: Text('"${banner.title}" will be permanently removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await HeroBannerService.instance.deleteBanner(banner.id);
    }
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;
    final updated = List<HeroBanner>.from(_banners);
    final moved = updated.removeAt(oldIndex);
    updated.insert(newIndex, moved);
    setState(() => _banners = updated); // optimistic UI update
    await HeroBannerService.instance.reorder(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hero Banners'), centerTitle: true),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.green[700],
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AddEditHeroBannerScreen(nextOrder: _banners.length),
          ),
        ),
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildHeroSettingsCard(),
                Expanded(
                  child: _banners.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('No hero banners yet.', textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: _seeding ? null : _seedSamples,
                          icon: _seeding
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.auto_awesome),
                          label: const Text('Load Sample Banners'),
                        ),
                      ],
                    ),
                  ),
                )
              : ReorderableListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                  itemCount: _banners.length,
                  onReorder: _onReorder,
                  itemBuilder: (context, index) {
                    final banner = _banners[index];
                    return _BannerRow(
                      key: ValueKey(banner.id),
                      banner: banner,
                      onEdit: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AddEditHeroBannerScreen(
                            existingBanner: banner,
                            nextOrder: _banners.length,
                          ),
                        ),
                      ),
                      onDelete: () => _confirmDelete(banner),
                      onActiveChanged: (val) =>
                          HeroBannerService.instance.setActive(banner.id, val),
                    );
                  },
                ),
                ),
              ],
            ),
    );
  }
}

class _BannerRow extends StatelessWidget {
  final HeroBanner banner;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onActiveChanged;

  const _BannerRow({
    super.key,
    required this.banner,
    required this.onEdit,
    required this.onDelete,
    required this.onActiveChanged,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = banner.imageUrl != null && banner.imageUrl!.isNotEmpty;

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        onTap: onEdit,
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 56,
            height: 56,
            child: hasImage
                ? Image.network(
                    banner.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (c, e, s) => Container(color: Colors.grey[300]),
                  )
                : Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: banner.gradientColors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Icon(banner.icon, color: Colors.white, size: 22),
                  ),
          ),
        ),
        title: Text(
          banner.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${banner.subtitle}\n${hasImage ? 'Photo' : 'Text design'} • ${banner.linkType.label}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: banner.active,
              activeColor: Colors.green[700],
              onChanged: onActiveChanged,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: onDelete,
            ),
            const Icon(Icons.drag_handle, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
