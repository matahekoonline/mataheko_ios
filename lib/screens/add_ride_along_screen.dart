import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/auth_service.dart';

/// Driver self-registration: "Offer a Ride". Posts to Firestore as
/// isPending: true / isApproved: false -- same Ghana-Card-gated approval
/// flow as every other provider category. Supports both a one-time trip
/// and a recurring weekday/weekend commute.
class AddRideAlongScreen extends StatefulWidget {
  const AddRideAlongScreen({super.key});

  @override
  State<AddRideAlongScreen> createState() => _AddRideAlongScreenState();
}

class _AddRideAlongScreenState extends State<AddRideAlongScreen> {
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

  String _rideType = 'oneTime'; // 'oneTime' | 'recurring'
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
    if (picked.isNotEmpty) {
      setState(() => _photos.addAll(picked.map((x) => File(x.path))));
    }
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
    setState(() {
      _departureDateTime =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
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

    if (_rideType == 'oneTime' && _departureDateTime == null) {
      _showError('Please pick a departure date and time.');
      return;
    }
    if (_rideType == 'recurring' && (_selectedDays.isEmpty || _recurringTime == null)) {
      _showError('Please pick the days and time for your recurring commute.');
      return;
    }
    if (_ghanaCardController.text.trim().isEmpty) {
      _showError('Ghana Card number is required for driver verification.');
      return;
    }

    setState(() => _submitting = true);
    try {
      await AuthService.instance.registerAsRideAlongDriver(
        driverName: _driverNameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        fromArea: _fromController.text.trim(),
        toArea: _toController.text.trim(),
        stationArea: _stationController.text.trim(),
        rideType: _rideType,
        departureDateTime: _rideType == 'oneTime' ? _departureDateTime : null,
        departureTime: _rideType == 'recurring' ? _formatTimeOfDay(_recurringTime!) : null,
        recurringDays: _rideType == 'recurring' ? _selectedDays.toList() : const [],
        seatsTotal: int.tryParse(_seatsController.text.trim()) ?? 1,
        pricePerSeat: double.tryParse(_priceController.text.trim()) ?? 0,
        carModel: _carModelController.text.trim().isEmpty ? null : _carModelController.text.trim(),
        carColor: _carColorController.text.trim().isEmpty ? null : _carColorController.text.trim(),
        plateNumber: _plateController.text.trim().isEmpty ? null : _plateController.text.trim(),
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        ghanaCardNumber: _ghanaCardController.text.trim(),
        ghanaCardImage: _ghanaCardImage,
        photos: _photos,
      );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ride submitted! It will appear once an admin verifies your details.'),
        ),
      );
    } catch (e) {
      _showError('Could not post ride: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Offer a Ride')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Your details', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextFormField(
              controller: _driverNameController,
              decoration: const InputDecoration(labelText: 'Full name'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'Phone number'),
              keyboardType: TextInputType.phone,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 24),

            Text('Route', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextFormField(
              controller: _fromController,
              decoration: const InputDecoration(labelText: 'From (e.g. Mataheko)'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _toController,
              decoration: const InputDecoration(labelText: 'To (e.g. Tema Station)'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _stationController,
              decoration: const InputDecoration(labelText: 'Pickup point / landmark'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 24),

            Text('Schedule', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'oneTime', label: Text('One-time trip'), icon: Icon(Icons.event)),
                ButtonSegment(value: 'recurring', label: Text('Recurring commute'), icon: Icon(Icons.repeat)),
              ],
              selected: {_rideType},
              onSelectionChanged: (s) => setState(() => _rideType = s.first),
            ),
            const SizedBox(height: 12),
            if (_rideType == 'oneTime')
              OutlinedButton.icon(
                onPressed: _pickOneTimeDate,
                icon: const Icon(Icons.calendar_today),
                label: Text(_departureDateTime == null
                    ? 'Pick date & time'
                    : _departureDateTime.toString()),
              )
            else ...[
              Wrap(
                spacing: 8,
                children: _weekDays.map((day) {
                  final selected = _selectedDays.contains(day);
                  return FilterChip(
                    label: Text(day),
                    selected: selected,
                    onSelected: (v) => setState(
                        () => v ? _selectedDays.add(day) : _selectedDays.remove(day)),
                  );
                }).toList(),
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
            const SizedBox(height: 24),

            Text('Car & pricing', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _seatsController,
                    decoration: const InputDecoration(labelText: 'Seats available'),
                    keyboardType: TextInputType.number,
                    validator: (v) => (v == null || int.tryParse(v.trim()) == null)
                        ? 'Enter a number'
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _priceController,
                    decoration: const InputDecoration(labelText: 'Price per seat (GH₵)'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) => (v == null || double.tryParse(v.trim()) == null)
                        ? 'Enter an amount'
                        : null,
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
            const SizedBox(height: 24),

            Text('Verification', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextFormField(
              controller: _ghanaCardController,
              decoration: const InputDecoration(labelText: 'Ghana Card number'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
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
              label: Text(_photos.isEmpty
                  ? 'Add car / profile photos'
                  : '${_photos.length} photo(s) selected'),
            ),
            const SizedBox(height: 28),

            FilledButton(
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Submit for Review'),
            ),
          ],
        ),
      ),
    );
  }
}
