import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/plumber.dart';
import '../../services/photo_upload_service.dart';

class AddPlumberScreen extends StatefulWidget {
  const AddPlumberScreen({super.key});

  @override
  State<AddPlumberScreen> createState() => _AddPlumberScreenState();
}

class _AddPlumberScreenState extends State<AddPlumberScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _businessController = TextEditingController();
  final _areaController = TextEditingController();
  final _experienceController = TextEditingController();
  final _ghanaCardController = TextEditingController();

  final Set<String> _selectedPropertyTypes = {};
  final Set<String> _selectedBrands = {};
  final Set<String> _selectedServices = {};
  bool _offersEmergencyService = false;

  File? _plumberPhoto;
  File? _ghanaCardPhoto;
  final _picker = ImagePicker();
  bool _loading = false;
  String? _error;

  Future<void> _pickImage(bool isPlumberPhoto) async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1200, imageQuality: 80);
    if (picked == null) return;
    setState(() {
      if (isPlumberPhoto) {
        _plumberPhoto = File(picked.path);
      } else {
        _ghanaCardPhoto = File(picked.path);
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPropertyTypes.isEmpty) {
      setState(() => _error = 'Select at least one property type.');
      return;
    }
    if (_plumberPhoto == null) {
      setState(() => _error = 'Please add a photo of the plumber.');
      return;
    }
    if (_ghanaCardPhoto == null) {
      setState(() => _error = 'Please add a photo of the Ghana Card.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final docRef = FirebaseFirestore.instance.collection('plumbers').doc();
      final adminUid = FirebaseAuth.instance.currentUser?.uid ?? 'unknown_admin';

      final photoUrl = await PhotoUploadService.uploadPhoto(
        uid: adminUid,
        photo: _plumberPhoto!,
        type: 'rider_photos', // shared "public profile photo" bucket
      );
      final ghanaCardPhotoUrl = await PhotoUploadService.uploadGhanaCardPhoto(
        uid: adminUid,
        photo: _ghanaCardPhoto!,
      );

      final plumber = Plumber(
        id: docRef.id,
        name: _nameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        businessName: _businessController.text.trim(),
        stationArea: _areaController.text.trim(),
        yearsOfExperience: int.tryParse(_experienceController.text.trim()) ?? 0,
        propertyTypesServiced: _selectedPropertyTypes.toList(),
        fixtureBrands: _selectedBrands.toList(),
        servicesOffered: _selectedServices.toList(),
        offersEmergencyService: _offersEmergencyService,
        rating: 0.0,
        reviewCount: 0,
        // Admin-added plumbers still go through the same one-tap approval
        // as self-registered ones -- mirrors addElectricianByAdmin's
        // convention (there is deliberately no auto-approve shortcut, so
        // every entry gets the same final human check before going public).
        isApproved: false,
        isPending: true,
        ghanaCardNumber: _ghanaCardController.text.trim(),
        photoUrl: photoUrl,
        ghanaCardPhotoUrl: ghanaCardPhotoUrl,
      );

      await docRef.set({
        ...plumber.toMap(),
        // PlumbersScreen queries .orderBy('createdAt', descending: true) --
        // Firestore silently EXCLUDES any doc missing that field from an
        // orderBy query (no error, it just never shows up). Plumber.toMap()
        // doesn't set this itself, so it has to be added here explicitly.
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Plumber added — approve them from the list to make them public.')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _error = 'Failed to save plumber. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _businessController.dispose();
    _areaController.dispose();
    _experienceController.dispose();
    _ghanaCardController.dispose();
    super.dispose();
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
              selectedColor: Colors.blue[100],
              checkmarkColor: Colors.blue[800],
            );
          }).toList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Plumber')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: GestureDetector(
                    onTap: () => _pickImage(true),
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.blue[50],
                      backgroundImage: _plumberPhoto != null ? FileImage(_plumberPhoto!) : null,
                      child: _plumberPhoto == null
                          ? Icon(Icons.add_a_photo, color: Colors.blue[700], size: 28)
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const Center(
                  child: Text('Plumber photo (shown to app users)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ),
                const SizedBox(height: 20),

                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Plumber Name', border: OutlineInputBorder()),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _businessController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Business Name', border: OutlineInputBorder()),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone Number', border: OutlineInputBorder()),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _areaController,
                  decoration: const InputDecoration(labelText: 'Area / Location', border: OutlineInputBorder()),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _experienceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Years of Experience',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),

                const SizedBox(height: 20),
                _chipSection('Property Types Serviced', propertyTypeOptions, _selectedPropertyTypes),
                const SizedBox(height: 20),
                _chipSection('Fixture Brands (optional)', fixtureBrandOptions, _selectedBrands),
                const SizedBox(height: 20),
                _chipSection('Services Offered', plumbingServiceOptions, _selectedServices),

                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Offers Emergency / After-Hours Call-Out', style: TextStyle(fontSize: 13)),
                  value: _offersEmergencyService,
                  activeColor: Colors.blue[700],
                  onChanged: (val) => setState(() => _offersEmergencyService = val),
                ),

                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.lock_outline, size: 14, color: Colors.redAccent),
                    const SizedBox(width: 4),
                    Text(
                      'Identity record — admin only, never shown to app users',
                      style: TextStyle(fontSize: 12, color: Colors.grey[700], fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _ghanaCardController,
                  decoration: const InputDecoration(
                    labelText: 'Ghana Card Number',
                    hintText: 'GHA-XXXXXXXXX-X',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () => _pickImage(false),
                  child: Container(
                    height: 140,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red[100]!),
                    ),
                    child: _ghanaCardPhoto == null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.badge_outlined, color: Colors.red[300], size: 32),
                              const SizedBox(height: 6),
                              Text('Tap to add Ghana Card photo', style: TextStyle(color: Colors.red[300], fontSize: 12)),
                            ],
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(_ghanaCardPhoto!, fit: BoxFit.cover, width: double.infinity),
                          ),
                  ),
                ),

                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _loading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Save Plumber'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
