import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/media_item.dart';
import '../services/media_service.dart';
import 'video_player_screen.dart';

class MediaScreen extends StatelessWidget {
  const MediaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Local Talent'),
          centerTitle: true,
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.play_circle_outline), text: 'Videos'),
              Tab(icon: Icon(Icons.music_note_outlined), text: 'Music'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showSubmitInfo(context),
          icon: const Icon(Icons.upload),
          label: const Text('Submit Your Work'),
          backgroundColor: Colors.green[700],
        ),
        body: TabBarView(
          children: [
            StreamBuilder<List<MediaItem>>(
              stream: MediaService.instance.videosStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  debugPrint('Videos stream error: ${snapshot.error}');
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                return _VideoGrid(items: snapshot.data ?? const <MediaItem>[]);
              },
            ),
            StreamBuilder<List<MediaItem>>(
              stream: MediaService.instance.musicStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  debugPrint('Music stream error: ${snapshot.error}');
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                return _MusicList(items: snapshot.data ?? const <MediaItem>[]);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showSubmitInfo(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Share Your Music or Video',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'Are you a local artist, church, or creator in Mataheko-Afienya? '
              'Upload your original content to YouTube or Spotify, then share '
              'the link with us to get featured here.',
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final uri = Uri.parse('https://wa.me/233597555882');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                icon: const Icon(Icons.chat),
                label: const Text('Message Us on WhatsApp'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoGrid extends StatelessWidget {
  final List<MediaItem> items;
  const _VideoGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Text('No videos yet. Be the first to share!'));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => VideoPlayerScreen(item: item)),
            );
          },
          child: Card(
            clipBehavior: Clip.antiAlias,
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 100,
                  width: double.infinity,
                  color: Colors.green[100],
                  child: Icon(Icons.play_circle_fill, color: Colors.green[800], size: 40),
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.creatorName,
                        style: TextStyle(color: Colors.green[800], fontSize: 12),
                      ),
                    ],
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

class _MusicList extends StatelessWidget {
  final List<MediaItem> items;
  const _MusicList({required this.items});

  Future<void> _openAudioLink(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Text('No music yet. Be the first to share!'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = items[index];
        return Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding: const EdgeInsets.all(10),
            leading: CircleAvatar(
              radius: 26,
              backgroundColor: Colors.green[100],
              child: Icon(Icons.music_note, color: Colors.green[800]),
            ),
            title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${item.creatorName} · ${item.thumbnailNote}'),
            trailing: IconButton(
              icon: Icon(Icons.play_circle_fill, color: Colors.green[700], size: 32),
              onPressed: () => _openAudioLink(item.sourceId),
            ),
            onTap: () => _openAudioLink(item.sourceId),
          ),
        );
      },
    );
  }
}
