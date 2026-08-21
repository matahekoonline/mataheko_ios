import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../utils/photo_picker_helper.dart';
import '../../models/hotel.dart';
import '../../services/auth_service.dart';

/// Admin utility screen for directly adding a Hotel entry. Mirrors
/// AddElectricianScreen/AddTilerScreen's structure, adapted for the
/// hotel-specific fields people actually want to check before calling to
/// book: room types, price range, amenities, check-in/out times, and
/// whether walk-ins are accepted. Unlike every other add-provider screen,
/// this one supports multiple property photos rather than a single
/// profile photo.
///
/// New entries still start isPending: true and need one tap on "Approve"
/// back on HotelsScreen before they show up publicly.
class AddHotelScreen extends StatefulWidget {
  const AddHotelScreen({super.key});

  @override
  State<AddHotelScreen> createState() => _AddHotelScreenState();
}

class _AddHotelScreenState extends State<AddHotelScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _businessController = TextEditingController();
  final _areaController = TextEditingController();
  final _minPriceController = TextEditingController();
  final _maxPriceController = TextEditingController();
  final _roomsController = TextEditingController();
  final _ghanaCardController = TextEditingController();

  final Set<String> _selectedRoomTypes = {};
  final Set<String> _selectedAmenities = {};

  TimeOfDay? _checkInTime;
  TimeOfDay? _checkOutTime;

  bool _offersFreeBreakfast = false;
  bool _offersAirportPickup = false;
  bool _acceptsWalkIns = true;

  final List<File> _photos = [];
  File? _ghanaCardImage;
  final _picker = ImagePicker();

  bool _loading = false;
  String? _error;

  Future<void> _addPhotosFromGallery() async {
    final picked = await _picker.pickMultiImage(imageQuality: 80);
    if (picked.isNotEmpty) {
      setState(() => _photos.addAll(picked.map((x) => File(x.path))));
    }
  }

  Future<void> _addPhotoFromCamera() async {
    final picked = await pickImageFromCameraOrGallery(context, imageQuality: 80);
    if (picked != null) setState(() => _photos.add(File(picked.path)));
  }

  void _removePhoto(int index) => setState(() => _photos.removeAt(index));

  Future<void> _pickGhanaCardImage() async {
    final picked = await pickImageFromCameraOrGallery(context, imageQuality: 80);
    if (picked != null) setState(() => _ghanaCardImage = File(picked.path));
  }

  Future<void> _pickCheckInTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _checkInTime ?? const TimeOfDay(hour: 12, minute: 0),
    );
    if (picked != null) setState(() => _checkInTime = picked);
  }

  Future<void> _pickCheckOutTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _checkOutTime ?? const TimeOfDay(hour: 11, minute: 0),
    );
    if (picked != null) setState(() => _checkOutTime = picked);
  }

  String _formatTime(TimeOfDay? t) {
    if (t == null) return 'Not set';
    final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final minute = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  Widget _chipSection(String title, List<String> options, Set<String> selected) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((opt) {
            final isSelected = selected.contains(opt);
            return FilterChip(
              label: Text(opt, style: const TextStyle(fontSize: 12)),
              selected: isSelected,
              onSelected: (val) {
                setState(() {
                  if (val) {
                    selected.add(opt);
                  } else {
                    selected.remove(opt);
                  }
                });
              },
              selectedColor: Colors.indigo[100],
              checkmarkColor: Colors.indigo[800],
            );
          }).toList(),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedRoomTypes.isEmpty) {
      setState(() => _error = 'Select at least one room type.');
      return;
    }
    if (_photos.isEmpty) {
      setState(() => _error = 'Add at least one photo of the property.');
      return;
    }

    final minPrice = double.tryParse(_minPriceController.text.trim()) ?? 0;
    final maxPrice = double.tryParse(_maxPriceController.text.trim()) ?? 0;
    if (maxPrice < minPrice) {
      setState(() => _error = 'Max price can\'t be lower than min price.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await AuthService.instance.addHotelByAdmin(
        fullName: _nameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        businessName: _businessController.text.trim(),
        stationArea: _areaController.text.trim(),
        roomTypes: _selectedRoomTypes.toList(),
        amenities: _selectedAmenities.toList(),
        priceRangeMin: minPrice,
        priceRangeMax: maxPrice,
        numberOfRooms: int.tryParse(_roomsController.text.trim()) ?? 0,
        checkInTime: _formatTime(_checkInTime),
        checkOutTime: _formatTime(_checkOutTime),
        offersFreeBreakfast: _offersFreeBreakfast,
        offersAirportPickup: _offersAirportPickup,
        acceptsWalkIns: _acceptsWalkIns,
        photos: _photos,
        ghanaCardNumber: _ghanaCardController.text.trim(),
        ghanaCardImage: _ghanaCardImage,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hotel added — approve it from the list to make it public.')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      // ignore: avoid_print
      print('[AddHotelScreen] Save failed: $e');
      if (!mounted) return;
      setState(() => _error = 'Failed to save hotel: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _businessController.dispose();
    _areaController.dispose();
    _minPriceController.dispose();
    _maxPriceController.dispose();
    _roomsController.dispose();
    _ghanaCardController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Hotel')),
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

                // ---------------------------------------------------------
                // Photos -- the one field on this screen that differs most
                // from the other add-provider screens: a gallery of
                // property photos instead of a single profile photo.
                // ---------------------------------------------------------
                Text('Property Photos', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(
                  'Add a few photos of the hotel — exterior, rooms, common areas.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 10),
                if (_photos.isNotEmpty)
                  SizedBox(
                    height: 100,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _photos.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        return Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.file(
                                _photos[index],
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 2,
                              right: 2,
                              child: GestureDetector(
                                onTap: () => _removePhoto(index),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close, size: 14, color: Colors.white),
                                ),
                              ),
                            ),
                            if (index == 0)
                              Positioned(
                                bottom: 2,
                                left: 2,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text('Cover', style: TextStyle(fontSize: 9, color: Colors.white)),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                if (_photos.isNotEmpty) const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _addPhotosFromGallery,
                        icon: const Icon(Icons.photo_library_outlined, size: 18),
                        label: const Text('Add from gallery'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _addPhotoFromCamera,
                        icon: const Icon(Icons.camera_alt_outlined, size: 18),
                        label: const Text('Take photo'),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Contact Person Name', border: OutlineInputBorder()),
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
                  controller: _businessController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Hotel Name',
                    hintText: 'e.g. Mataheko Gardens Hotel',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _areaController,
                  decoration: const InputDecoration(
                    labelText: 'Area / Location',
                    hintText: 'e.g. Afienya junction',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),

                const SizedBox(height: 20),
                Text('Price Range Per Night (GHS)', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _minPriceController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Min', border: OutlineInputBorder()),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _maxPriceController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Max', border: OutlineInputBorder()),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),
                TextFormField(
                  controller: _roomsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Number of Rooms', border: OutlineInputBorder()),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),

                const SizedBox(height: 20),
                Text('Check-in / Check-out', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _pickCheckInTime,
                        child: Text('Check-in: ${_formatTime(_checkInTime)}'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _pickCheckOutTime,
                        child: Text('Check-out: ${_formatTime(_checkOutTime)}'),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),
                _chipSection('Room Types Available', hotelRoomTypeOptions, _selectedRoomTypes),
                const SizedBox(height: 20),
                _chipSection('Amenities', hotelAmenityOptions, _selectedAmenities),

                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Free Breakfast Included', style: TextStyle(fontSize: 13)),
                  value: _offersFreeBreakfast,
                  activeColor: Colors.indigo[700],
                  onChanged: (val) => setState(() => _offersFreeBreakfast = val),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Offers Airport Pickup', style: TextStyle(fontSize: 13)),
                  value: _offersAirportPickup,
                  activeColor: Colors.indigo[700],
                  onChanged: (val) => setState(() => _offersAirportPickup = val),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Accepts Walk-ins (no booking needed)', style: TextStyle(fontSize: 13)),
                  value: _acceptsWalkIns,
                  activeColor: Colors.indigo[700],
                  onChanged: (val) => setState(() => _acceptsWalkIns = val),
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
                  onPressed: _loading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _loading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Save Hotel'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
