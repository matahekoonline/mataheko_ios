import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../utils/photo_picker_helper.dart';
import '/models/room_for_rent.dart';
import '/services/auth_service.dart';

/// Admin-adds-directly form for a Room for Rent listing — mirrors
/// AddHotelScreen in shape (multi-photo property listing), not the
/// single-photo AddElectricianScreen/AddCarpenterScreen pattern. Photo
/// upload happens inside AuthService.addRoomForRentByAdmin itself, same
/// as addHotelByAdmin — this screen just hands over raw Files.
class AddRoomForRentScreen extends StatefulWidget {
  const AddRoomForRentScreen({super.key});

  @override
  State<AddRoomForRentScreen> createState() => _AddRoomForRentScreenState();
}

class _AddRoomForRentScreenState extends State<AddRoomForRentScreen> {
  static const _palmGreen = Color(0xFF1F6F4A);
  final _formKey = GlobalKey<FormState>();

  final _landlordNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _titleController = TextEditingController();
  final _areaController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _ghanaCardController = TextEditingController();

  String? _selectedRoomType;
  String? _selectedRentPeriod;
  final Set<String> _selectedAmenities = {};

  final List<File> _propertyPhotos = [];
  File? _ghanaCardImage;
  final _picker = ImagePicker();

  bool _loading = false;
  String? _error;

  Future<void> _pickPropertyPhoto() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      setState(() => _propertyPhotos.add(File(picked.path)));
    }
  }

  Future<void> _pickGhanaCardImage() async {
    final picked = await pickImageFromCameraOrGallery(context, imageQuality: 80);
    if (picked != null) {
      setState(() => _ghanaCardImage = File(picked.path));
    }
  }

  Widget _chipSection(String title, List<String> options, Set<String> selected) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((opt) {
            final isSelected = selected.contains(opt);
            return FilterChip(
              label: Text(opt, style: const TextStyle(fontSize: 12)),
              selected: isSelected,
              onSelected: (val) {
                setState(() {
                  if (val) {
                    selected.add(opt);
                  } else {
                    selected.remove(opt);
                  }
                });
              },
              selectedColor: _palmGreen.withOpacity(0.15),
              checkmarkColor: _palmGreen,
            );
          }).toList(),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedRoomType == null) {
      setState(() => _error = 'Please select a room type.');
      return;
    }
    if (_selectedRentPeriod == null) {
      setState(() => _error = 'Please select a rent period.');
      return;
    }
    if (_propertyPhotos.isEmpty) {
      setState(() => _error = 'Please add at least one property photo.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // AuthService.addRoomForRentByAdmin handles all photo uploads
      // internally (property photos + optional Ghana Card), same as
      // addHotelByAdmin — this screen just passes raw Files.
      await AuthService.instance.addRoomForRentByAdmin(
        landlordName: _landlordNameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        propertyTitle: _titleController.text.trim(),
        stationArea: _areaController.text.trim(),
        roomType: _selectedRoomType!,
        price: double.tryParse(_priceController.text.trim()) ?? 0,
        rentPeriod: _selectedRentPeriod!,
        amenities: _selectedAmenities.toList(),
        description: _descriptionController.text.trim(),
        photos: _propertyPhotos,
        ghanaCardNumber: _ghanaCardController.text.trim(),
        ghanaCardImage: _ghanaCardImage,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Room listing added — pending approval.')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      // ignore: avoid_print
      print('[AddRoomForRentScreen] Save failed: $e');
      if (!mounted) return;
      setState(() => _error = 'Failed to save listing: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _landlordNameController.dispose();
    _phoneController.dispose();
    _titleController.dispose();
    _areaController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _ghanaCardController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Room for Rent'),
        backgroundColor: _palmGreen,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
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

                const Text('Landlord Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _landlordNameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Landlord Full Name', border: OutlineInputBorder()),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone Number', border: OutlineInputBorder()),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),

                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 12),
                const Text('Property Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Property Title',
                    hintText: 'e.g. Neat self-contained near Mataheko market',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _areaController,
                  decoration: const InputDecoration(
                    labelText: 'Area / Location',
                    hintText: 'e.g. Mataheko, near the station',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _selectedRoomType,
                  decoration: const InputDecoration(labelText: 'Room Type', border: OutlineInputBorder()),
                  items: roomTypeOptions
                      .map((r) => DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: 13))))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedRoomType = v),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _priceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Price (GHS)',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedRentPeriod,
                        decoration: const InputDecoration(labelText: 'Per', border: OutlineInputBorder()),
                        items: roomRentPeriodOptions
                            .map((p) => DropdownMenuItem(value: p, child: Text(p, style: const TextStyle(fontSize: 12))))
                            .toList(),
                        onChanged: (v) => setState(() => _selectedRentPeriod = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _chipSection('Amenities', roomAmenityOptions, _selectedAmenities),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    hintText: 'Any extra details buyers should know',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),

                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 12),
                const Text('Property Photos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 4),
                Text(
                  'Add a few photos — exterior, room, kitchen, etc.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ..._propertyPhotos.map((file) => Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.file(file, width: 90, height: 90, fit: BoxFit.cover),
                            ),
                            Positioned(
                              top: 2,
                              right: 2,
                              child: GestureDetector(
                                onTap: () => setState(() => _propertyPhotos.remove(file)),
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
                        )),
                    GestureDetector(
                      onTap: _pickPropertyPhoto,
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Icon(Icons.add_photo_alternate_outlined, color: Colors.grey[500]),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.lock_outline, size: 14, color: Colors.redAccent),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Identity record — admin only, never shown to app users',
                        style: TextStyle(fontSize: 12, color: Colors.grey[700], fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _ghanaCardController,
                  decoration: const InputDecoration(
                    labelText: 'Ghana Card Number (optional)',
                    hintText: 'GHA-XXXXXXXXX-X',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _pickGhanaCardImage,
                  child: Container(
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red[100]!),
                    ),
                    child: _ghanaCardImage == null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.badge_outlined, color: Colors.red[300], size: 28),
                              const SizedBox(height: 6),
                              Text('Tap to add Ghana Card photo (optional)',
                                  style: TextStyle(color: Colors.red[300], fontSize: 12)),
                            ],
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(_ghanaCardImage!, fit: BoxFit.cover, width: double.infinity),
                          ),
                  ),
                ),

                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _palmGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _loading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Add Room Listing'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
