import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/hero_banner.dart';
import '../services/hero_banner_service.dart';
import '../services/photo_upload_service.dart';
import '../data/sample_listings.dart';

// Requires image_picker in pubspec.yaml (in addition to the
// firebase_core / cloud_firestore you already have):
//   image_picker: ^1.1.2
// Run `flutter pub get` after adding it. Photos upload to your PHP host
// via PhotoUploadService, the same as rider/mechanic/carpenter photos —
// not Firebase Storage.

enum _BannerMode { photo, text }

/// Preset gradient pairs, matching the palette already used in
/// sample_banners.dart. Kept as fixed swatches (rather than a full color
/// wheel) so admins get consistent, good-looking results with one tap.
const List<List<Color>> _gradientPresets = [
  [Color(0xFF2E7D32), Color(0xFF66BB6A)], // green
  [Color(0xFF1565C0), Color(0xFF42A5F5)], // blue
  [Color(0xFFEF6C00), Color(0xFFFFB74D)], // orange
  [Color(0xFF6A1B9A), Color(0xFFAB47BC)], // purple
  [Color(0xFF00695C), Color(0xFF26A69A)], // teal
  [Color(0xFFC62828), Color(0xFFEF5350)], // red
  [Color(0xFF283593), Color(0xFF5C6BC0)], // indigo
  [Color(0xFF37474F), Color(0xFF78909C)], // slate
  [Color(0xFFAD1457), Color(0xFFEC407A)], // pink
  [Color(0xFF827717), Color(0xFFC0CA33)], // olive
];

class AddEditHeroBannerScreen extends StatefulWidget {
  /// Pass an existing banner to edit it; leave null to create a new one.
  final HeroBanner? existingBanner;

  /// Order value to give a brand-new banner (appended to the end of the list).
  final int nextOrder;

  const AddEditHeroBannerScreen({
    super.key,
    this.existingBanner,
    required this.nextOrder,
  });

  @override
  State<AddEditHeroBannerScreen> createState() => _AddEditHeroBannerScreenState();
}

class _AddEditHeroBannerScreenState extends State<AddEditHeroBannerScreen> {
  late final bool _isEditing = widget.existingBanner != null;

  late _BannerMode _mode = (widget.existingBanner?.hasPhoto ?? false)
      ? _BannerMode.photo
      : _BannerMode.text;

  late final TextEditingController _titleCtrl =
      TextEditingController(text: widget.existingBanner?.title ?? '');
  late final TextEditingController _subtitleCtrl =
      TextEditingController(text: widget.existingBanner?.subtitle ?? '');
  late final TextEditingController _linkValueCtrl =
      TextEditingController(text: widget.existingBanner?.linkValue ?? '');

  // Separate from _linkValueCtrl because the category case is a dropdown
  // picked from the app's fixed categories list, not free text. Seeded
  // from the existing banner only when it was already linked to a category.
  late String? _selectedCategoryValue = widget.existingBanner?.linkType == BannerLinkType.category
      ? widget.existingBanner?.linkValue
      : null;

  late List<Color> _selectedGradient =
      widget.existingBanner?.gradientColors ?? _gradientPresets.first;
  late String _selectedIconKey = widget.existingBanner?.iconKey ?? 'campaign';
  late BannerLinkType _linkType =
      widget.existingBanner?.linkType ?? BannerLinkType.none;
  late bool _active = widget.existingBanner?.active ?? true;

  // Existing photo URL (already uploaded, from Firestore) vs. a newly
  // picked file waiting to be uploaded on Save.
  late String? _existingImageUrl = widget.existingBanner?.imageUrl;
  File? _pickedImageFile;

