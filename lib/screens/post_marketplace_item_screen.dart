import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/marketplace_service.dart';

class PostMarketplaceItemScreen extends StatefulWidget {
  const PostMarketplaceItemScreen({super.key});

  @override
  State<PostMarketplaceItemScreen> createState() =>
      _PostMarketplaceItemScreenState();
}

class _PostMarketplaceItemScreenState extends State<PostMarketplaceItemScreen> {
  static const maxPhotos = 4;

  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _price = TextEditingController();
  final _location = TextEditingController();
  final _area = TextEditingController();
  final _phone = TextEditingController();

  final _picker = ImagePicker();
  final List<File> _photos = [];

  bool _loading = false;
  String? _error;

  Future<void> _addPhotos() async {
    final remaining = maxPhotos - _photos.length;
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

    final existing = _photos.map((e) => e.path).toSet();
    final added = <File>[];

    for (final x in picked) {
      if (added.length >= remaining) break;
      if (existing.contains(x.path)) continue;
      final file = File(x.path);
      added.add(file);
      existing.add(x.path);
    }

    setState(() {
      _photos.addAll(added);
      _error = null;
    });

    if (picked.length > added.length) {
      _toast('Only 4 photos can be attached to one listing.');
    }
  }

  void _removePhoto(int index) {
    if (index < 0 || index >= _photos.length) return;
    setState(() {
      _photos.removeAt(index);
      _error = null;
    });
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    if (_photos.isEmpty) {
      setState(() => _error = 'Add at least one photo.');
      _toast('At least one photo is required.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await MarketplaceService.instance.postItem(
        title: _title.text,
        description: _description.text,
        price: _price.text,
        locationText: _location.text,
        areaDetail: _area.text,
        sellerPhone: _phone.text,
        photos: List<File>.unmodifiable(_photos),
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sell an Item')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Photos',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                ),
                Text(
                  '${_photos.length}/4',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Add up to 4 photos. The first photo is the cover.',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 92,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  ..._photos.asMap().entries.map(
                    (entry) => Container(
                      width: 92,
                      height: 92,
                      margin: const EdgeInsets.only(right: 8),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(13),
                            child: Image.file(
                              entry.value,
                              width: 92,
                              height: 92,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            right: 4,
                            top: 4,
                            child: GestureDetector(
                              onTap: _loading
                                  ? null
                                  : () => _removePhoto(entry.key),
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
                    ),
                  ),
                  if (_photos.length < maxPhotos)
                    InkWell(
                      onTap: _loading ? null : _addPhotos,
                      borderRadius: BorderRadius.circular(13),
                      child: Container(
                        width: 92,
                        height: 92,
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
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ],
            const SizedBox(height: 18),
            _field(_title, 'What are you selling?', requiredField: true),
            _field(_description, 'Description', maxLines: 4, requiredField: true),
            _field(_price, 'Price', requiredField: true),
            _field(_location, 'Area / location', requiredField: true),
            _field(_area, 'Landmark (optional)'),
            _field(_phone, 'Phone number', requiredField: true),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _loading ? null : _submit,
              icon: _loading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.publish_rounded),
              label: Text(_loading ? 'Posting...' : 'Post item'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF166534),
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool requiredField = false,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: TextFormField(
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
        validator: requiredField
            ? (v) => v == null || v.trim().isEmpty ? 'Required' : null
            : null,
      ),
    );
  }
}
