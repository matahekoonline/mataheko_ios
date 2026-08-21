import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../utils/photo_picker_helper.dart';
import '../../models/home_cook.dart';
import '../../services/auth_service.dart';
import '../../services/photo_upload_service.dart';

/// Admin-only form for manually adding a Home Cook, including their menu.
/// Mirrors AddTilerScreen's structure/behavior. Writes go through
/// AuthService.addHomeCookByAdmin, same pattern as the other admin add
/// screens, rather than hitting Firestore directly.
///
/// Photos: kitchen/dish photos are picked from the gallery or camera and
/// uploaded as files (same multi-photo picker as AddHotelScreen). Ghana
/// Card verification photo now uses the same gallery/camera picker
/// pattern (single image) instead of a pasted URL.
class AddHomeCookScreen extends StatefulWidget {
  const AddHomeCookScreen({super.key});

  @override
  State<AddHomeCookScreen> createState() => _AddHomeCookScreenState();
}

class _AddHomeCookScreenState extends State<AddHomeCookScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _stationAreaController = TextEditingController();
  final _ghanaCardController = TextEditingController();

  final _cuisineInputController = TextEditingController();
  final _deliveryAreaInputController = TextEditingController();

  final List<String> _cuisineTypes = [];
  final List<String> _deliveryAreas = [];
  final List<MenuItem> _menu = [];

  final List<File> _photos = [];
  File? _ghanaCardPhoto;
  final _picker = ImagePicker();

  bool _offersDelivery = false;
  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _businessNameController.dispose();
    _stationAreaController.dispose();
    _ghanaCardController.dispose();
    _cuisineInputController.dispose();
    _deliveryAreaInputController.dispose();
    super.dispose();
  }

  void _addChip(TextEditingController controller, List<String> target) {
    final value = controller.text.trim();
    if (value.isEmpty) return;
    setState(() {
      target.add(value);
      controller.clear();
    });
  }

  Future<void> _addPhotosFromGallery() async {
    final picked = await _picker.pickMultiImage(imageQuality: 80);
    if (picked.isNotEmpty) {
      setState(() => _photos.addAll(picked.map((x) => File(x.path))));
    }
  }

  Future<void> _addPhotoFromCamera() async {
    final picked = await pickImageFromCameraOrGallery(context, imageQuality: 80);
    if (picked != null) setState(() => _photos.add(File(picked.path)));
  }

  void _removePhoto(int index) => setState(() => _photos.removeAt(index));

  Future<void> _pickGhanaCardFromGallery() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) setState(() => _ghanaCardPhoto = File(picked.path));
  }

  Future<void> _pickGhanaCardFromCamera() async {
    final picked = await pickImageFromCameraOrGallery(context, imageQuality: 80);
    if (picked != null) setState(() => _ghanaCardPhoto = File(picked.path));
  }

  void _removeGhanaCardPhoto() => setState(() => _ghanaCardPhoto = null);

  Future<void> _addMenuItem() async {
    final result = await showDialog<MenuItem>(
      context: context,
      builder: (_) => const _AddMenuItemDialog(),
    );
    if (result != null) setState(() => _menu.add(result));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final name = _nameController.text.trim();
      final phone = _phoneController.text.trim();

      // Kitchen/dish photos: addHomeCookByAdmin uploads these itself
      // (via _uploadHomeCookPhotos -> uploadListingPhoto internally), so
      // just pass the raw Files through -- don't upload them here too.

      // Upload the Ghana Card photo, if one was picked.
      String? ghanaCardPhotoUrl;
      if (_ghanaCardPhoto != null) {
        ghanaCardPhotoUrl = await PhotoUploadService.uploadGhanaCardPhoto(
          uid: phone,
          photo: _ghanaCardPhoto!,
        );
      }

      await AuthService.instance.addHomeCookByAdmin(
        fullName: name,
        phoneNumber: phone,
        businessName: _businessNameController.text.trim(),
        stationArea: _stationAreaController.text.trim(),
        cuisineTypes: _cuisineTypes,
        deliveryAreas: _deliveryAreas,
        offersDelivery: _offersDelivery,
        menu: _menu,
        ghanaCardNumber: _ghanaCardController.text.trim().isEmpty
            ? null
            : _ghanaCardController.text.trim(),
        ghanaCardPhotoUrl: ghanaCardPhotoUrl,
        photos: _photos,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$name added')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Could not add home cook. Try again.');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Home Cook')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
              ),
              const SizedBox(height: 16),
            ],

            // ---------------------------------------------------------
            // Photos -- kitchen / dish photos.
            // ---------------------------------------------------------
            Text('Photos', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              'Add a few photos — the cook, the kitchen, or dishes.',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 10),
            if (_photos.isNotEmpty)
              SizedBox(
                height: 100,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _photos.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(
                            _photos[index],
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: GestureDetector(
                            onTap: () => _removePhoto(index),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                        if (index == 0)
                          Positioned(
                            bottom: 2,
                            left: 2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text('Cover', style: TextStyle(fontSize: 9, color: Colors.white)),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            if (_photos.isNotEmpty) const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _addPhotosFromGallery,
                    icon: const Icon(Icons.photo_library_outlined, size: 18),
                    label: const Text('Add from gallery'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _addPhotoFromCamera,
                    icon: const Icon(Icons.camera_alt_outlined, size: 18),
                    label: const Text('Take photo'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Full Name'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'Phone Number'),
              keyboardType: TextInputType.phone,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _businessNameController,
              decoration: const InputDecoration(labelText: 'Kitchen / Business Name (optional)'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _stationAreaController,
              decoration: const InputDecoration(labelText: 'Station Area'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 20),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Offers Delivery'),
              subtitle: const Text('Off = pickup only'),
              value: _offersDelivery,
              onChanged: (v) => setState(() => _offersDelivery = v),
            ),

            if (_offersDelivery) ...[
              const SizedBox(height: 8),
              Text('Delivery Areas', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _deliveryAreaInputController,
                      decoration: const InputDecoration(hintText: 'e.g. Afienya'),
                      onSubmitted: (_) => _addChip(_deliveryAreaInputController, _deliveryAreas),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: Colors.deepOrange),
                    onPressed: () => _addChip(_deliveryAreaInputController, _deliveryAreas),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _deliveryAreas
                    .map((v) => Chip(
                  label: Text(v),
                  onDeleted: () => setState(() => _deliveryAreas.remove(v)),
                ))
                    .toList(),
              ),
            ],

            const SizedBox(height: 20),
            Text('Cuisine Types', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _cuisineInputController,
                    decoration: const InputDecoration(hintText: 'e.g. Local Dishes'),
                    onSubmitted: (_) => _addChip(_cuisineInputController, _cuisineTypes),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: Colors.deepOrange),
                  onPressed: () => _addChip(_cuisineInputController, _cuisineTypes),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: _cuisineTypes
                  .map((v) => Chip(
                label: Text(v),
                onDeleted: () => setState(() => _cuisineTypes.remove(v)),
              ))
                  .toList(),
            ),

            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Menu', style: Theme.of(context).textTheme.titleSmall),
                TextButton.icon(
                  onPressed: _addMenuItem,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Dish'),
                ),
              ],
            ),
            if (_menu.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('No dishes added yet', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              )
            else
              Column(
                children: _menu.asMap().entries.map((entry) {
                  final item = entry.value;
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      dense: true,
                      title: Text(item.name),
                      subtitle: item.description != null && item.description!.isNotEmpty
                          ? Text(item.description!)
                          : null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(item.price, style: const TextStyle(fontWeight: FontWeight.w600)),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () => setState(() => _menu.removeAt(entry.key)),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),

            const SizedBox(height: 24),
            Text('Verification (optional)', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            TextFormField(
              controller: _ghanaCardController,
              decoration: const InputDecoration(labelText: 'Ghana Card Number'),
            ),
            const SizedBox(height: 12),

            // ---------------------------------------------------------
            // Ghana Card verification photo -- now the same
            // gallery/camera picker pattern as the kitchen photos above,
            // instead of a pasted URL. Single photo only.
            // ---------------------------------------------------------
            Text('Ghana Card Photo', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 8),
            if (_ghanaCardPhoto != null)
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(
                      _ghanaCardPhoto!,
                      width: 120,
                      height: 120,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 2,
                    right: 2,
                    child: GestureDetector(
                      onTap: _removeGhanaCardPhoto,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            if (_ghanaCardPhoto != null) const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickGhanaCardFromGallery,
                    icon: const Icon(Icons.photo_library_outlined, size: 18),
                    label: Text(_ghanaCardPhoto == null ? 'Add from gallery' : 'Replace'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickGhanaCardFromCamera,
                    icon: const Icon(Icons.camera_alt_outlined, size: 18),
                    label: const Text('Take photo'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: Colors.deepOrange[700],
                foregroundColor: Colors.white,
              ),
              child: _isSaving
                  ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
                  : const Text('Save Home Cook'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddMenuItemDialog extends StatefulWidget {
  const _AddMenuItemDialog();

  @override
  State<_AddMenuItemDialog> createState() => _AddMenuItemDialogState();
}

class _AddMenuItemDialogState extends State<_AddMenuItemDialog> {
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Dish'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Dish Name'),
            autofocus: true,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _priceController,
            decoration: const InputDecoration(labelText: 'Price (e.g. 25 or GHS 25)'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _descriptionController,
            decoration: const InputDecoration(labelText: 'Description (optional)'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final name = _nameController.text.trim();
            final price = _priceController.text.trim();
            if (name.isEmpty || price.isEmpty) return;
            Navigator.pop(
              context,
              MenuItem(
                name: name,
                price: price,
                description: _descriptionController.text.trim().isEmpty
                    ? null
                    : _descriptionController.text.trim(),
              ),
            );
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}