  bool _uploading = false;
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _subtitleCtrl.dispose();
    _linkValueCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (picked == null) return;
    setState(() {
      _pickedImageFile = File(picked.path);
      _existingImageUrl = null; // new photo replaces whatever was there
    });
  }

  Future<String> _uploadImage(String bannerId) async {
    return PhotoUploadService.uploadHeroBannerPhoto(
      uid: bannerId,
      photo: _pickedImageFile!,
    );
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    final subtitle = _subtitleCtrl.text.trim();

    if (title.isEmpty || subtitle.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title and subtitle are required.')),
      );
      return;
    }
    if (_mode == _BannerMode.photo && _pickedImageFile == null && _existingImageUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose a photo, or switch to Text Design.')),
      );
      return;
    }
    if (_linkType == BannerLinkType.category && _selectedCategoryValue == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please pick a category for this banner to link to.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      // A new banner needs an id before we can upload its photo under that
      // path, so reserve the doc id up front for creates.
      final id = widget.existingBanner?.id ??
          HeroBannerService.instance.newBannerId();

      String? finalImageUrl;
      if (_mode == _BannerMode.photo) {
        if (_pickedImageFile != null) {
          setState(() => _uploading = true);
          finalImageUrl = await _uploadImage(id);
          setState(() => _uploading = false);
        } else {
          finalImageUrl = _existingImageUrl;
        }
      }

      final banner = HeroBanner(
        id: id,
        title: title,
        subtitle: subtitle,
        imageUrl: _mode == _BannerMode.photo ? finalImageUrl : null,
        gradientColors: _selectedGradient,
        iconKey: _selectedIconKey,
        active: _active,
        order: widget.existingBanner?.order ?? widget.nextOrder,
        linkType: _linkType,
        linkValue: _linkType == BannerLinkType.none
            ? null
            : _linkType == BannerLinkType.category
                ? _selectedCategoryValue
                : _linkValueCtrl.text.trim(),
      );

      if (_isEditing) {
        await HeroBannerService.instance.updateBanner(banner);
      } else {
        await HeroBannerService.instance.createBannerWithId(banner);
      }

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save banner: $e')),
      );
    } finally {
      if (mounted) setState(() {
        _saving = false;
        _uploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Banner' : 'New Banner'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _buildPreview(),
          const SizedBox(height: 20),
          _buildModeToggle(),
          const SizedBox(height: 20),
          if (_mode == _BannerMode.photo) _buildPhotoPicker() else _buildTextDesignPicker(),
          const SizedBox(height: 20),
          _buildTextFields(),
          const SizedBox(height: 20),
          _buildLinkSection(),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Active'),
            subtitle: const Text('Shown on the home screen when on'),
            value: _active,
            activeColor: Colors.green[700],
            onChanged: (v) => setState(() => _active = v),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.green[700],
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _saving ? null : _save,
              child: _saving
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(_uploading
                      ? 'Uploading photo...'
                      : _isEditing
                          ? 'Save Changes'
                          : 'Add Banner'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    final hasImage = _mode == _BannerMode.photo &&
        (_pickedImageFile != null || _existingImageUrl != null);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          decoration: BoxDecoration(
            gradient: hasImage
                ? null
                : LinearGradient(
                    colors: _selectedGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            color: hasImage ? Colors.black : null,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasImage)
                _pickedImageFile != null
                    ? Image.file(_pickedImageFile!, fit: BoxFit.cover)
                    : Image.network(_existingImageUrl!, fit: BoxFit.cover),
              if (hasImage)
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.black.withOpacity(0.45), Colors.black.withOpacity(0.05)],
                      begin: Alignment.bottomLeft,
                      end: Alignment.topRight,
                    ),
                  ),
                ),
              if (!hasImage)
                Positioned(
                  right: -10,
                  bottom: -10,
                  child: Icon(
                    HeroBannerIcons.iconFor(_selectedIconKey),
                    size: 100,
                    color: Colors.white.withOpacity(0.15),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (!hasImage) ...[
                      Icon(HeroBannerIcons.iconFor(_selectedIconKey),
                          color: Colors.white, size: 24),
                      const SizedBox(height: 8),
                    ],
                    Text(
                      _titleCtrl.text.isEmpty ? 'Banner title' : _titleCtrl.text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _subtitleCtrl.text.isEmpty ? 'Banner subtitle' : _subtitleCtrl.text,
                      style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeToggle() {
    return SegmentedButton<_BannerMode>(
      segments: const [
        ButtonSegment(
          value: _BannerMode.photo,
          label: Text('Photo'),
          icon: Icon(Icons.photo),
        ),
        ButtonSegment(
          value: _BannerMode.text,
          label: Text('Text Design'),
          icon: Icon(Icons.text_fields),
        ),
      ],
      selected: {_mode},
      onSelectionChanged: (s) => setState(() => _mode = s.first),
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.green[700];
          return null;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return null;
        }),
      ),
    );
  }

  Widget _buildPhotoPicker() {
    final hasPhoto = _pickedImageFile != null || _existingImageUrl != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Photo', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(
          'Recommend roughly 1200×675px (16:9). It will be cropped to fill the banner.',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _pickImage,
          icon: const Icon(Icons.upload),
          label: Text(hasPhoto ? 'Replace Photo' : 'Choose Photo'),
        ),
      ],
    );
  }

  Widget _buildTextDesignPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Background gradient', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _gradientPresets.map((colors) {
            final selected = colors[0] == _selectedGradient[0] && colors[1] == _selectedGradient[1];
            return GestureDetector(
              onTap: () => setState(() => _selectedGradient = colors),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: colors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: selected
                      ? Border.all(color: Colors.black87, width: 2.5)
                      : null,
                ),
                child: selected
                    ? const Icon(Icons.check, color: Colors.white, size: 20)
                    : null,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        const Text('Icon', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: HeroBannerIcons.options.entries.map((entry) {
            final selected = entry.key == _selectedIconKey;
            return GestureDetector(
              onTap: () => setState(() => _selectedIconKey = entry.key),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: selected ? Colors.green[700] : Colors.grey[200],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(entry.value, color: selected ? Colors.white : Colors.grey[700]),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTextFields() {
    return Column(
      children: [
        TextField(
          controller: _titleCtrl,
          decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
          onChanged: (_) => setState(() {}),
          maxLength: 40,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _subtitleCtrl,
          decoration: const InputDecoration(labelText: 'Subtitle', border: OutlineInputBorder()),
          onChanged: (_) => setState(() {}),
          maxLength: 70,
        ),
      ],
    );
  }

  Widget _buildLinkSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('When tapped', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        DropdownButtonFormField<BannerLinkType>(
          initialValue: _linkType,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          items: BannerLinkType.values
              .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
              .toList(),
          onChanged: (v) => setState(() => _linkType = v ?? BannerLinkType.none),
        ),
        if (_linkType != BannerLinkType.none) ...[
          const SizedBox(height: 12),
          if (_linkType == BannerLinkType.category)
            DropdownButtonFormField<String>(
              initialValue: _selectedCategoryValue,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              items: categories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedCategoryValue = v),
            )
          else
            TextField(
              controller: _linkValueCtrl,
              decoration: InputDecoration(
                labelText: switch (_linkType) {
                  BannerLinkType.listing => 'Listing id',
                  BannerLinkType.url => 'URL (https://...)',
                  BannerLinkType.category => '',
                  BannerLinkType.none => '',
                },
                border: const OutlineInputBorder(),
              ),
            ),
        ],
      ],
    );
  }
}
