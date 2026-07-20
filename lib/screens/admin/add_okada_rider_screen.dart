import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/okada_rider.dart';
import '../../services/photo_upload_service.dart';

class AddOkadaRiderScreen extends StatefulWidget {
  const AddOkadaRiderScreen({super.key});

  @override
  State<AddOkadaRiderScreen> createState() => _AddOkadaRiderScreenState();
}

class _AddOkadaRiderScreenState extends State<AddOkadaRiderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _plateController = TextEditingController();
  final _stationController = TextEditingController();
  final _ghanaCardController = TextEditingController();
  bool _loading = false;
  String? _error;

  File? _riderPhoto;
  File? _ghanaCardPhoto;
  final _picker = ImagePicker();

  Future<void> _pickImage(bool isRiderPhoto) async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 80,
    );
    if (picked == null) return;
    setState(() {
      if (isRiderPhoto) {
        _riderPhoto = File(picked.path);
      } else {
        _ghanaCardPhoto = File(picked.path);
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_riderPhoto == null) {
      setState(() => _error = 'Please add a photo of the rider.');
      return;
    }
    if (_ghanaCardPhoto == null) {
      setState(() => _error = 'Please add a photo of the Ghana Card.');
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      setState(() => _error = 'You must be signed in as admin to add a rider.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Create the Firestore doc reference first to get an ID to tag
      // uploads with. We don't write to Firestore yet — only after both
      // uploads succeed — so we never end up with a doc pointing at
      // missing photos.
      final docRef = FirebaseFirestore.instance.collection('okada_riders').doc();
      final riderId = docRef.id;
      final adminUid = currentUser.uid;

      // Public rider photo — anyone browsing the Okada category can see this
      final riderPhotoUrl = await PhotoUploadService.uploadRiderPhoto(
        uid: adminUid,
        photo: _riderPhoto!,
      );

      // Ghana Card photo — separate subfolder on the PHP host with a
      // random unguessable filename (see upload_photo.php). Only share
      // this URL inside admin-only screens.
      final ghanaCardPhotoUrl = await PhotoUploadService.uploadGhanaCardPhoto(
        uid: adminUid,
        photo: _ghanaCardPhoto!,
      );

      final rider = OkadaRider(
        id: riderId,
        riderName: _nameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        numberPlate: _plateController.text.trim(),
        stationName: _stationController.text.trim(),
        ghanaCardNumber: _ghanaCardController.text.trim(),
        riderPhotoUrl: riderPhotoUrl,
        ghanaCardPhotoUrl: ghanaCardPhotoUrl,
      );

      // Override the client-side createdAt string with a server timestamp
      // so ordering (`orderBy('createdAt')` in okada_riders_screen.dart)
      // is reliable regardless of the device's clock.
      final data = rider.toMap();
      data['createdAt'] = FieldValue.serverTimestamp();

      await docRef.set(data);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rider added')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      // Surface the REAL error instead of a generic message — this is what
      // tells you whether it's the upload, Firestore permissions, or
      // something else. Once things are working reliably you can swap
      // this back to a friendlier generic message if you prefer.
      // ignore: avoid_print
      print('[AddOkadaRiderScreen] Save failed: $e');
      if (!mounted) return;
      setState(() => _error = 'Failed to save rider: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _plateController.dispose();
    _stationController.dispose();
    _ghanaCardController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Okada Rider')),
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
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Rider photo picker
                Center(
                  child: GestureDetector(
                    onTap: () => _pickImage(true),
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.green[50],
                      backgroundImage: _riderPhoto != null ? FileImage(_riderPhoto!) : null,
                      child: _riderPhoto == null
                          ? Icon(Icons.add_a_photo, color: Colors.green[700], size: 28)
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const Center(
                  child: Text('Rider photo (shown to app users)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ),
                const SizedBox(height: 20),

                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Rider Name', border: OutlineInputBorder()),
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
                  controller: _plateController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Number Plate',
                    hintText: 'e.g. GT 1234-24',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _stationController,
                  decoration: const InputDecoration(labelText: 'Station Name', border: OutlineInputBorder()),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),

                const SizedBox(height: 24),
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

                // Ghana Card photo picker
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
                      : const Text('Save Rider'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
