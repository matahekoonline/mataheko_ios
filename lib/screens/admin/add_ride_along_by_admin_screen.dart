import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/auth_service.dart';

/// Admin-adds-directly screen -- mirrors AddRideAlongScreen's fields but
/// calls addRideAlongByAdmin and has no "signed-in driver" to key uploads
/// by. Still lands as isPending: true / isApproved: false so it goes
/// through the same one-tap "Approve" flow in ManageProvidersScreen as
/// every other admin-add screen.
class AddRideAlongByAdminScreen extends StatefulWidget {
  const AddRideAlongByAdminScreen({super.key});

  @override
  State<AddRideAlongByAdminScreen> createState() => _AddRideAlongByAdminScreenState();
}

class _AddRideAlongByAdminScreenState extends State<AddRideAlongByAdminScreen> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  final _driverNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _fromController = TextEditingController();
  final _toController = TextEditingController();
  final _stationController = TextEditingController();
  final _seatsController = TextEditingController(text: '3');
  final _priceController = TextEditingController();
  final _carModelController = TextEditingController();
  final _carColorController = TextEditingController();
  final _plateController = TextEditingController();
  final _notesController = TextEditingController();
  final _ghanaCardController = TextEditingController();

  String _rideType = 'oneTime';
  DateTime? _departureDateTime;
  TimeOfDay? _recurringTime;
  final Set<String> _selectedDays = {};
  final List<String> _weekDays = const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  final List<File> _photos = [];
  File? _ghanaCardImage;
  bool _submitting = false;

  @override
  void dispose() {
    _driverNameController.dispose();
    _phoneController.dispose();
    _fromController.dispose();
    _toController.dispose();
    _stationController.dispose();
    _seatsController.dispose();
    _priceController.dispose();
    _carModelController.dispose();
    _carColorController.dispose();
    _plateController.dispose();
    _notesController.dispose();
    _ghanaCardController.dispose();
    super.dispose();
  }

  Future<void> _pickPhotos() async {
    final picked = await _picker.pickMultiImage(imageQuality: 80);
    if (picked.isNotEmpty) setState(() => _photos.addAll(picked.map((x) => File(x.path))));
  }

  Future<void> _pickGhanaCard() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) setState(() => _ghanaCardImage = File(picked.path));
  }

  Future<void> _pickOneTimeDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (time == null) return;
    setState(() => _departureDateTime =
        DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  Future<void> _pickRecurringTime() async {
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (time != null) setState(() => _recurringTime = time);
  }

  String _formatTimeOfDay(TimeOfDay t) {
    final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final minute = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    try {
      await AuthService.instance.addRideAlongByAdmin(
        driverName: _driverNameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        fromArea: _fromController.text.trim(),
        toArea: _toController.text.trim(),
        stationArea: _stationController.text.trim(),
        rideType: _rideType,
        departureDateTime: _rideType == 'oneTime' ? _departureDateTime : null,
        departureTime: _rideType == 'recurring' && _recurringTime != null
            ? _formatTimeOfDay(_recurringTime!)
            : null,
        recurringDays: _rideType == 'recurring' ? _selectedDays.toList() : const [],
        seatsTotal: int.tryParse(_seatsController.text.trim()) ?? 1,
        pricePerSeat: double.tryParse(_priceController.text.trim()) ?? 0,
        carModel: _carModelController.text.trim().isEmpty ? null : _carModelController.text.trim(),
        carColor: _carColorController.text.trim().isEmpty ? null : _carColorController.text.trim(),
        plateNumber: _plateController.text.trim().isEmpty ? null : _plateController.text.trim(),
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        photos: _photos,
        ghanaCardNumber:
            _ghanaCardController.text.trim().isEmpty ? null : _ghanaCardController.text.trim(),
        ghanaCardImage: _ghanaCardImage,
      );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Ride added. Approve it from Manage Providers.')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not add ride: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Ride Along')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _driverNameController,
              decoration: const InputDecoration(labelText: 'Driver name'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'Phone number'),
              keyboardType: TextInputType.phone,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _fromController,
              decoration: const InputDecoration(labelText: 'From'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _toController,
              decoration: const InputDecoration(labelText: 'To'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _stationController,
              decoration: const InputDecoration(labelText: 'Pickup point / landmark'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 20),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'oneTime', label: Text('One-time')),
                ButtonSegment(value: 'recurring', label: Text('Recurring')),
              ],
              selected: {_rideType},
              onSelectionChanged: (s) => setState(() => _rideType = s.first),
            ),
            const SizedBox(height: 12),
            if (_rideType == 'oneTime')
              OutlinedButton.icon(
                onPressed: _pickOneTimeDate,
                icon: const Icon(Icons.calendar_today),
                label: Text(_departureDateTime?.toString() ?? 'Pick date & time'),
              )
            else ...[
              Wrap(
                spacing: 8,
                children: _weekDays
                    .map((day) => FilterChip(
                          label: Text(day),
                          selected: _selectedDays.contains(day),
                          onSelected: (v) => setState(
                              () => v ? _selectedDays.add(day) : _selectedDays.remove(day)),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickRecurringTime,
                icon: const Icon(Icons.access_time),
                label: Text(_recurringTime == null
                    ? 'Pick departure time'
                    : _formatTimeOfDay(_recurringTime!)),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _seatsController,
                    decoration: const InputDecoration(labelText: 'Seats'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _priceController,
                    decoration: const InputDecoration(labelText: 'Price per seat (GH₵)'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _carModelController,
              decoration: const InputDecoration(labelText: 'Car model (optional)'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _carColorController,
                    decoration: const InputDecoration(labelText: 'Color (optional)'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _plateController,
                    decoration: const InputDecoration(labelText: 'Plate number (optional)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _ghanaCardController,
              decoration: const InputDecoration(labelText: 'Ghana Card number (optional)'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickGhanaCard,
              icon: const Icon(Icons.badge_outlined),
              label: Text(_ghanaCardImage == null ? 'Upload Ghana Card photo' : 'Ghana Card selected ✓'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickPhotos,
              icon: const Icon(Icons.photo_camera_outlined),
              label: Text(_photos.isEmpty ? 'Add photos' : '${_photos.length} photo(s) selected'),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              child: _submitting
                  ? const SizedBox(
                      height: 20, width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Add Ride'),
            ),
          ],
        ),
      ),
    );
  }
}
