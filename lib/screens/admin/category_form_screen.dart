import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../models/category.dart';
import '../../../services/category_service.dart';
import '../../../services/photo_upload_service.dart';

class CategoryFormScreen extends StatefulWidget {
  /// Null => adding a new category. Non-null => editing an existing one.
  final Category? existing;
  const CategoryFormScreen({super.key, this.existing});

  @override
  State<CategoryFormScreen> createState() => _CategoryFormScreenState();
}

class _CategoryFormScreenState extends State<CategoryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;

  File? _pickedIcon;
  String? _existingIconUrl;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _existingIconUrl = widget.existing?.iconUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickIcon() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (picked == null) return;
    setState(() => _pickedIcon = File(picked.path));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    // Require an icon on create; editing can keep the existing one.
    if (!_isEditing && _pickedIcon == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose a PNG icon for this category.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final id = widget.existing?.id ?? CategoryService.instance.newCategoryId();

      String? iconUrl = _existingIconUrl;
      if (_pickedIcon != null) {
        iconUrl = await PhotoUploadService.uploadCategoryIcon(uid: id, photo: _pickedIcon!);
      }

      final category = Category(
        id: id,
        name: _nameController.text.trim(),
        iconUrl: iconUrl,
        active: widget.existing?.active ?? true,
        order: widget.existing?.order ?? 0,
      );

      if (_isEditing) {
        await CategoryService.instance.updateCategory(category);
      } else {
        await CategoryService.instance.createCategoryWithId(category);
      }

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save category: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Category' : 'Add Category')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: GestureDetector(
                onTap: _pickIcon,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue[600]!, Colors.blue[400]!],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: ClipOval(
                    child: _pickedIcon != null
                        ? Image.file(_pickedIcon!, fit: BoxFit.cover)
                        : (_existingIconUrl != null && _existingIconUrl!.isNotEmpty
                        ? Image.network(_existingIconUrl!, fit: BoxFit.cover)
                        : const Icon(Icons.add_a_photo, color: Colors.white, size: 32)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: _pickIcon,
                child: Text(_pickedIcon != null || _existingIconUrl != null
                    ? 'Change icon'
                    : 'Choose PNG icon'),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Category name',
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _saving
                  ? const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
                  : Text(_isEditing ? 'Save Changes' : 'Add Category'),
            ),
          ],
        ),
      ),
    );
  }
}