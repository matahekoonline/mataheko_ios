import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/auth_service.dart';
import '../services/photo_upload_service.dart';
import '../utils/photo_picker_helper.dart';

/// Category-aware provider onboarding.
///
/// The common identity/verification fields are shared, while the professional
/// section changes according to the selected category. The field names below
/// match the category registration shapes already exposed by AuthService.
class ProviderRegistrationScreen extends StatefulWidget {
  final String categoryId;
  final String categoryName;

  const ProviderRegistrationScreen({
    super.key,
    required this.categoryId,
    required this.categoryName,
  });

  @override
  State<ProviderRegistrationScreen> createState() =>
      _ProviderRegistrationScreenState();
}

class _ProviderRegistrationScreenState
    extends State<ProviderRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();

  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _business = TextEditingController();
  final _location = TextEditingController();
  final _experience = TextEditingController();
  final _qualification = TextEditingController();
  final _ghanaCard = TextEditingController();

  // Generic/specialized text fields.
  final _description = TextEditingController();
  final _specialties = TextEditingController();
  final _services = TextEditingController();
  final _materials = TextEditingController();
  final _vehicleTypes = TextEditingController();
  final _brands = TextEditingController();
  final _subjects = TextEditingController();
  final _classLevels = TextEditingController();
  final _propertyTypes = TextEditingController();
  final _fixtureBrands = TextEditingController();
  final _garmentTypes = TextEditingController();
  final _fabricSpecialties = TextEditingController();
  final _rebarSizes = TextEditingController();
  final _cuisineTypes = TextEditingController();
  final _deliveryAreas = TextEditingController();
  final _roomTypes = TextEditingController();
  final _amenities = TextEditingController();
  final _priceMin = TextEditingController();
  final _priceMax = TextEditingController();
  final _numberOfRooms = TextEditingController();
  final _checkIn = TextEditingController(text: '2:00 PM');
  final _checkOut = TextEditingController(text: '12:00 PM');
  final _propertyTitle = TextEditingController();
  final _roomType = TextEditingController();
  final _rentPrice = TextEditingController();
  final _rentPeriod = TextEditingController(text: 'Monthly');
  final _eventTypes = TextEditingController();
  final _eventServices = TextEditingController();
  final _routeFrom = TextEditingController();
  final _routeTo = TextEditingController();
  final _vehicle = TextEditingController();
  final _plateNumber = TextEditingController();
  final _station = TextEditingController();
  final _motorcycleTypes = TextEditingController();

  final Set<String> _selectedSpecialties = {};
  final Set<String> _selectedMaterials = {};
  final Set<String> _selectedServices = {};
  final Set<String> _selectedVehicleTypes = {};
  final Set<String> _selectedSubjects = {};
  final Set<String> _selectedClassLevels = {};
  final Set<String> _selectedCuisineTypes = {};
  final Set<String> _selectedRoomTypes = {};
  final Set<String> _selectedAmenities = {};

  bool _offersOnSite = false;
  bool _offersEmergency = false;
  bool _offersRoadside = false;
  bool _offersRush = false;
  bool _offersHomeTutoring = false;
  bool _offersOnlineTutoring = false;
  bool _offersDelivery = false;
  bool _offersBreakfast = false;
  bool _offersAirportPickup = false;
  bool _acceptsWalkIns = false;

  File? _profilePhoto;
  File? _ghanaCardPhoto;
  final List<File> _businessPhotos = [];
  bool _submitting = false;

  @override
  void dispose() {
    for (final c in [
      _name, _phone, _business, _location, _experience, _qualification,
      _ghanaCard, _description, _specialties, _services, _materials,
      _vehicleTypes, _brands, _subjects, _classLevels, _propertyTypes,
      _fixtureBrands, _garmentTypes, _fabricSpecialties, _rebarSizes,
      _cuisineTypes, _deliveryAreas, _roomTypes, _amenities, _priceMin,
      _priceMax, _numberOfRooms, _checkIn, _checkOut, _propertyTitle,
      _roomType, _rentPrice, _rentPeriod, _eventTypes, _eventServices,
      _routeFrom, _routeTo, _vehicle, _plateNumber, _station,
      _motorcycleTypes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String get category => widget.categoryName.trim();

  List<String> _csv(String value) => value
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toSet()
      .toList();

  bool _is(String value) => category.toLowerCase() == value.toLowerCase();

  Future<void> _pickProfilePhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
    );
    if (picked != null && mounted) {
      setState(() => _profilePhoto = File(picked.path));
    }
  }

  Future<void> _pickGhanaCard() async {
    final picked = await pickImageFromCameraOrGallery(
      context,
      imageQuality: 82,
    );
    if (picked != null && mounted) {
      setState(() => _ghanaCardPhoto = File(picked.path));
    }
  }

  Future<void> _pickBusinessPhotos() async {
    final remaining = 4 - _businessPhotos.length;
    if (remaining <= 0) return;

    final picked = await ImagePicker().pickMultiImage(imageQuality: 82);
    if (!mounted) return;

    setState(() {
      for (final x in picked.take(remaining)) {
        _businessPhotos.add(File(x.path));
      }
    });
  }

  InputDecoration _decoration(String label, {String? hint}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        filled: true,
      );

  Widget _text(
    TextEditingController controller,
    String label, {
    String? hint,
    bool required = false,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: _decoration(label, hint: hint),
        validator: required
            ? (v) => v == null || v.trim().isEmpty ? 'Required' : null
            : null,
      ),
    );
  }

  Widget _chips(
    String title,
    List<String> options,
    Set<String> selected, {
    bool required = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          if (required)
            const Padding(
              padding: EdgeInsets.only(top: 3),
              child: Text('Select at least one', style: TextStyle(fontSize: 12)),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((option) {
              return FilterChip(
                label: Text(option),
                selected: selected.contains(option),
                onSelected: (value) {
                  setState(() {
                    if (value) {
                      selected.add(option);
                    } else {
                      selected.remove(option);
                    }
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _switch(String title, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }

  List<Widget> _professionalFields() {
    if (_is('Teacher')) {
      return [
        _text(_business, 'School / institution', required: true),
        _text(_qualification, 'Teaching qualification / credential', required: true),
        _chips('Subjects taught', const ['English', 'Mathematics', 'Science', 'ICT', 'Social Studies', 'French', 'Accounting', 'Economics'], _selectedSubjects, required: true),
        _chips('Class levels taught', const ['KG', 'Primary', 'JHS', 'SHS', 'Tertiary', 'Adult Education'], _selectedClassLevels, required: true),
        _switch('Offers home tutoring', _offersHomeTutoring, (v) => setState(() => _offersHomeTutoring = v)),
        _switch('Offers online tutoring', _offersOnlineTutoring, (v) => setState(() => _offersOnlineTutoring = v)),
      ];
    }

    if (_is('Mechanic')) {
      return [
        _text(_business, 'Workshop name', required: true),
        _chips('Vehicle types', const ['Cars', 'SUVs', 'Trucks', 'Buses', 'Motorcycles', 'Commercial Vehicles'], _selectedVehicleTypes, required: true),
        _text(_brands, 'Brand specialties', hint: 'Toyota, Nissan, Mercedes...'),
        _text(_services, 'Services offered', hint: 'Oil change, diagnostics, engine repair...', maxLines: 3),
        _switch('Offers roadside service', _offersRoadside, (v) => setState(() => _offersRoadside = v)),
      ];
    }

    if (_is('Electrician')) {
      return [
        _text(_business, 'Business name', required: true),
        _text(_propertyTypes, 'Property types serviced', hint: 'Homes, shops, offices, factories...'),
        _text(_services, 'Services offered', hint: 'Wiring, sockets, lighting, installations...', maxLines: 3),
        _switch('Offers emergency service', _offersEmergency, (v) => setState(() => _offersEmergency = v)),
      ];
    }

    if (_is('Plumber')) {
      return [
        _text(_business, 'Business name', required: true),
        _text(_propertyTypes, 'Property types serviced', hint: 'Homes, offices, shops...'),
        _text(_fixtureBrands, 'Fixture / equipment brands', hint: 'GROHE, Roca, local brands...'),
        _text(_services, 'Services offered', hint: 'Pipe repair, installation, drainage...', maxLines: 3),
        _switch('Offers emergency service', _offersEmergency, (v) => setState(() => _offersEmergency = v)),
      ];
    }

    if (_is('Carpenter')) {
      return [
        _text(_business, 'Workshop name', required: true),
        _text(_specialties, 'Specialties', hint: 'Furniture, roofing, doors, cabinets...'),
        _text(_materials, 'Materials worked with', hint: 'Mahogany, plywood, MDF...'),
        _text(_services, 'Services offered', maxLines: 3),
        _switch('Offers on-site service', _offersOnSite, (v) => setState(() => _offersOnSite = v)),
      ];
    }

    if (_is('Tailor')) {
      return [
        _text(_business, 'Business name', required: true),
        _text(_garmentTypes, 'Garment types serviced', hint: 'Dresses, suits, uniforms, traditional wear...'),
        _text(_fabricSpecialties, 'Fabric specialties', hint: 'Kente, lace, cotton, silk...'),
        _text(_services, 'Services offered', maxLines: 3),
        _switch('Offers rush service', _offersRush, (v) => setState(() => _offersRush = v)),
      ];
    }

    if (_is('Tiler')) {
      return [
        _text(_business, 'Business name', required: true),
        _text(_specialties, 'Tile specialties', hint: 'Floor, wall, bathroom, outdoor...'),
        _text(_materials, 'Materials worked with', hint: 'Ceramic, porcelain, marble...'),
        _text(_services, 'Services offered', maxLines: 3),
        _switch('Offers on-site consultation', _offersOnSite, (v) => setState(() => _offersOnSite = v)),
      ];
    }

    if (_is('Welder')) {
      return [
        _text(_business, 'Business name', required: true),
        _text(_specialties, 'Welding specialties', hint: 'Gate fabrication, structural steel, grills...'),
        _text(_materials, 'Materials worked with', hint: 'Mild steel, stainless steel, aluminium...'),
        _text(_services, 'Services offered', maxLines: 3),
        _switch('Offers on-site service', _offersOnSite, (v) => setState(() => _offersOnSite = v)),
      ];
    }

    if (_is('Steel Bender')) {
      return [
        _text(_business, 'Workshop name', required: true),
        _text(_specialties, 'Specialties', hint: 'Structural work, reinforcement, fabrication...'),
        _text(_rebarSizes, 'Rebar sizes handled', hint: '8mm, 10mm, 12mm, 16mm...'),
        _switch('Offers on-site service', _offersOnSite, (v) => setState(() => _offersOnSite = v)),
      ];
    }

    if (_is('Home Food')) {
      return [
        _text(_business, 'Food business name', required: true),
        _chips('Cuisine types', const ['Ghanaian', 'Continental', 'Local Soups', 'Pastries', 'Grills', 'Healthy Meals', 'Breakfast'], _selectedCuisineTypes, required: true),
        _text(_deliveryAreas, 'Delivery areas', hint: 'Mataheko, Kaneshie, Odorkor...'),
        _switch('Offers delivery', _offersDelivery, (v) => setState(() => _offersDelivery = v)),
        _text(_description, 'Menu / dishes', hint: 'One per line: Dish | Price | Description', maxLines: 6),
      ];
    }

    if (_is('Hotel')) {
      return [
        _text(_business, 'Hotel / accommodation name', required: true),
        _chips('Room types', const ['Single', 'Double', 'Twin', 'Deluxe', 'Suite', 'Family'], _selectedRoomTypes, required: true),
        _chips('Amenities', const ['Wi-Fi', 'Parking', 'Restaurant', 'Pool', 'Air Conditioning', 'Conference Room', 'Gym'], _selectedAmenities),
        _text(_priceMin, 'Minimum room price', keyboardType: TextInputType.number, required: true),
        _text(_priceMax, 'Maximum room price', keyboardType: TextInputType.number, required: true),
        _text(_numberOfRooms, 'Number of rooms', keyboardType: TextInputType.number, required: true),
        _text(_checkIn, 'Check-in time', required: true),
        _text(_checkOut, 'Check-out time', required: true),
        _switch('Offers free breakfast', _offersBreakfast, (v) => setState(() => _offersBreakfast = v)),
        _switch('Offers airport pickup', _offersAirportPickup, (v) => setState(() => _offersAirportPickup = v)),
        _switch('Accepts walk-ins', _acceptsWalkIns, (v) => setState(() => _acceptsWalkIns = v)),
      ];
    }

    if (_is('Room for Rent')) {
      return [
        _text(_propertyTitle, 'Property title', required: true),
        _text(_roomType, 'Room type', hint: 'Single room, chamber & hall, self-contained...', required: true),
        _text(_rentPrice, 'Rent price', keyboardType: TextInputType.number, required: true),
        _text(_rentPeriod, 'Rent period', required: true),
        _text(_amenities, 'Amenities', hint: 'Water, electricity, kitchen, parking...'),
        _text(_description, 'Property description', maxLines: 5),
      ];
    }

    if (_is('Okada') || _is('Aboboyaa')) {
      return [
        _text(_plateNumber, 'Number plate', required: true),
        _text(_station, 'Station name', required: true),
        _text(_vehicle, _is('Okada') ? 'Motorcycle / bike details' : 'Tricycle details'),
      ];
    }

    if (_is('Motor Mechanic')) {
      return [
        _text(_business, 'Workshop name', required: true),
        _text(_motorcycleTypes, 'Motorcycle types serviced', hint: 'Honda, Yamaha, Haojue...'),
        _text(_services, 'Services offered', maxLines: 3),
      ];
    }

    if (_is('Event Planner')) {
      return [
        _text(_business, 'Business / planner name', required: true),
        _text(_eventTypes, 'Event types', hint: 'Weddings, birthdays, funerals, corporate events...'),
        _text(_eventServices, 'Services offered', hint: 'Decor, coordination, catering, MC...', maxLines: 3),
      ];
    }

    if (_is('Ride Along')) {
      return [
        _text(_routeFrom, 'Typical route / pickup area', required: true),
        _text(_routeTo, 'Typical destination / drop-off area', required: true),
        _text(_vehicle, 'Vehicle details', required: true),
        _text(_plateNumber, 'Vehicle number plate', required: true),
      ];
    }

    if (_is('Mason')) {
      return [
        _text(_business, 'Business / professional name'),
        _text(_specialties, 'Construction specialties', hint: 'Block work, plastering, foundations...'),
        _text(_materials, 'Materials / systems worked with'),
        _text(_services, 'Services offered', maxLines: 3),
        _switch('Offers on-site service', _offersOnSite, (v) => setState(() => _offersOnSite = v)),
      ];
    }

    return [
      _text(_business, 'Business / professional name'),
      _text(_specialties, 'Specialties'),
      _text(_services, 'Services offered', maxLines: 3),
      _text(_description, 'Professional description', maxLines: 4),
      _switch('Offers on-site service', _offersOnSite, (v) => setState(() => _offersOnSite = v)),
    ];
  }

  Map<String, dynamic> _specializedData() {
    final data = <String, dynamic>{};

    if (_is('Teacher')) {
      data.addAll({
        'schoolOrInstitution': _business.text.trim(),
        'qualification': _qualification.text.trim(),
        'subjectsTaught': _selectedSubjects.isNotEmpty ? _selectedSubjects.toList() : _csv(_subjects.text),
        'classLevelsTaught': _selectedClassLevels.isNotEmpty ? _selectedClassLevels.toList() : _csv(_classLevels.text),
        'offersHomeTutoring': _offersHomeTutoring,
        'offersOnlineTutoring': _offersOnlineTutoring,
      });
    } else if (_is('Mechanic')) {
      data.addAll({'workshopName': _business.text.trim(), 'vehicleTypes': _selectedVehicleTypes.toList(), 'brandSpecialties': _csv(_brands.text), 'servicesOffered': _csv(_services.text), 'offersRoadsideService': _offersRoadside});
    } else if (_is('Electrician')) {
      data.addAll({'businessName': _business.text.trim(), 'propertyTypesServiced': _csv(_propertyTypes.text), 'servicesOffered': _csv(_services.text), 'offersEmergencyService': _offersEmergency});
    } else if (_is('Plumber')) {
      data.addAll({'businessName': _business.text.trim(), 'propertyTypesServiced': _csv(_propertyTypes.text), 'fixtureBrands': _csv(_fixtureBrands.text), 'servicesOffered': _csv(_services.text), 'offersEmergencyService': _offersEmergency});
    } else if (_is('Carpenter')) {
      data.addAll({'workshopName': _business.text.trim(), 'specialties': _csv(_specialties.text), 'materialsWorkedWith': _csv(_materials.text), 'servicesOffered': _csv(_services.text), 'offersOnSiteService': _offersOnSite});
    } else if (_is('Tailor')) {
      data.addAll({'businessName': _business.text.trim(), 'garmentTypesServiced': _csv(_garmentTypes.text), 'fabricSpecialties': _csv(_fabricSpecialties.text), 'servicesOffered': _csv(_services.text), 'offersRushService': _offersRush});
    } else if (_is('Tiler')) {
      data.addAll({'businessName': _business.text.trim(), 'specialtiesServiced': _csv(_specialties.text), 'materialsWorkedWith': _csv(_materials.text), 'servicesOffered': _csv(_services.text), 'offersOnSiteConsultation': _offersOnSite});
    } else if (_is('Welder')) {
      data.addAll({'businessName': _business.text.trim(), 'specialtiesServiced': _csv(_specialties.text), 'materialsWorkedWith': _csv(_materials.text), 'servicesOffered': _csv(_services.text), 'offersOnSiteService': _offersOnSite});
    } else if (_is('Steel Bender')) {
      data.addAll({'workshopName': _business.text.trim(), 'specialties': _csv(_specialties.text), 'rebarSizesHandled': _csv(_rebarSizes.text), 'offersOnSiteService': _offersOnSite});
    } else if (_is('Home Food')) {
      final menu = _description.text
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .map((line) {
            final p = line.split('|').map((e) => e.trim()).toList();
            return {'name': p.isNotEmpty ? p[0] : line, 'price': p.length > 1 ? double.tryParse(p[1]) ?? 0 : 0, 'description': p.length > 2 ? p[2] : ''};
          })
          .toList();
      data.addAll({'businessName': _business.text.trim(), 'cuisineTypes': _selectedCuisineTypes.toList(), 'deliveryAreas': _csv(_deliveryAreas.text), 'offersDelivery': _offersDelivery, 'menu': menu});
    } else if (_is('Hotel')) {
      data.addAll({'businessName': _business.text.trim(), 'roomTypes': _selectedRoomTypes.toList(), 'amenities': _selectedAmenities.toList(), 'priceRangeMin': double.tryParse(_priceMin.text) ?? 0, 'priceRangeMax': double.tryParse(_priceMax.text) ?? 0, 'numberOfRooms': int.tryParse(_numberOfRooms.text) ?? 0, 'checkInTime': _checkIn.text.trim(), 'checkOutTime': _checkOut.text.trim(), 'offersFreeBreakfast': _offersBreakfast, 'offersAirportPickup': _offersAirportPickup, 'acceptsWalkIns': _acceptsWalkIns});
    } else if (_is('Room for Rent')) {
      data.addAll({'landlordName': _name.text.trim(), 'propertyTitle': _propertyTitle.text.trim(), 'roomType': _roomType.text.trim(), 'price': double.tryParse(_rentPrice.text) ?? 0, 'rentPeriod': _rentPeriod.text.trim(), 'amenities': _csv(_amenities.text), 'description': _description.text.trim(), 'isAvailable': true});
    } else if (_is('Okada') || _is('Aboboyaa')) {
      data.addAll({'numberPlate': _plateNumber.text.trim(), 'stationName': _station.text.trim(), 'vehicleDetails': _vehicle.text.trim()});
    } else if (_is('Motor Mechanic')) {
      data.addAll({'workshopName': _business.text.trim(), 'motorcycleTypes': _csv(_motorcycleTypes.text), 'servicesOffered': _csv(_services.text)});
    } else if (_is('Event Planner')) {
      data.addAll({'businessName': _business.text.trim(), 'eventTypes': _csv(_eventTypes.text), 'servicesOffered': _csv(_eventServices.text)});
    } else if (_is('Ride Along')) {
      data.addAll({'routeFrom': _routeFrom.text.trim(), 'routeTo': _routeTo.text.trim(), 'vehicleDetails': _vehicle.text.trim(), 'numberPlate': _plateNumber.text.trim()});
    } else if (_is('Mason')) {
      data.addAll({'businessName': _business.text.trim(), 'specialties': _csv(_specialties.text), 'materialsWorkedWith': _csv(_materials.text), 'servicesOffered': _csv(_services.text), 'offersOnSiteService': _offersOnSite});
    } else {
      data.addAll({'businessName': _business.text.trim(), 'specialties': _csv(_specialties.text), 'servicesOffered': _csv(_services.text), 'description': _description.text.trim(), 'offersOnSiteService': _offersOnSite});
    }

    return data;
  }


  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_ghanaCardPhoto == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please take a photo of your Ghana Card.')));
      return;
    }

    if (_is('Teacher') && _selectedSubjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select at least one subject.')));
      return;
    }
    if (_is('Teacher') && _selectedClassLevels.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select at least one class level.')));
      return;
    }
    if (_is('Mechanic') && _selectedVehicleTypes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select at least one vehicle type.')));
      return;
    }
    if (_is('Hotel') && (_selectedRoomTypes.isEmpty || _selectedAmenities.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select room types and at least one amenity.')));
      return;
    }
    if (_is('Home Food') && _selectedCuisineTypes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select at least one cuisine type.')));
      return;
    }

    setState(() => _submitting = true);

    try {
      final uid = AuthService.instance.currentUser?.uid;
      if (uid == null) throw Exception('No signed-in user.');

      final ghanaCardUrl = await PhotoUploadService.uploadGhanaCardPhoto(uid: uid, photo: _ghanaCardPhoto!);
      String? profileUrl;
      if (_profilePhoto != null) {
        profileUrl = await PhotoUploadService.uploadProfilePhoto(uid: uid, photo: _profilePhoto!);
      }

      final businessPhotoUrls = <String>[];
      if (_businessPhotos.isNotEmpty) {
        for (var i = 0; i < _businessPhotos.length; i++) {
          final url = await PhotoUploadService.uploadListingPhoto(
            uid: '${uid}_provider_$i',
            photo: _businessPhotos[i],
          );
          businessPhotoUrls.add(url);
        }
      }

      final specialized = _specializedData();
      if (businessPhotoUrls.isNotEmpty) {
        specialized['photoUrls'] = businessPhotoUrls;
      }

      await AuthService.instance.registerProviderFromDashboard(
        category: category,
        fullName: _name.text.trim(),
        phoneNumber: _phone.text.trim(),
        stationArea: _location.text.trim(),
        ghanaCardNumber: _ghanaCard.text.trim(),
        ghanaCardPhotoUrl: ghanaCardUrl,
        photoUrl: profileUrl,
        businessName: _business.text.trim(),
        description: _description.text.trim(),
        yearsOfExperience: int.tryParse(_experience.text.trim()) ?? 0,
        servicesOffered: _csv(_services.text),
        specialties: _csv(_specialties.text),
        extra: specialized,
      );

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: Colors.green, size: 48),
          title: const Text('Registration submitted'),
          content: Text('Your $category provider profile has been submitted and is pending admin verification.'),
          actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done'))],
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not submit registration: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('$category Registration')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _section('Selected provider category', [
                ListTile(leading: const Icon(Icons.verified_user_outlined), title: Text(category), subtitle: const Text('This category is locked for this application.')),
              ]),
              _section('Identity & contact', [
                Center(child: GestureDetector(onTap: _pickProfilePhoto, child: CircleAvatar(radius: 52, backgroundImage: _profilePhoto == null ? null : FileImage(_profilePhoto!), child: _profilePhoto == null ? const Icon(Icons.add_a_photo_outlined, size: 28) : null))),
                const SizedBox(height: 8),
                const Center(child: Text('Professional photo (optional)')),
                const SizedBox(height: 18),
                _text(_name, 'Full name', required: true),
                _text(_phone, 'Phone number', required: true, keyboardType: TextInputType.phone),
                _text(_location, 'Station / area', hint: 'e.g. Mataheko Junction', required: true),
                _text(_experience, 'Years of experience', keyboardType: TextInputType.number),
              ]),
              _section('Professional details', _professionalFields()),
              _section('Identity verification', [
                _text(_ghanaCard, 'Ghana Card number', required: true),
                OutlinedButton.icon(onPressed: _pickGhanaCard, icon: Icon(_ghanaCardPhoto == null ? Icons.camera_alt_outlined : Icons.check_circle), label: Text(_ghanaCardPhoto == null ? 'Take Ghana Card photo' : 'Ghana Card photo captured')),
              ]),
              if (_is('Hotel') || _is('Home Food') || _is('Room for Rent'))
                _section('Business photos', [
                  OutlinedButton.icon(onPressed: _businessPhotos.length >= 4 ? null : _pickBusinessPhotos, icon: const Icon(Icons.photo_library_outlined), label: Text('Add photos (${_businessPhotos.length}/4)')),
                  if (_businessPhotos.isNotEmpty) SizedBox(height: 110, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: _businessPhotos.length, separatorBuilder: (_, __) => const SizedBox(width: 8), itemBuilder: (_, i) => Stack(children: [ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(_businessPhotos[i], width: 110, height: 110, fit: BoxFit.cover)), Positioned(right: 3, top: 3, child: IconButton(onPressed: () => setState(() => _businessPhotos.removeAt(i)), icon: const Icon(Icons.cancel, color: Colors.white)))]))),
                ]),
              FilledButton.icon(onPressed: _submitting ? null : _submit, icon: _submitting ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send_rounded), label: Text(_submitting ? 'Submitting...' : 'Submit for verification'), style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15))),
              const SizedBox(height: 12),
              Text('Verification information is used for security and admin review. It is not editable from the normal account profile.', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            ],
          ),
        ),
      ),
    );
  }
}
