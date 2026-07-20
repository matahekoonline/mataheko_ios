import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/carpenter.dart';
import '../../services/auth_service.dart';
import '../../services/photo_upload_service.dart';

/// Admin utility screen for directly adding a Carpenter entry (as opposed
/// to a provider self-registering through BioDataScreen via
/// registerAsCarpenter). Mirrors the Add Electrician form. New entries
/// still start isPending: true and need one tap on "Approve" back on
/// CarpentersScreen before they show up publicly -- there is deliberately
/// no auto-approve shortcut here.
class AddCarpenterScreen extends StatefulWidget {
  const AddCarpenterScreen({super.key});

  @override
  State<AddCarpenterScreen> createState() => _AddCarpenterScreenState();
}

class _AddCarpenterScreenState extends State<AddCarpenterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _workshopController = TextEditingController();
  final _areaController = TextEditingController();
  final _experienceController = TextEditingController();
  final _ghanaCardController = TextEditingController();

  final Set<String> _selectedSpecialties = {};
  final Set<String> _selectedMaterials = {};
  final Set<String> _selectedServices = {};
  bool _offersOnSiteService = false;

  File? _photo;
  File? _ghanaCardImage;
  final _picker = ImagePicker();

  bool _loading = false;
  String? _error;

  Future<void> _pickPhoto() async {
    final picked = await _picker.pickImage(source: ImageSource.camera, imageQuality: 80);
    if (picked != null) setState(() => _photo = File(picked.path));
  }

  Future<void> _pickGhanaCardImage() async {
    final picked = await _picker.pickImage(source: ImageSource.camera, imageQuality: 80);
    if (picked != null) setState(() => _ghanaCardImage = File(picked.path));
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
              selectedColor: Colors.green[100],
              checkmarkColor: Colors.green[800],
            );
          }).toList(),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedServices.isEmpty) {
      setState(() => _error = 'Select at least one service offered.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Admin-added entries don't have a signed-in uid to key uploads by,
      // so we use a throwaway id (timestamp) for the storage path -- this
      // matches how PhotoUploadService is used elsewhere (uid is just a
      // folder/prefix, not a Firestore document key here).
      final uploadKey = 'admin_${DateTime.now().millisecondsSinceEpoch}';

      String? photoUrl;
      if (_photo != null) {
        photoUrl = await PhotoUploadService.uploadRiderPhoto(uid: uploadKey, photo: _photo!);
      }

      String? ghanaCardPhotoUrl;
      if (_ghanaCardImage != null) {
        ghanaCardPhotoUrl = await PhotoUploadService.uploadGhanaCardPhoto(uid: uploadKey, photo: _ghanaCardImage!);
      }

      await AuthService.instance.addCarpenterByAdmin(
        fullName: _nameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        workshopName: _workshopController.text.trim(),
        stationArea: _areaController.text.trim(),
        yearsOfExperience: int.tryParse(_experienceController.text.trim()) ?? 0,
        specialties: _selectedSpecialties.toList(),
        materialsWorkedWith: _selectedMaterials.toList(),
        servicesOffered: _selectedServices.toList(),
        offersOnSiteService: _offersOnSiteService,
        ghanaCardNumber: _ghanaCardController.text.trim(),
        ghanaCardPhotoUrl: ghanaCardPhotoUrl,
        photoUrl: photoUrl,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Carpenter added — approve them from the list to make them public.')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      // ignore: avoid_print
      print('[AddCarpenterScreen] Save failed: $e');
      if (!mounted) return;
      setState(() => _error = 'Failed to save carpenter: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _workshopController.dispose();
    _areaController.dispose();
    _experienceController.dispose();
    _ghanaCardController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Carpenter')),
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

                Center(
                  child: GestureDetector(
                    onTap: _pickPhoto,
                    child: CircleAvatar(
                      radius: 44,
                      backgroundColor: Colors.green[50],
                      backgroundImage: _photo != null ? FileImage(_photo!) : null,
                      child: _photo == null
                          ? Icon(Icons.add_a_photo_outlined, color: Colors.green[700], size: 26)
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Text('Public photo (shown to app users)', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ),
                const SizedBox(height: 20),

                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder()),
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
                  controller: _workshopController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Workshop / Business Name',
                    hintText: 'e.g. Kofi Woodworks',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _areaController,
                  decoration: const InputDecoration(
                    labelText: 'Area / Location',
                    hintText: 'e.g. Mataheko main road',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _experienceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Years of Experience', border: OutlineInputBorder()),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),

                const SizedBox(height: 20),
                _chipSection('Specialties', Carpenter.specialtyOptions, _selectedSpecialties),
                const SizedBox(height: 20),
                _chipSection('Materials Worked With', Carpenter.materialOptions, _selectedMaterials),
                const SizedBox(height: 20),
                _chipSection('Services Offered', Carpenter.serviceOptions, _selectedServices),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Offers On-Site Service', style: TextStyle(fontSize: 13)),
                  value: _offersOnSiteService,
                  activeColor: Colors.green[700],
                  onChanged: (val) => setState(() => _offersOnSiteService = val),
                ),

                const SizedBox(height: 12),
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
                    height: 140,
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
                        Icon(Icons.badge_outlined, color: Colors.red[300], size: 32),
                        const SizedBox(height: 6),
                        Text('Tap to add Ghana Card photo (optional)', style: TextStyle(color: Colors.red[300], fontSize: 12)),
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
                    backgroundColor: Colors.green[700],
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _loading
                      ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                      : const Text('Save Carpenter'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
