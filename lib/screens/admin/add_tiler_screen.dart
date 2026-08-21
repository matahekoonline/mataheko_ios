import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../utils/photo_picker_helper.dart';
import '../../services/auth_service.dart';
import '../../services/photo_upload_service.dart';

/// Admin-only form for manually adding a Tiler.
/// Mirrors AddElectricianScreen's structure/behavior, adapted to the Tiler
/// model's fields (specialties/materials/services + on-site consultation
/// instead of property types/services offered). Photos are captured with
/// the camera and uploaded through PhotoUploadService -- previously this
/// screen only had plain text fields for photo URLs, which meant no photo
/// was ever actually uploaded. Writes go through
/// AuthService.addTilerByAdmin, same pattern as the other admin add
/// screens, rather than hitting Firestore directly.
class AddTilerScreen extends StatefulWidget {
  const AddTilerScreen({super.key});

  @override
  State<AddTilerScreen> createState() => _AddTilerScreenState();
}

class _AddTilerScreenState extends State<AddTilerScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _stationAreaController = TextEditingController();
  final _yearsController = TextEditingController();
  final _ghanaCardController = TextEditingController();

  final _specialtyInputController = TextEditingController();
  final _materialInputController = TextEditingController();
  final _serviceInputController = TextEditingController();

  final List<String> _specialtiesServiced = [];
  final List<String> _materialsWorkedWith = [];
  final List<String> _servicesOffered = [];

  bool _offersOnSiteConsultation = false;

  File? _photo;
  File? _ghanaCardImage;
  final _picker = ImagePicker();

  bool _isSaving = false;
  String? _error;

  Future<void> _pickPhoto() async {
    final picked = await pickImageFromCameraOrGallery(context, imageQuality: 80);
    if (picked != null) setState(() => _photo = File(picked.path));
  }

  Future<void> _pickGhanaCardImage() async {
    final picked = await pickImageFromCameraOrGallery(context, imageQuality: 80);
    if (picked != null) setState(() => _ghanaCardImage = File(picked.path));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _businessNameController.dispose();
    _stationAreaController.dispose();
    _yearsController.dispose();
    _ghanaCardController.dispose();
    _specialtyInputController.dispose();
    _materialInputController.dispose();
    _serviceInputController.dispose();
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final name = _nameController.text.trim();

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

      await AuthService.instance.addTilerByAdmin(
        fullName: name,
        phoneNumber: _phoneController.text.trim(),
        businessName: _businessNameController.text.trim(),
        stationArea: _stationAreaController.text.trim(),
        yearsOfExperience: int.tryParse(_yearsController.text.trim()) ?? 0,
        specialtiesServiced: _specialtiesServiced,
        materialsWorkedWith: _materialsWorkedWith,
        servicesOffered: _servicesOffered,
        offersOnSiteConsultation: _offersOnSiteConsultation,
        ghanaCardNumber: _ghanaCardController.text.trim().isEmpty
            ? null
            : _ghanaCardController.text.trim(),
        photoUrl: photoUrl,
        ghanaCardPhotoUrl: ghanaCardPhotoUrl,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$name added — approve them from the list to make them public.')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      // ignore: avoid_print
      print('[AddTilerScreen] Save failed: $e');
      if (!mounted) return;
      setState(() => _error = 'Failed to save tiler: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Tiler')),
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
                      backgroundColor: Colors.teal[50],
                      backgroundImage: _photo != null ? FileImage(_photo!) : null,
                      child: _photo == null
                          ? Icon(Icons.add_a_photo_outlined, color: Colors.teal[700], size: 26)
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
                  decoration: const InputDecoration(labelText: 'Phone Number', border: OutlineInputBorder()),
                  keyboardType: TextInputType.phone,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _businessNameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Business Name (optional)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _stationAreaController,
                  decoration: const InputDecoration(labelText: 'Station Area', border: OutlineInputBorder()),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _yearsController,
                  decoration: const InputDecoration(labelText: 'Years of Experience', border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 20),

                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Offers On-Site Consultation', style: TextStyle(fontSize: 13)),
                  value: _offersOnSiteConsultation,
                  activeColor: Colors.teal[700],
                  onChanged: (v) => setState(() => _offersOnSiteConsultation = v),
                ),

                const SizedBox(height: 12),
                Text('Specialties Serviced', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _specialtyInputController,
                        decoration: const InputDecoration(hintText: 'e.g. Floor tiling', border: OutlineInputBorder()),
                        onSubmitted: (_) => _addChip(_specialtyInputController, _specialtiesServiced),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: Colors.teal),
                      onPressed: () => _addChip(_specialtyInputController, _specialtiesServiced),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: _specialtiesServiced
                      .map((v) => Chip(
                    label: Text(v),
                    onDeleted: () => setState(() => _specialtiesServiced.remove(v)),
                  ))
                      .toList(),
                ),

                const SizedBox(height: 20),
                Text('Materials Worked With', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _materialInputController,
                        decoration: const InputDecoration(hintText: 'e.g. Porcelain', border: OutlineInputBorder()),
                        onSubmitted: (_) => _addChip(_materialInputController, _materialsWorkedWith),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: Colors.teal),
                      onPressed: () => _addChip(_materialInputController, _materialsWorkedWith),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: _materialsWorkedWith
                      .map((v) => Chip(
                    label: Text(v),
                    onDeleted: () => setState(() => _materialsWorkedWith.remove(v)),
                  ))
                      .toList(),
                ),

                const SizedBox(height: 20),
                Text('Services Offered', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _serviceInputController,
                        decoration: const InputDecoration(hintText: 'e.g. Bathroom retiling', border: OutlineInputBorder()),
                        onSubmitted: (_) => _addChip(_serviceInputController, _servicesOffered),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: Colors.teal),
                      onPressed: () => _addChip(_serviceInputController, _servicesOffered),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: _servicesOffered
                      .map((v) => Chip(
                    label: Text(v),
                    onDeleted: () => setState(() => _servicesOffered.remove(v)),
                  ))
                      .toList(),
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
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                      : const Text('Save Tiler'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}