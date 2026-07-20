import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/sports_models.dart';
import '../services/sports_service.dart';
import '../services/photo_upload_service.dart';

class AddEditPlayerScreen extends StatefulWidget {
  final String sportType;
  final String teamId;
  final SportsPlayer? existing;

  const AddEditPlayerScreen({
    super.key,
    required this.sportType,
    required this.teamId,
    this.existing,
  });

  @override
  State<AddEditPlayerScreen> createState() => _AddEditPlayerScreenState();
}

class _AddEditPlayerScreenState extends State<AddEditPlayerScreen> {
  late final TextEditingController _nameController =
      TextEditingController(text: widget.existing?.name ?? '');
  late final TextEditingController _jerseyController =
      TextEditingController(text: widget.existing?.jerseyNumber?.toString() ?? '');
  late final TextEditingController _positionController =
      TextEditingController(text: widget.existing?.position ?? '');
  File? _pickedPhoto;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) setState(() => _pickedPhoto = File(picked.path));
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Player name is required')),
      );
      return;
    }
    final jersey = int.tryParse(_jerseyController.text.trim());
    final position = _positionController.text.trim();

    setState(() => _saving = true);
    try {
      if (_isEditing) {
        String? photoUrl;
        if (_pickedPhoto != null) {
          photoUrl =
              await PhotoUploadService.uploadPlayerPhoto(uid: widget.existing!.id, photo: _pickedPhoto!);
        }
        await SportsService.instance.updatePlayer(widget.existing!.id, {
          'name': name,
          'jerseyNumber': jersey,
          'position': position.isEmpty ? null : position,
          if (photoUrl != null) 'photoUrl': photoUrl,
        });
      } else {
        final id = SportsService.instance.newPlayerId();
        String? photoUrl;
        if (_pickedPhoto != null) {
          photoUrl = await PhotoUploadService.uploadPlayerPhoto(uid: id, photo: _pickedPhoto!);
        }
        await SportsService.instance.createPlayerWithId(
          id: id,
          sportType: widget.sportType,
          teamId: widget.teamId,
          name: name,
          jerseyNumber: jersey,
          position: position.isEmpty ? null : position,
          photoUrl: photoUrl,
        );
      }
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final existingPhoto = widget.existing?.photoUrl;

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Player' : 'Add Player'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: GestureDetector(
              onTap: _pickPhoto,
              child: CircleAvatar(
                radius: 48,
                backgroundColor: Colors.green[50],
                backgroundImage: _pickedPhoto != null
                    ? FileImage(_pickedPhoto!)
                    : (existingPhoto != null && existingPhoto.isNotEmpty
                        ? NetworkImage(existingPhoto) as ImageProvider
                        : null),
                child: (_pickedPhoto == null && (existingPhoto == null || existingPhoto.isEmpty))
                    ? Icon(Icons.person_outline, size: 40, color: Colors.green[700])
                    : null,
              ),
            ),
          ),
          Center(
            child: TextButton.icon(
              onPressed: _pickPhoto,
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Player photo'),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Player name', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _jerseyController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Jersey number', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _positionController,
            decoration: const InputDecoration(labelText: 'Position (optional)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.green[700],
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(_isEditing ? 'Save Changes' : 'Add Player'),
            ),
          ),
        ],
      ),
    );
  }
}
