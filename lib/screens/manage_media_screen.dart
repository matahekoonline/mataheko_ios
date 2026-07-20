import 'package:flutter/material.dart';
import '../models/media_item.dart';
import '../services/media_service.dart';

class ManageMediaScreen extends StatefulWidget {
  const ManageMediaScreen({super.key});

  @override
  State<ManageMediaScreen> createState() => _ManageMediaScreenState();
}

class _ManageMediaScreenState extends State<ManageMediaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _creatorController = TextEditingController();
  final _noteController = TextEditingController();
  final _linkController = TextEditingController();

  MediaType _selectedType = MediaType.video;
  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _creatorController.dispose();
    _noteController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  /// Pulls the 11-character video ID out of common YouTube URL shapes
  /// (watch?v=, youtu.be/, shorts/, embed/), or accepts a bare ID as-is.
  String? _extractYoutubeId(String input) {
    final trimmed = input.trim();

    final bareId = RegExp(r'^[a-zA-Z0-9_-]{11}$');
    if (bareId.hasMatch(trimmed)) return trimmed;

    final patterns = [
      RegExp(r'youtu\.be/([a-zA-Z0-9_-]{11})'),
      RegExp(r'youtube\.com/watch\?v=([a-zA-Z0-9_-]{11})'),
      RegExp(r'youtube\.com/shorts/([a-zA-Z0-9_-]{11})'),
      RegExp(r'youtube\.com/embed/([a-zA-Z0-9_-]{11})'),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(trimmed);
      if (match != null) return match.group(1);
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final title = _titleController.text.trim();
    final creator = _creatorController.text.trim();
    final note = _noteController.text.trim();
    final link = _linkController.text.trim();

    String sourceId;
    MediaSource source;

    if (_selectedType == MediaType.video) {
      final videoId = _extractYoutubeId(link);
      if (videoId == null) {
        _showMessage('Couldn\'t find a valid YouTube video ID in that link.');
        return;
      }
      sourceId = videoId;
      source = MediaSource.youtube;
    } else {
      if (!(link.startsWith('http://') || link.startsWith('https://'))) {
        _showMessage('Please paste a full link starting with http:// or https://');
        return;
      }
      sourceId = link;
      source = link.contains('spotify.com') ? MediaSource.spotify : MediaSource.audio;
    }

    setState(() => _isSaving = true);
    try {
      await MediaService.instance.addMediaItem(
        MediaItem(
          id: '', // ignored — Firestore generates the doc ID on add
          title: title,
          creatorName: creator,
          type: _selectedType,
          source: source,
          sourceId: sourceId,
          thumbnailNote: note,
        ),
      );
      _titleController.clear();
      _creatorController.clear();
      _noteController.clear();
      _linkController.clear();
      _showMessage('Added! It\'ll show up on the Local Talent page immediately.');
    } catch (e) {
      _showMessage('Something went wrong: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _confirmDelete(MediaItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete this item?'),
        content: Text('"${item.title}" will be removed from Local Talent.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await MediaService.instance.deleteMediaItem(item.id);
    }
  }

  String _sourceLabel(MediaSource source) {
    switch (source) {
      case MediaSource.youtube:
        return 'YouTube';
      case MediaSource.spotify:
        return 'Spotify';
      case MediaSource.audio:
        return 'Audio link';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Local Talent'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Form(
            key: _formKey,
            child: Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Add New',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('Video (YouTube)'),
                            selected: _selectedType == MediaType.video,
                            onSelected: (_) => setState(() => _selectedType = MediaType.video),
                            selectedColor: Colors.green[200],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('Audio (Spotify/MP3)'),
                            selected: _selectedType == MediaType.music,
                            onSelected: (_) => setState(() => _selectedType = MediaType.music),
                            selectedColor: Colors.green[200],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _creatorController,
                      decoration: const InputDecoration(
                        labelText: 'Creator / Artist name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _noteController,
                      decoration: const InputDecoration(
                        labelText: 'Short description',
                        hintText: 'Shown under the title',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _linkController,
                      decoration: InputDecoration(
                        labelText: _selectedType == MediaType.video
                            ? 'YouTube link'
                            : 'Spotify or direct MP3/audio link',
                        hintText: _selectedType == MediaType.video
                            ? 'https://youtube.com/watch?v=...'
                            : 'https://open.spotify.com/... or https://.../song.mp3',
                        border: const OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _submit,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.add),
                        label: Text(_isSaving ? 'Saving...' : 'Add to Local Talent'),
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
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Existing Items',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          StreamBuilder<List<MediaItem>>(
            stream: MediaService.instance.allMediaStream(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text('Error loading items: ${snapshot.error}');
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final items = snapshot.data ?? const <MediaItem>[];
              if (items.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Nothing added yet.'),
                );
              }
              return Column(
                children: items.map((item) {
                  return Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.green[100],
                        child: Icon(
                          item.type == MediaType.video
                              ? Icons.play_circle_outline
                              : Icons.music_note_outlined,
                          color: Colors.green[800],
                        ),
                      ),
                      title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${item.creatorName} · ${_sourceLabel(item.source)}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _confirmDelete(item),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
