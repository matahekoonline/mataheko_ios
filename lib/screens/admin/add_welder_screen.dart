// FILE PATH: lib/screens/admin/add_welder_screen.dart
//
// FIX: the photo picked via _pickPhoto was never uploaded or passed to
// AuthService.addWelderByAdmin (see the old TODO/NOTE comments), so every
// welder got saved with photoUrl: null and WeldersScreen always fell back
// to the default icon. Now uploads through PhotoUploadService, same
// pattern as AddElectricianScreen/AddTilerScreen, and passes the resulting
// URL through.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/auth_service.dart';
import '../../services/photo_upload_service.dart';

// TODO: remove these three lists if welder.dart already defines equivalents,
// and import from there instead so options stay in one place.
const List<String> welderSpecialtyOptions = [
  'Gate Fabrication',
  'Window Grills / Burglar Proofing',
  'Staircase Railings',
  'Structural Steel',
  'Roofing Trusses',
  'Furniture (Metal)',
  'Repairs & Maintenance',
];

const List<String> welderMaterialOptions = [
  'Mild Steel',
  'Stainless Steel',
  'Aluminum',
  'Wrought Iron',
  'Cast Iron',
];

const List<String> welderServiceOptions = [
  'Arc Welding',
  'MIG Welding',
  'TIG Welding',
  'Cutting & Fabrication',
  'On-site Installation',
  'Painting / Finishing',
];

class AddWelderScreen extends StatefulWidget {
  const AddWelderScreen({super.key});

  @override
  State<AddWelderScreen> createState() => _AddWelderScreenState();
}

class _AddWelderScreenState extends State<AddWelderScreen> {

  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _businessController = TextEditingController();
  final _stationController = TextEditingController();
  final _yearsController = TextEditingController();

  final Set<String> _selectedSpecialties = {};
  final Set<String> _selectedMaterials = {};
  final Set<String> _selectedServices = {};
  bool _offersOnSiteService = false;

  File? _photoFile;
  bool _submitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _businessController.dispose();
    _stationController.dispose();
    _yearsController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      setState(() => _photoFile = File(picked.path));
    }
  }

  Widget _chipSelector({
    required String label,
    required List<String> options,
    required Set<String> selected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            final isSelected = selected.contains(option);
            return FilterChip(
              label: Text(option),
              selected: isSelected,
              onSelected: (value) {
                setState(() {
                  if (value) {
                    selected.add(option);
                  } else {
                    selected.remove(option);
                  }
                });
              },
              selectedColor: Colors.blueGrey[100],
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSpecialties.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one specialty.')),
      );
      return;
    }
    if (_selectedServices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one service offered.')),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      // Admin-added entries don't have a signed-in uid to key uploads by,
      // so use a throwaway id (timestamp) for the storage path -- same
      // pattern as AddElectricianScreen/AddTilerScreen.
      String? photoUrl;
      if (_photoFile != null) {
        final uploadKey = 'admin_${DateTime.now().millisecondsSinceEpoch}';
        photoUrl = await PhotoUploadService.uploadWelderPhoto(uid: uploadKey, photo: _photoFile!);
      }

      await AuthService.instance.addWelderByAdmin(
        fullName: _nameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        businessName: _businessController.text.trim(),
        stationArea: _stationController.text.trim(),
        yearsOfExperience: int.tryParse(_yearsController.text.trim()) ?? 0,
        specialtiesServiced: _selectedSpecialties.toList(),
        materialsWorkedWith: _selectedMaterials.toList(),
        servicesOffered: _selectedServices.toList(),
        offersOnSiteService: _offersOnSiteService,
        photoUrl: photoUrl,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Welder added. Approve from the list to make them public.')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      // ignore: avoid_print
      print('[AddWelderScreen] Save failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not add welder. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Welder')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: GestureDetector(
                onTap: _pickPhoto,
                child: CircleAvatar(
                  radius: 48,
                  backgroundColor: Colors.blueGrey[100],
                  backgroundImage: _photoFile != null ? FileImage(_photoFile!) : null,
                  child: _photoFile == null
                      ? Icon(Icons.add_a_photo_outlined, color: Colors.blueGrey[800])
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Full name', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone number', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _businessController,
              decoration: const InputDecoration(labelText: 'Business name', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _stationController,
              decoration: const InputDecoration(
                labelText: 'Station / area (e.g. Mataheko Junction)',
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _yearsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Years of experience', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 20),

            _chipSelector(
              label: 'Welding specialties',
              options: welderSpecialtyOptions,
              selected: _selectedSpecialties,
            ),
            _chipSelector(
              label: 'Materials worked with (optional)',
              options: welderMaterialOptions,
              selected: _selectedMaterials,
            ),
            _chipSelector(
              label: 'Services offered',
              options: welderServiceOptions,
              selected: _selectedServices,
            ),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Offers on-site service'),
              value: _offersOnSiteService,
              onChanged: (v) => setState(() => _offersOnSiteService = v),
            ),
            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueGrey[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _submitting
                  ? const SizedBox(
                height: 20, width: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
                  : const Text('Add Welder'),
            ),
          ],
        ),
      ),
    );
  }
}