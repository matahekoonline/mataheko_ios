import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ManageEmergencyContactsScreen extends StatefulWidget {
  const ManageEmergencyContactsScreen({super.key});

  @override
  State<ManageEmergencyContactsScreen> createState() =>
      _ManageEmergencyContactsScreenState();
}

class _ManageEmergencyContactsScreenState
    extends State<ManageEmergencyContactsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _primary = TextEditingController();
  final _secondary = TextEditingController();
  final _description = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  final _ref =
      FirebaseFirestore.instance.collection('app_settings').doc('emergency_contacts');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final snap = await _ref.get();
      final d = snap.data() ?? {};
      _title.text = d['title']?.toString() ?? 'Emergency Contacts';
      _primary.text = d['primaryPhone']?.toString() ?? '';
      _secondary.text = d['secondaryPhone']?.toString() ?? '';
      _description.text = d['description']?.toString() ?? '';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await _ref.set({
        'title': _title.text.trim(),
        'primaryPhone': _primary.text.trim(),
        'secondaryPhone': _secondary.text.trim(),
        'description': _description.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Emergency contacts updated.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save emergency contacts: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _primary.dispose();
    _secondary.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Emergency Contacts')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    'These contacts appear at the bottom of every signed-in user Account screen.',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _title,
                    decoration: const InputDecoration(
                      labelText: 'Section title',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _primary,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Primary emergency phone',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) && _secondary.text.trim().isEmpty
                            ? 'Add at least one emergency phone number.'
                            : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _secondary,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Secondary emergency phone',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _description,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Description / instructions',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(_saving ? 'Saving…' : 'Save emergency contacts'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
