import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/sports_models.dart';
import '../services/sports_service.dart';
import '../services/photo_upload_service.dart';

class AddEditTeamScreen extends StatefulWidget {
  final String sportType;
  final SportsTeam? existing;

  const AddEditTeamScreen({super.key, required this.sportType, this.existing});

  @override
  State<AddEditTeamScreen> createState() => _AddEditTeamScreenState();
}

class _AddEditTeamScreenState extends State<AddEditTeamScreen> {
  late final TextEditingController _nameController =
      TextEditingController(text: widget.existing?.name ?? '');
  File? _pickedLogo;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  Future<void> _pickLogo() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) setState(() => _pickedLogo = File(picked.path));
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Team name is required')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      if (_isEditing) {
        String? logoUrl;
        if (_pickedLogo != null) {
          logoUrl = await PhotoUploadService.uploadTeamLogo(
            uid: widget.existing!.id,
            photo: _pickedLogo!,
          );
        }
        await SportsService.instance.updateTeam(widget.existing!.id, name: name, logoUrl: logoUrl);
      } else {
        final id = SportsService.instance.newTeamId();
        String? logoUrl;
        if (_pickedLogo != null) {
          logoUrl = await PhotoUploadService.uploadTeamLogo(uid: id, photo: _pickedLogo!);
        }
        await SportsService.instance.createTeamWithId(
          id: id,
          sportType: widget.sportType,
          name: name,
          logoUrl: logoUrl,
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
    final existingLogo = widget.existing?.logoUrl;

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Team' : 'Add Team'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: GestureDetector(
              onTap: _pickLogo,
              child: CircleAvatar(
                radius: 48,
                backgroundColor: Colors.green[50],
                backgroundImage: _pickedLogo != null
                    ? FileImage(_pickedLogo!)
                    : (existingLogo != null && existingLogo.isNotEmpty
                        ? NetworkImage(existingLogo) as ImageProvider
                        : null),
                child: (_pickedLogo == null && (existingLogo == null || existingLogo.isEmpty))
                    ? Icon(Icons.shield_outlined, size: 40, color: Colors.green[700])
                    : null,
              ),
            ),
          ),
          Center(
            child: TextButton.icon(
              onPressed: _pickLogo,
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Team logo'),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Team name', border: OutlineInputBorder()),
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
                  : Text(_isEditing ? 'Save Changes' : 'Add Team'),
            ),
          ),
        ],
      ),
    );
  }
}
