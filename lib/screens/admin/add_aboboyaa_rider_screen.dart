import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/photo_upload_service.dart';

class AddAboboyaaRiderScreen extends StatefulWidget {
  const AddAboboyaaRiderScreen({super.key});

  @override
  State<AddAboboyaaRiderScreen> createState() =>
      _AddAboboyaaRiderScreenState();
}

class _AddAboboyaaRiderScreenState
    extends State<AddAboboyaaRiderScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _businessController = TextEditingController();
  final _phoneController = TextEditingController();
  final _stationController = TextEditingController();
  final _experienceController = TextEditingController();
  final _ghanaCardController = TextEditingController();
  final _vehicleController = TextEditingController();
  final _loadTypeController = TextEditingController();
  final _serviceController = TextEditingController();

  final _picker = ImagePicker();

  File? _operatorPhoto;
  File? _ghanaCardPhoto;

  final List<String> _loadTypes = [];
  final List<String> _servicesOffered = [];

  bool _isAvailable = true;
  bool _loading = false;
  String? _error;

  Future<void> _pickImage({
    required bool operatorPhoto,
  }) async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 80,
    );

    if (picked == null || !mounted) return;

    setState(() {
      if (operatorPhoto) {
        _operatorPhoto = File(picked.path);
      } else {
        _ghanaCardPhoto = File(picked.path);
      }
    });
  }

  void _addLoadType() {
    final value = _loadTypeController.text.trim();

    if (value.isEmpty) return;

    if (!_loadTypes.any(
          (e) => e.toLowerCase() == value.toLowerCase(),
    )) {
      setState(() {
        _loadTypes.add(value);
      });
    }

    _loadTypeController.clear();
  }

  void _addService() {
    final value = _serviceController.text.trim();

    if (value.isEmpty) return;

    if (!_servicesOffered.any(
          (e) => e.toLowerCase() == value.toLowerCase(),
    )) {
      setState(() {
        _servicesOffered.add(value);
      });
    }

    _serviceController.clear();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    if (_operatorPhoto == null) {
      setState(() {
        _error = 'Please add a photo of the Aboboyaa operator.';
      });
      return;
    }

    if (_ghanaCardPhoto == null) {
      setState(() {
        _error = 'Please add a photo of the Ghana Card.';
      });
      return;
    }

    if (_loadTypes.isEmpty) {
      setState(() {
        _error = 'Add at least one type of load handled.';
      });
      return;
    }

    if (_servicesOffered.isEmpty) {
      setState(() {
        _error = 'Add at least one service offered.';
      });
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      setState(() {
        _error = 'You must be signed in as admin to add a rider.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Create the Firestore document first.
      // We use this ID for the uploaded photos as well.
      final docRef = FirebaseFirestore.instance
          .collection('aboboyaa_riders')
          .doc();

      final riderId = docRef.id;

      // Upload public rider/operator photo.
      final photoUrl =
      await PhotoUploadService.uploadRiderPhoto(
        uid: riderId,
        photo: _operatorPhoto!,
      );

      // Upload sensitive Ghana Card photo.
      final ghanaCardPhotoUrl =
      await PhotoUploadService.uploadGhanaCardPhoto(
        uid: riderId,
        photo: _ghanaCardPhoto!,
      );

      final data = <String, dynamic>{
        // Firebase/document identity
        'uid': riderId,

        // Public rider information
        'riderName': _nameController.text.trim(),
        'businessName': _businessController.text.trim(),
        'phoneNumber': _phoneController.text.trim(),
        'vehicleNumber': _vehicleController.text.trim(),
        'stationName': _stationController.text.trim(),

        'yearsOfExperience':
        int.tryParse(
          _experienceController.text.trim(),
        ) ??
            0,

        'loadTypes': List<String>.from(_loadTypes),

        'servicesOffered':
        List<String>.from(_servicesOffered),

        'isAvailable': _isAvailable,

        // Admin-created riders are already approved.
        'verificationStatus': 'approved',

        // Rating
        'rating': 0.0,
        'reviewCount': 0,

        // Public photo
        'riderPhotoUrl': photoUrl,

        // Sensitive identity information
        'ghanaCardNumber':
        _ghanaCardController.text.trim(),

        'ghanaCardPhotoUrl': ghanaCardPhotoUrl,

        // Audit information
        'createdBy': currentUser.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await docRef.set(data);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Aboboyaa rider added successfully.',
          ),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      debugPrint(
        '[AddAboboyaaRiderScreen] Save failed: $e',
      );

      if (mounted) {
        setState(() {
          _error = 'Failed to save rider: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  InputDecoration _decoration(
      String label, {
        String? hint,
        IconData? icon,
      }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon:
      icon == null ? null : Icon(icon),
      border: const OutlineInputBorder(),
    );
  }

  Widget _chips(
      List<String> values,
      void Function(String) onDelete,
      ) {
    if (values.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: values.map(
              (value) {
            return Chip(
              label: Text(value),
              onDeleted: () {
                setState(() {
                  onDelete(value);
                });
              },
            );
          },
        ).toList(),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _businessController.dispose();
    _phoneController.dispose();
    _stationController.dispose();
    _experienceController.dispose();
    _ghanaCardController.dispose();
    _vehicleController.dispose();
    _loadTypeController.dispose();
    _serviceController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Aboboyaa Rider'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.stretch,
              children: [
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius:
                      BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.red[200]!,
                      ),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // -------------------------------------------------
                // Operator photo
                // -------------------------------------------------
                Center(
                  child: GestureDetector(
                    onTap: _loading
                        ? null
                        : () => _pickImage(
                      operatorPhoto: true,
                    ),
                    child: CircleAvatar(
                      radius: 55,
                      backgroundColor:
                      Colors.green[50],
                      backgroundImage:
                      _operatorPhoto == null
                          ? null
                          : FileImage(
                        _operatorPhoto!,
                      ),
                      child: _operatorPhoto == null
                          ? Icon(
                        Icons.add_a_photo,
                        color:
                        Colors.green[700],
                        size: 30,
                      )
                          : null,
                    ),
                  ),
                ),

                const SizedBox(height: 6),

                const Center(
                  child: Text(
                    'Operator photo (shown to app users)',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // -------------------------------------------------
                // Name
                // -------------------------------------------------
                TextFormField(
                  controller: _nameController,
                  textCapitalization:
                  TextCapitalization.words,
                  decoration: _decoration(
                    'Operator Name',
                    hint: 'e.g. Kwame Mensah',
                    icon: Icons.person_outline,
                  ),
                  validator: (v) =>
                  v == null ||
                      v.trim().isEmpty
                      ? 'Required'
                      : null,
                ),

                const SizedBox(height: 12),

                // -------------------------------------------------
                // Business name
                // -------------------------------------------------
                TextFormField(
                  controller: _businessController,
                  textCapitalization:
                  TextCapitalization.words,
                  decoration: _decoration(
                    'Business / Display Name',
                    hint:
                    'e.g. Kwame Aboboyaa Services',
                    icon: Icons.business_outlined,
                  ),
                  validator: (v) =>
                  v == null ||
                      v.trim().isEmpty
                      ? 'Required'
                      : null,
                ),

                const SizedBox(height: 12),

                // -------------------------------------------------
                // Phone
                // -------------------------------------------------
                TextFormField(
                  controller: _phoneController,
                  keyboardType:
                  TextInputType.phone,
                  decoration: _decoration(
                    'Phone Number',
                    hint: 'e.g. 024 XXX XXXX',
                    icon: Icons.phone_outlined,
                  ),
                  validator: (v) =>
                  v == null ||
                      v.trim().isEmpty
                      ? 'Required'
                      : null,
                ),

                const SizedBox(height: 12),

                // -------------------------------------------------
                // Vehicle number
                // -------------------------------------------------
                TextFormField(
                  controller: _vehicleController,
                  textCapitalization:
                  TextCapitalization.characters,
                  decoration: _decoration(
                    'Vehicle Number',
                    hint: 'e.g. AS 1234-24',
                    icon:
                    Icons.local_shipping_outlined,
                  ),
                  validator: (v) =>
                  v == null ||
                      v.trim().isEmpty
                      ? 'Required'
                      : null,
                ),

                const SizedBox(height: 12),

                // -------------------------------------------------
                // Station
                // -------------------------------------------------
                TextFormField(
                  controller: _stationController,
                  textCapitalization:
                  TextCapitalization.words,
                  decoration: _decoration(
                    'Station / Operating Area',
                    hint:
                    'e.g. Mataheko, Afienya',
                    icon:
                    Icons.location_on_outlined,
                  ),
                  validator: (v) =>
                  v == null ||
                      v.trim().isEmpty
                      ? 'Required'
                      : null,
                ),

                const SizedBox(height: 12),

                // -------------------------------------------------
                // Experience
                // -------------------------------------------------
                TextFormField(
                  controller:
                  _experienceController,
                  keyboardType:
                  TextInputType.number,
                  decoration: _decoration(
                    'Years of Experience',
                    hint: 'e.g. 5',
                    icon:
                    Icons.work_history_outlined,
                  ),
                  validator: (v) {
                    final value =
                    int.tryParse(
                      v?.trim() ?? '',
                    );

                    return value == null ||
                        value < 0
                        ? 'Enter a valid number of years'
                        : null;
                  },
                ),

                const SizedBox(height: 16),

                // -------------------------------------------------
                // Availability
                // -------------------------------------------------
                SwitchListTile(
                  contentPadding:
                  EdgeInsets.zero,
                  title: const Text(
                    'Currently Available',
                    style: TextStyle(
                      fontWeight:
                      FontWeight.w600,
                    ),
                  ),
                  subtitle: const Text(
                    'Show this operator as available on the Aboboyaa screen.',
                  ),
                  value: _isAvailable,
                  onChanged: _loading
                      ? null
                      : (value) {
                    setState(() {
                      _isAvailable =
                          value;
                    });
                  },
                ),

                const SizedBox(height: 8),

                // -------------------------------------------------
                // Load types
                // -------------------------------------------------
                const Text(
                  'Types of Load Handled',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight:
                    FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 8),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller:
                        _loadTypeController,
                        textCapitalization:
                        TextCapitalization
                            .sentences,
                        decoration:
                        _decoration(
                          'Load type',
                          hint:
                          'e.g. Building materials',
                        ),
                        onFieldSubmitted:
                            (_) =>
                            _addLoadType(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 56,
                      child:
                      ElevatedButton(
                        onPressed: _loading
                            ? null
                            : _addLoadType,
                        child: const Icon(
                          Icons.add,
                        ),
                      ),
                    ),
                  ],
                ),

                _chips(
                  _loadTypes,
                      (value) =>
                      _loadTypes.remove(
                        value,
                      ),
                ),

                const SizedBox(height: 18),

                // -------------------------------------------------
                // Services
                // -------------------------------------------------
                const Text(
                  'Services Offered',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight:
                    FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 8),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller:
                        _serviceController,
                        textCapitalization:
                        TextCapitalization
                            .sentences,
                        decoration:
                        _decoration(
                          'Service',
                          hint:
                          'e.g. Local delivery',
                        ),
                        onFieldSubmitted:
                            (_) =>
                            _addService(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 56,
                      child:
                      ElevatedButton(
                        onPressed: _loading
                            ? null
                            : _addService,
                        child: const Icon(
                          Icons.add,
                        ),
                      ),
                    ),
                  ],
                ),

                _chips(
                  _servicesOffered,
                      (value) =>
                      _servicesOffered
                          .remove(value),
                ),

                const SizedBox(height: 24),

                const Divider(),

                const SizedBox(height: 8),

                // -------------------------------------------------
                // Ghana Card
                // -------------------------------------------------
                Row(
                  children: [
                    const Icon(
                      Icons.lock_outline,
                      size: 15,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        'Identity record — admin only, never shown to app users',
                        style: TextStyle(
                          fontSize: 12,
                          color:
                          Colors.grey[700],
                          fontWeight:
                          FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                TextFormField(
                  controller:
                  _ghanaCardController,
                  decoration: _decoration(
                    'Ghana Card Number',
                    hint:
                    'GHA-XXXXXXXXX-X',
                    icon:
                    Icons.badge_outlined,
                  ),
                  validator: (v) =>
                  v == null ||
                      v.trim().isEmpty
                      ? 'Required'
                      : null,
                ),

                const SizedBox(height: 12),

                InkWell(
                  onTap: _loading
                      ? null
                      : () => _pickImage(
                    operatorPhoto:
                    false,
                  ),
                  borderRadius:
                  BorderRadius.circular(12),
                  child: Container(
                    height: 150,
                    width: double.infinity,
                    decoration:
                    BoxDecoration(
                      color: Colors.red[50],
                      borderRadius:
                      BorderRadius.circular(
                        12,
                      ),
                      border: Border.all(
                        color: Colors.red[100]!,
                      ),
                    ),
                    child:
                    _ghanaCardPhoto == null
                        ? Column(
                      mainAxisAlignment:
                      MainAxisAlignment
                          .center,
                      children: [
                        Icon(
                          Icons
                              .badge_outlined,
                          color:
                          Colors.red[300],
                          size: 34,
                        ),
                        const SizedBox(
                            height: 8),
                        Text(
                          'Tap to add Ghana Card photo',
                          style:
                          TextStyle(
                            color:
                            Colors.red[
                            300],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    )
                        : ClipRRect(
                      borderRadius:
                      BorderRadius
                          .circular(
                        12,
                      ),
                      child: Image.file(
                        _ghanaCardPhoto!,
                        fit: BoxFit.cover,
                        width:
                        double.infinity,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // -------------------------------------------------
                // Save
                // -------------------------------------------------
                ElevatedButton(
                  onPressed:
                  _loading ? null : _submit,
                  style:
                  ElevatedButton.styleFrom(
                    backgroundColor:
                    Colors.green[700],
                    foregroundColor:
                    Colors.white,
                    padding:
                    const EdgeInsets.symmetric(
                      vertical: 15,
                    ),
                  ),
                  child: _loading
                      ? const SizedBox(
                    height: 19,
                    width: 19,
                    child:
                    CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Text(
                    'Save Aboboyaa Rider',
                    style: TextStyle(
                      fontWeight:
                      FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}