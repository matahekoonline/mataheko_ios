import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/marketplace_item.dart';
import '../services/marketplace_service.dart';
import '../services/photo_upload_service.dart';

class AdminMarketplaceEditScreen extends StatefulWidget {
  final MarketplaceItem item;

  const AdminMarketplaceEditScreen({
    super.key,
    required this.item,
  });

  @override
  State<AdminMarketplaceEditScreen> createState() =>
      _AdminMarketplaceEditScreenState();
}

class _AdminMarketplaceEditScreenState
    extends State<AdminMarketplaceEditScreen> {
  static const maxPhotos = 4;

  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _price;
  late final TextEditingController _location;
  late final TextEditingController _area;
  late final TextEditingController _phone;

  final _picker = ImagePicker();
  final List<String> _urls = [];
  final List<File> _newPhotos = [];

  bool _approved = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final i = widget.item;
    _title = TextEditingController(text: i.title);
    _description = TextEditingController(text: i.description);
    _price = TextEditingController(text: i.price);
    _location = TextEditingController(text: i.locationText);
    _area = TextEditingController(text: i.areaDetail ?? '');
    _phone = TextEditingController(text: i.sellerPhone);
    _urls.addAll(i.photoUrls.take(maxPhotos));
    _approved = i.isApproved;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _price.dispose();
    _location.dispose();
    _area.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _addPhotos() async {
    final remaining = maxPhotos - _urls.length - _newPhotos.length;
    if (remaining <= 0) {
      _toast('Maximum of 4 photos reached.');
      return;
    }

    final picked = await _picker.pickMultiImage(
      imageQuality: 80,
      maxWidth: 2000,
      maxHeight: 2000,
    );

    if (picked.isEmpty || !mounted) return;

    final existing = {
      ..._newPhotos.map((f) => f.path),
    };

    for (final x in picked) {
      if (remaining <= 0) break;
      if (existing.contains(x.path)) continue;
      _newPhotos.add(File(x.path));
      existing.add(x.path);
    }

    if (mounted) setState(() {});
  }

  void _removeUrl(int index) {
    setState(() => _urls.removeAt(index));
  }

  void _removeNewPhoto(int index) {
    setState(() => _newPhotos.removeAt(index));
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty ||
        _description.text.trim().isEmpty ||
        _price.text.trim().isEmpty ||
        _location.text.trim().isEmpty ||
        _phone.text.trim().isEmpty) {
      _toast('Please complete all required fields.');
      return;
    }

    if (_urls.length + _newPhotos.length == 0) {
      _toast('At least one photo is required.');
      return;
    }

    if (_urls.length + _newPhotos.length > maxPhotos) {
      _toast('A listing can have a maximum of 4 photos.');
      return;
    }

    setState(() => _saving = true);

    try {
      final urls = List<String>.from(_urls);

      for (final photo in _newPhotos) {
        final url = await PhotoUploadService.uploadMarketplacePhoto(
          uid: 'admin_${widget.item.id}',
          photo: photo,
        );
        if (url.trim().isNotEmpty) urls.add(url.trim());
      }

      await MarketplaceService.instance.adminUpdateItem(
        itemId: widget.item.id,
        title: _title.text,
        description: _description.text,
        price: _price.text,
        locationText: _location.text,
        areaDetail: _area.text,
        sellerPhone: _phone.text,
        photoUrls: urls,
        isApproved: _approved,
      );

      if (!mounted) return;
      _toast('Marketplace item updated.', good: true);
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) _toast('Could not save item: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
    final count = _urls.length + _newPhotos.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Edit Marketplace Item',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF18212F),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _PhotoEditor(
            urls: _urls,
            newPhotos: _newPhotos,
            count: count,
            onAdd: _saving ? null : _addPhotos,
            onRemoveUrl: _saving ? null : _removeUrl,
            onRemoveNew: _saving ? null : _removeNewPhoto,
          ),
          const SizedBox(height: 16),
          _field(_title, 'Title'),
          _field(_description, 'Description', maxLines: 4),
          _field(_price, 'Price'),
          _field(_location, 'Area / location'),
          _field(_area, 'Landmark (optional)'),
          _field(_phone, 'Seller phone'),
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            title: const Text(
              'Published / approved',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              _approved
                  ? 'Visible on the public marketplace'
                  : 'Hidden until approved',
            ),
            value: _approved,
            onChanged: _saving
                ? null
                : (value) => setState(() => _approved = value),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save_rounded),
            label: Text(_saving ? 'Saving...' : 'Save changes'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF166534),
              padding: const EdgeInsets.symmetric(vertical: 15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
      ),
    );
  }
}

class _PhotoEditor extends StatelessWidget {
  final List<String> urls;
  final List<File> newPhotos;
  final int count;
  final VoidCallback? onAdd;
  final void Function(int)? onRemoveUrl;
  final void Function(int)? onRemoveNew;

  const _PhotoEditor({
    required this.urls,
    required this.newPhotos,
    required this.count,
    required this.onAdd,
    required this.onRemoveUrl,
    required this.onRemoveNew,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4E9F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Listing photos',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              Text(
                '$count / 4',
                style: TextStyle(
                  color: count == 4
                      ? const Color(0xFF166534)
                      : Colors.grey[600],
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 92,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                ...urls.asMap().entries.map(
                  (entry) => _PhotoThumb(
                    image: NetworkImage(entry.value),
                    onRemove: onRemoveUrl == null
                        ? null
                        : () => onRemoveUrl!(entry.key),
                  ),
                ),
                ...newPhotos.asMap().entries.map(
                  (entry) => _PhotoThumb(
                    image: FileImage(entry.value),
                    onRemove: onRemoveNew == null
                        ? null
                        : () => onRemoveNew!(entry.key),
                  ),
                ),
                if (count < 4)
                  InkWell(
                    onTap: onAdd,
                    borderRadius: BorderRadius.circular(13),
                    child: Container(
                      width: 92,
                      height: 92,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF2EC),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(
                        Icons.add_a_photo_rounded,
                        color: Color(0xFF166534),
                      ),
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

class _PhotoThumb extends StatelessWidget {
  final ImageProvider image;
  final VoidCallback? onRemove;

  const _PhotoThumb({
    required this.image,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92,
      height: 92,
      margin: const EdgeInsets.only(right: 8),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: Image(
              image: image,
              width: 92,
              height: 92,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: Colors.grey[200],
                alignment: Alignment.center,
                child: const Icon(Icons.broken_image_outlined),
              ),
            ),
          ),
          Positioned(
            right: 4,
            top: 4,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
