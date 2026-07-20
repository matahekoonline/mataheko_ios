import 'package:flutter/material.dart';
import '../../models/home_cook.dart';
import '../../services/auth_service.dart';

/// Admin-only form for manually adding a Home Cook, including their menu.
/// Mirrors AddTilerScreen's structure/behavior. Writes go through
/// AuthService.addHomeCookByAdmin, same pattern as the other admin add
/// screens, rather than hitting Firestore directly.
class AddHomeCookScreen extends StatefulWidget {
  const AddHomeCookScreen({super.key});

  @override
  State<AddHomeCookScreen> createState() => _AddHomeCookScreenState();
}

class _AddHomeCookScreenState extends State<AddHomeCookScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _stationAreaController = TextEditingController();
  final _ghanaCardController = TextEditingController();
  final _photoUrlController = TextEditingController();
  final _ghanaCardPhotoUrlController = TextEditingController();

  final _cuisineInputController = TextEditingController();
  final _deliveryAreaInputController = TextEditingController();

  final List<String> _cuisineTypes = [];
  final List<String> _deliveryAreas = [];
  final List<MenuItem> _menu = [];

  bool _offersDelivery = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _businessNameController.dispose();
    _stationAreaController.dispose();
    _ghanaCardController.dispose();
    _photoUrlController.dispose();
    _ghanaCardPhotoUrlController.dispose();
    _cuisineInputController.dispose();
    _deliveryAreaInputController.dispose();
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

  Future<void> _addMenuItem() async {
    final result = await showDialog<MenuItem>(
      context: context,
      builder: (_) => const _AddMenuItemDialog(),
    );
    if (result != null) setState(() => _menu.add(result));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final name = _nameController.text.trim();

      await AuthService.instance.addHomeCookByAdmin(
        fullName: name,
        phoneNumber: _phoneController.text.trim(),
        businessName: _businessNameController.text.trim(),
        stationArea: _stationAreaController.text.trim(),
        cuisineTypes: _cuisineTypes,
        deliveryAreas: _deliveryAreas,
        offersDelivery: _offersDelivery,
        menu: _menu,
        ghanaCardNumber: _ghanaCardController.text.trim().isEmpty
            ? null
            : _ghanaCardController.text.trim(),
        photoUrl: _photoUrlController.text.trim().isEmpty
            ? null
            : _photoUrlController.text.trim(),
        ghanaCardPhotoUrl: _ghanaCardPhotoUrlController.text.trim().isEmpty
            ? null
            : _ghanaCardPhotoUrlController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$name added')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not add home cook. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Home Cook')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Full Name'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'Phone Number'),
              keyboardType: TextInputType.phone,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _businessNameController,
              decoration: const InputDecoration(labelText: 'Kitchen / Business Name (optional)'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _stationAreaController,
              decoration: const InputDecoration(labelText: 'Station Area'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 20),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Offers Delivery'),
              subtitle: const Text('Off = pickup only'),
              value: _offersDelivery,
              onChanged: (v) => setState(() => _offersDelivery = v),
            ),

            if (_offersDelivery) ...[
              const SizedBox(height: 8),
              Text('Delivery Areas', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _deliveryAreaInputController,
                      decoration: const InputDecoration(hintText: 'e.g. Afienya'),
                      onSubmitted: (_) => _addChip(_deliveryAreaInputController, _deliveryAreas),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: Colors.deepOrange),
                    onPressed: () => _addChip(_deliveryAreaInputController, _deliveryAreas),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _deliveryAreas
                    .map((v) => Chip(
                          label: Text(v),
                          onDeleted: () => setState(() => _deliveryAreas.remove(v)),
                        ))
                    .toList(),
              ),
            ],

            const SizedBox(height: 20),
            Text('Cuisine Types', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _cuisineInputController,
                    decoration: const InputDecoration(hintText: 'e.g. Local Dishes'),
                    onSubmitted: (_) => _addChip(_cuisineInputController, _cuisineTypes),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: Colors.deepOrange),
                  onPressed: () => _addChip(_cuisineInputController, _cuisineTypes),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: _cuisineTypes
                  .map((v) => Chip(
                        label: Text(v),
                        onDeleted: () => setState(() => _cuisineTypes.remove(v)),
                      ))
                  .toList(),
            ),

            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Menu', style: Theme.of(context).textTheme.titleSmall),
                TextButton.icon(
                  onPressed: _addMenuItem,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Dish'),
                ),
              ],
            ),
            if (_menu.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('No dishes added yet', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              )
            else
              Column(
                children: _menu.asMap().entries.map((entry) {
                  final item = entry.value;
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      dense: true,
                      title: Text(item.name),
                      subtitle: item.description != null && item.description!.isNotEmpty
                          ? Text(item.description!)
                          : null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(item.price, style: const TextStyle(fontWeight: FontWeight.w600)),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () => setState(() => _menu.removeAt(entry.key)),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),

            const SizedBox(height: 24),
            Text('Verification (optional)', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            TextFormField(
              controller: _ghanaCardController,
              decoration: const InputDecoration(labelText: 'Ghana Card Number'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _photoUrlController,
              decoration: const InputDecoration(labelText: 'Photo URL'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _ghanaCardPhotoUrlController,
              decoration: const InputDecoration(labelText: 'Ghana Card Photo URL'),
            ),

            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: Colors.deepOrange[700],
                foregroundColor: Colors.white,
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Save Home Cook'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddMenuItemDialog extends StatefulWidget {
  const _AddMenuItemDialog();

  @override
  State<_AddMenuItemDialog> createState() => _AddMenuItemDialogState();
}

class _AddMenuItemDialogState extends State<_AddMenuItemDialog> {
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Dish'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Dish Name'),
            autofocus: true,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _priceController,
            decoration: const InputDecoration(labelText: 'Price (e.g. 25 or GHS 25)'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _descriptionController,
            decoration: const InputDecoration(labelText: 'Description (optional)'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final name = _nameController.text.trim();
            final price = _priceController.text.trim();
            if (name.isEmpty || price.isEmpty) return;
            Navigator.pop(
              context,
              MenuItem(
                name: name,
                price: price,
                description: _descriptionController.text.trim().isEmpty
                    ? null
                    : _descriptionController.text.trim(),
              ),
            );
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
