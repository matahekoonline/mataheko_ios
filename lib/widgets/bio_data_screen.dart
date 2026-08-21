import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../utils/photo_picker_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_role.dart';
import '../models/mechanic.dart';
import '../models/steel_bender.dart';
import '../models/electrician.dart';
import '../models/tailor.dart';
import '../models/plumber.dart';

import '../services/auth_service.dart';
import '../services/photo_upload_service.dart';

import '../data/sample_listings.dart';
import '../screens/rider_mode_screen.dart';

class BioDataScreen extends StatefulWidget {
  final UserRole role;

  const BioDataScreen({
    super.key,
    required this.role,
  });

  @override
  State<BioDataScreen> createState() => _BioDataScreenState();
}

class _BioDataScreenState extends State<BioDataScreen> {
  final _formKey = GlobalKey<FormState>();

  // ---------------------------------------------------------------------
  // Basic controllers
  // ---------------------------------------------------------------------

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _areaController = TextEditingController();
  final _ghanaCardController = TextEditingController();
  final _plateController = TextEditingController();
  final _stationController = TextEditingController();

  // ---------------------------------------------------------------------
  // Mechanic
  // ---------------------------------------------------------------------

  final _workshopController = TextEditingController();
  final _experienceController = TextEditingController();

  final Set<String> _selectedVehicleTypes = {};
  final Set<String> _selectedBrands = {};
  final Set<String> _selectedServices = {};

  bool _offersRoadsideService = false;

  // ---------------------------------------------------------------------
  // Steel Bender
  // ---------------------------------------------------------------------

  final Set<String> _selectedSteelSpecialties = {};
  final Set<String> _selectedRebarSizes = {};

  bool _offersOnSiteService = false;

  // ---------------------------------------------------------------------
  // Electrician
  // ---------------------------------------------------------------------

  final Set<String> _selectedPropertyTypes = {};
  final Set<String> _selectedElectricianServices = {};

  bool _offersEmergencyService = false;

  // ---------------------------------------------------------------------
  // Tailor
  // ---------------------------------------------------------------------

  final Set<String> _selectedGarmentTypes = {};
  final Set<String> _selectedFabrics = {};
  final Set<String> _selectedTailoringServices = {};

  bool _offersRushService = false;

  // ---------------------------------------------------------------------
  // Plumber
  // ---------------------------------------------------------------------

  final Set<String> _selectedPlumberPropertyTypes = {};
  final Set<String> _selectedFixtureBrands = {};
  final Set<String> _selectedPlumbingServices = {};

  bool _offersPlumberEmergencyService = false;

  // ---------------------------------------------------------------------
  // Ride Along
  // ---------------------------------------------------------------------

  final _rideFromController = TextEditingController();
  final _rideToController = TextEditingController();
  final _rideStationController = TextEditingController();
  final _rideSeatsController = TextEditingController();
  final _ridePriceController = TextEditingController();
  final _rideCarModelController = TextEditingController();
  final _rideCarColorController = TextEditingController();
  final _rideNotesController = TextEditingController();

  String _rideType = 'oneTime';

  DateTime? _departureDateTime;
  TimeOfDay? _departureTime;

  final Set<String> _recurringDays = {};

  // ---------------------------------------------------------------------
  // Images
  // ---------------------------------------------------------------------

  File? _cardImage;

  // Public/provider photo.
  //
  // For:
  // - Okada = rider photo
  // - Mechanic = mechanic photo
  // - Steel Bender = steel bender photo
  // - Electrician = electrician photo
  // - Tailor = tailor photo
  // - Plumber = plumber photo
  // - Aboboyaa = rider photo
  // - Ride Along = vehicle/driver photo
  File? _providerPhoto;

  // Basic account profile photo.
  File? _profilePhoto;

  String? _selectedCategory;

  bool _loading = false;
  String? _error;

  final _picker = ImagePicker();

  // ---------------------------------------------------------------------
  // Draft persistence
  // ---------------------------------------------------------------------

  static const _draftKey = 'bio_data_draft_v1';

  @override
  void initState() {
    super.initState();
    _restoreDraft();
  }

  Future<void> _saveDraft() async {
    final prefs = await SharedPreferences.getInstance();

    final draft = {
      'name': _nameController.text,
      'phone': _phoneController.text,
      'area': _areaController.text,
      'ghanaCard': _ghanaCardController.text,
      'plate': _plateController.text,
      'station': _stationController.text,

      'workshop': _workshopController.text,
      'experience': _experienceController.text,

      'category': _selectedCategory,

      'vehicleTypes': _selectedVehicleTypes.toList(),
      'brands': _selectedBrands.toList(),
      'services': _selectedServices.toList(),
      'roadside': _offersRoadsideService,

      'steelSpecialties': _selectedSteelSpecialties.toList(),
      'rebarSizes': _selectedRebarSizes.toList(),
      'onSite': _offersOnSiteService,

      'propertyTypes': _selectedPropertyTypes.toList(),
      'electricianServices': _selectedElectricianServices.toList(),
      'emergencyService': _offersEmergencyService,

      'garmentTypes': _selectedGarmentTypes.toList(),
      'fabrics': _selectedFabrics.toList(),
      'tailoringServices': _selectedTailoringServices.toList(),
      'rushService': _offersRushService,

      'plumberPropertyTypes': _selectedPlumberPropertyTypes.toList(),
      'fixtureBrands': _selectedFixtureBrands.toList(),
      'plumbingServices': _selectedPlumbingServices.toList(),
      'plumberEmergencyService': _offersPlumberEmergencyService,

      // Ride Along
      'rideFrom': _rideFromController.text,
      'rideTo': _rideToController.text,
      'rideStation': _rideStationController.text,
      'rideSeats': _rideSeatsController.text,
      'ridePrice': _ridePriceController.text,
      'rideCarModel': _rideCarModelController.text,
      'rideCarColor': _rideCarColorController.text,
      'rideNotes': _rideNotesController.text,
      'rideType': _rideType,
      'recurringDays': _recurringDays.toList(),

      if (_departureDateTime != null)
        'departureDateTime': _departureDateTime!.toIso8601String(),

      if (_departureTime != null)
        'departureHour': _departureTime!.hour,

      if (_departureTime != null)
        'departureMinute': _departureTime!.minute,

      // Images
      'cardImagePath': _cardImage?.path,
      'providerPhotoPath': _providerPhoto?.path,
      'profilePhotoPath': _profilePhoto?.path,
    };

    await prefs.setString(
      _draftKey,
      jsonEncode(draft),
    );
  }

  Future<void> _restoreDraft() async {
    final prefs = await SharedPreferences.getInstance();

    final raw = prefs.getString(_draftKey);

    if (raw == null) return;

    try {
      final draft = jsonDecode(raw) as Map<String, dynamic>;

      _nameController.text = draft['name'] as String? ?? '';
      _phoneController.text = draft['phone'] as String? ?? '';
      _areaController.text = draft['area'] as String? ?? '';
      _ghanaCardController.text = draft['ghanaCard'] as String? ?? '';
      _plateController.text = draft['plate'] as String? ?? '';
      _stationController.text = draft['station'] as String? ?? '';

      _workshopController.text = draft['workshop'] as String? ?? '';
      _experienceController.text = draft['experience'] as String? ?? '';

      _selectedCategory = draft['category'] as String?;

      _selectedVehicleTypes
        ..clear()
        ..addAll(
          List<String>.from(
            draft['vehicleTypes'] as List? ?? const [],
          ),
        );

      _selectedBrands
        ..clear()
        ..addAll(
          List<String>.from(
            draft['brands'] as List? ?? const [],
          ),
        );

      _selectedServices
        ..clear()
        ..addAll(
          List<String>.from(
            draft['services'] as List? ?? const [],
          ),
        );

      _offersRoadsideService =
          draft['roadside'] as bool? ?? false;

      _selectedSteelSpecialties
        ..clear()
        ..addAll(
          List<String>.from(
            draft['steelSpecialties'] as List? ?? const [],
          ),
        );

      _selectedRebarSizes
        ..clear()
        ..addAll(
          List<String>.from(
            draft['rebarSizes'] as List? ?? const [],
          ),
        );

      _offersOnSiteService =
          draft['onSite'] as bool? ?? false;

      _selectedPropertyTypes
        ..clear()
        ..addAll(
          List<String>.from(
            draft['propertyTypes'] as List? ?? const [],
          ),
        );

      _selectedElectricianServices
        ..clear()
        ..addAll(
          List<String>.from(
            draft['electricianServices'] as List? ?? const [],
          ),
        );

      _offersEmergencyService =
          draft['emergencyService'] as bool? ?? false;

      _selectedGarmentTypes
        ..clear()
        ..addAll(
          List<String>.from(
            draft['garmentTypes'] as List? ?? const [],
          ),
        );

      _selectedFabrics
        ..clear()
        ..addAll(
          List<String>.from(
            draft['fabrics'] as List? ?? const [],
          ),
        );

      _selectedTailoringServices
        ..clear()
        ..addAll(
          List<String>.from(
            draft['tailoringServices'] as List? ?? const [],
          ),
        );

      _offersRushService =
          draft['rushService'] as bool? ?? false;

      _selectedPlumberPropertyTypes
        ..clear()
        ..addAll(
          List<String>.from(
            draft['plumberPropertyTypes'] as List? ?? const [],
          ),
        );

      _selectedFixtureBrands
        ..clear()
        ..addAll(
          List<String>.from(
            draft['fixtureBrands'] as List? ?? const [],
          ),
        );

      _selectedPlumbingServices
        ..clear()
        ..addAll(
          List<String>.from(
            draft['plumbingServices'] as List? ?? const [],
          ),
        );

      _offersPlumberEmergencyService =
          draft['plumberEmergencyService'] as bool? ?? false;

      // -----------------------------------------------------------------
      // Restore Ride Along
      // -----------------------------------------------------------------

      _rideFromController.text =
          draft['rideFrom'] as String? ?? '';

      _rideToController.text =
          draft['rideTo'] as String? ?? '';

      _rideStationController.text =
          draft['rideStation'] as String? ?? '';

      _rideSeatsController.text =
          draft['rideSeats'] as String? ?? '';

      _ridePriceController.text =
          draft['ridePrice'] as String? ?? '';

      _rideCarModelController.text =
          draft['rideCarModel'] as String? ?? '';

      _rideCarColorController.text =
          draft['rideCarColor'] as String? ?? '';

      _rideNotesController.text =
          draft['rideNotes'] as String? ?? '';

      _rideType =
          draft['rideType'] as String? ?? 'oneTime';

      _recurringDays
        ..clear()
        ..addAll(
          List<String>.from(
            draft['recurringDays'] as List? ?? const [],
          ),
        );

      final departureDateString =
      draft['departureDateTime'] as String?;

      if (departureDateString != null) {
        _departureDateTime =
            DateTime.tryParse(departureDateString);
      }

      final departureHour =
      draft['departureHour'] as int?;

      final departureMinute =
      draft['departureMinute'] as int?;

      if (departureHour != null && departureMinute != null) {
        _departureTime = TimeOfDay(
          hour: departureHour,
          minute: departureMinute,
        );
      }

      // -----------------------------------------------------------------
      // Restore images
      // -----------------------------------------------------------------

      final cardPath =
      draft['cardImagePath'] as String?;

      final providerPath =
      draft['providerPhotoPath'] as String?;

      final profilePath =
      draft['profilePhotoPath'] as String?;

      if (cardPath != null &&
          File(cardPath).existsSync()) {
        _cardImage = File(cardPath);
      }

      if (providerPath != null &&
          File(providerPath).existsSync()) {
        _providerPhoto = File(providerPath);
      }

      if (profilePath != null &&
          File(profilePath).existsSync()) {
        _profilePhoto = File(profilePath);
      }

      if (mounted) {
        setState(() {});
      }
    } catch (_) {
      // Ignore corrupt drafts.
    }
  }

  Future<void> _clearDraft() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_draftKey);
  }

  // ---------------------------------------------------------------------
  // Category getters
  // ---------------------------------------------------------------------

  bool get _isProvider =>
      widget.role == UserRole.provider;

  bool get _isOkada =>
      _isProvider &&
          _selectedCategory == 'Okada';

  bool get _isAboboyaa =>
      _isProvider &&
          _selectedCategory == 'Aboboyaa';

  bool get _isRideAlong =>
      _isProvider &&
          _selectedCategory == 'Ride Along';

  bool get _isMechanic =>
      _isProvider &&
          _selectedCategory == 'Mechanic';

  bool get _isSteelBender =>
      _isProvider &&
          _selectedCategory == 'Steel Bender';

  bool get _isElectrician =>
      _isProvider &&
          _selectedCategory == 'Electrician';

  bool get _isTailor =>
      _isProvider &&
          _selectedCategory == 'Tailor';

  bool get _isPlumber =>
      _isProvider &&
          _selectedCategory == 'Plumber';

  bool get _needsProviderPhoto =>
      _isOkada ||
          _isAboboyaa ||
          _isRideAlong ||
          _isMechanic ||
          _isSteelBender ||
          _isElectrician ||
          _isTailor ||
          _isPlumber;

  // ---------------------------------------------------------------------
  // Image picking
  // ---------------------------------------------------------------------

  Future<void> _pickProfilePhoto() async {
    await _saveDraft();

    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (picked != null) {
      setState(() {
        _profilePhoto = File(picked.path);
      });

      await _saveDraft();
    }
  }

  Future<void> _pickCardImage() async {
    await _saveDraft();

    final picked = await pickImageFromCameraOrGallery(
      context,
      imageQuality: 80,
    );

    if (picked != null) {
      setState(() {
        _cardImage = File(picked.path);
      });

      await _saveDraft();
    }
  }

  Future<void> _pickProviderPhoto() async {
    await _saveDraft();

    final picked = await pickImageFromCameraOrGallery(
      context,
      imageQuality: 80,
    );

    if (picked != null) {
      setState(() {
        _providerPhoto = File(picked.path);
      });

      await _saveDraft();
    }
  }

  // ---------------------------------------------------------------------
  // Ride Along date/time
  // ---------------------------------------------------------------------

  Future<void> _pickRideDate() async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: DateTime(now.year + 2),
      initialDate: _departureDateTime ?? now,
    );

    if (picked == null) return;

    final currentTime =
        _departureTime ?? TimeOfDay.now();

    setState(() {
      _departureDateTime = DateTime(
        picked.year,
        picked.month,
        picked.day,
        currentTime.hour,
        currentTime.minute,
      );
    });

    await _saveDraft();
  }

  Future<void> _pickRideTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime:
      _departureTime ?? TimeOfDay.now(),
    );

    if (picked == null) return;

    setState(() {
      _departureTime = picked;

      if (_departureDateTime != null) {
        _departureDateTime = DateTime(
          _departureDateTime!.year,
          _departureDateTime!.month,
          _departureDateTime!.day,
          picked.hour,
          picked.minute,
        );
      }
    });

    await _saveDraft();
  }

  // ---------------------------------------------------------------------
  // Chips
  // ---------------------------------------------------------------------

  Widget _chipSection(
      String title,
      List options,
      Set selected,
      ) {
    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((opt) {
            final isSelected =
            selected.contains(opt);

            return FilterChip(
              label: Text(
                opt,
                style: const TextStyle(
                  fontSize: 12,
                ),
              ),
              selected: isSelected,
              onSelected: (value) {
                setState(() {
                  if (value) {
                    selected.add(opt);
                  } else {
                    selected.remove(opt);
                  }
                });
              },
              selectedColor: Colors.green[100],
              checkmarkColor:
              Colors.green[800],
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _rideDayChip(String day) {
    final selected =
    _recurringDays.contains(day);

    return FilterChip(
      label: Text(day),
      selected: selected,
      onSelected: (value) {
        setState(() {
          if (value) {
            _recurringDays.add(day);
          } else {
            _recurringDays.remove(day);
          }
        });

        _saveDraft();
      },
      selectedColor: Colors.green[100],
      checkmarkColor: Colors.green[800],
    );
  }

  // ---------------------------------------------------------------------
  // Submit
  // ---------------------------------------------------------------------

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_isProvider && _cardImage == null) {
      setState(() {
        _error =
        'Please take a photo of your Ghana Card.';
      });
      return;
    }

    if (_isProvider &&
        _selectedCategory == null) {
      setState(() {
        _error =
        'Please select a service category.';
      });
      return;
    }

    if (_needsProviderPhoto &&
        _providerPhoto == null) {
      setState(() {
        _error =
        'Please take a public photo.';
      });
      return;
    }

    if (_isMechanic &&
        _selectedVehicleTypes.isEmpty) {
      setState(() {
        _error =
        'Select at least one vehicle type you work on.';
      });
      return;
    }

    if (_isSteelBender &&
        _selectedSteelSpecialties.isEmpty) {
      setState(() {
        _error =
        'Select at least one specialty.';
      });
      return;
    }

    if (_isElectrician &&
        _selectedElectricianServices.isEmpty) {
      setState(() {
        _error =
        'Select at least one service you offer.';
      });
      return;
    }

    if (_isTailor &&
        _selectedGarmentTypes.isEmpty) {
      setState(() {
        _error =
        'Select at least one garment type you work on.';
      });
      return;
    }

    if (_isPlumber &&
        _selectedPlumberPropertyTypes.isEmpty) {
      setState(() {
        _error =
        'Select at least one property type you service.';
      });
      return;
    }

    // -------------------------------------------------------------------
    // Ride Along validation
    // -------------------------------------------------------------------

    if (_isRideAlong) {
      final seats =
          int.tryParse(
            _rideSeatsController.text.trim(),
          ) ??
              0;

      final price =
          double.tryParse(
            _ridePriceController.text.trim(),
          ) ??
              -1;

      if (_rideType == 'oneTime' &&
          _departureDateTime == null) {
        setState(() {
          _error =
          'Please select the departure date.';
        });
        return;
      }

      if (_departureTime == null) {
        setState(() {
          _error =
          'Please select the departure time.';
        });
        return;
      }

      if (_rideType == 'recurring' &&
          _recurringDays.isEmpty) {
        setState(() {
          _error =
          'Please select at least one recurring day.';
        });
        return;
      }

      if (seats <= 0) {
        setState(() {
          _error =
          'Please enter the number of available seats.';
        });
        return;
      }

      if (price < 0) {
        setState(() {
          _error =
          'Please enter a valid price per seat.';
        });
        return;
      }
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      String? ghanaCardPhotoUrl;
      String? profilePhotoUrl;

      final uid =
          AuthService.instance.currentUser?.uid;

      // -----------------------------------------------------------------
      // Ghana Card
      // -----------------------------------------------------------------

      if (_isProvider &&
          _cardImage != null &&
          uid != null) {
        ghanaCardPhotoUrl =
        await PhotoUploadService
            .uploadGhanaCardPhoto(
          uid: uid,
          photo: _cardImage!,
        );
      }

      // -----------------------------------------------------------------
      // Basic profile photo
      // -----------------------------------------------------------------

      if (_profilePhoto != null &&
          uid != null) {
        profilePhotoUrl =
        await PhotoUploadService
            .uploadProfilePhoto(
          uid: uid,
          photo: _profilePhoto!,
        );
      }

      // -----------------------------------------------------------------
      // Save main user profile
      // -----------------------------------------------------------------

      await AuthService.instance.saveUserProfile(
        fullName:
        _nameController.text.trim(),
        phoneNumber:
        _phoneController.text.trim(),
        area:
        _areaController.text.trim(),
        category:
        _isProvider
            ? _selectedCategory
            : null,
        ghanaCardNumber:
        _isProvider
            ? _ghanaCardController.text.trim()
            : null,
        ghanaCardPhotoUrl:
        ghanaCardPhotoUrl,
        photoUrl:
        profilePhotoUrl,
      );

      // -----------------------------------------------------------------
      // OKADA
      // -----------------------------------------------------------------

      if (_isOkada) {
        await AuthService.instance
            .registerAsOkadaRider(
          fullName:
          _nameController.text.trim(),
          phoneNumber:
          _phoneController.text.trim(),
          plateNumber:
          _plateController.text.trim(),
          station:
          _stationController.text.trim(),
          ghanaCardNumber:
          _ghanaCardController.text.trim(),
          ghanaCardPhotoUrl:
          ghanaCardPhotoUrl,
          riderPhoto:
          _providerPhoto,
        );
      }

      // -----------------------------------------------------------------
      // ABOBOYAA
      // -----------------------------------------------------------------

      if (_isAboboyaa) {
        await AuthService.instance
            .registerAsAboboyaa(
          fullName:
          _nameController.text.trim(),
          phoneNumber:
          _phoneController.text.trim(),
          numberPlate:
          _plateController.text.trim(),
          station:
          _stationController.text.trim(),
          ghanaCardNumber:
          _ghanaCardController.text.trim(),
          ghanaCardPhotoUrl:
          ghanaCardPhotoUrl,
          riderPhoto:
          _providerPhoto,
        );
      }

      // -----------------------------------------------------------------
      // RIDE ALONG
      // -----------------------------------------------------------------

      if (_isRideAlong) {
        final seats =
            int.tryParse(
              _rideSeatsController.text.trim(),
            ) ??
                1;

        final price =
            double.tryParse(
              _ridePriceController.text.trim(),
            ) ??
                0;

        String? departureTimeString;

        if (_departureTime != null) {
          final hour =
          _departureTime!.hour
              .toString()
              .padLeft(2, '0');

          final minute =
          _departureTime!.minute
              .toString()
              .padLeft(2, '0');

          departureTimeString =
          '$hour:$minute';
        }

        await AuthService.instance
            .registerAsRideAlongDriver(
          driverName:
          _nameController.text.trim(),
          phoneNumber:
          _phoneController.text.trim(),
          fromArea:
          _rideFromController.text.trim(),
          toArea:
          _rideToController.text.trim(),
          stationArea:
          _rideStationController.text.trim(),
          rideType:
          _rideType,

          departureDateTime:
          _rideType == 'oneTime'
              ? _departureDateTime
              : null,

          departureTime:
          departureTimeString,

          recurringDays:
          _rideType == 'recurring'
              ? _recurringDays.toList()
              : const [],

          seatsTotal:
          seats,

          pricePerSeat:
          price,

          carModel:
          _rideCarModelController.text
              .trim()
              .isEmpty
              ? null
              : _rideCarModelController
              .text
              .trim(),

          carColor:
          _rideCarColorController.text
              .trim()
              .isEmpty
              ? null
              : _rideCarColorController
              .text
              .trim(),

          plateNumber:
          _plateController.text
              .trim()
              .isEmpty
              ? null
              : _plateController.text
              .trim(),

          notes:
          _rideNotesController.text
              .trim()
              .isEmpty
              ? null
              : _rideNotesController.text
              .trim(),

          ghanaCardNumber:
          _ghanaCardController.text.trim(),

          ghanaCardImage:
          null,

          // Use the public/provider photo as
          // the first vehicle/ride photo.
          photos:
          _providerPhoto != null
              ? [_providerPhoto!]
              : const [],
        );
      }

      // -----------------------------------------------------------------
      // MECHANIC
      // -----------------------------------------------------------------

      if (_isMechanic) {
        await AuthService.instance
            .registerAsMechanic(
          fullName:
          _nameController.text.trim(),
          phoneNumber:
          _phoneController.text.trim(),
          workshopName:
          _workshopController.text.trim(),
          stationArea:
          _areaController.text.trim(),
          yearsOfExperience:
          int.tryParse(
            _experienceController.text
                .trim(),
          ) ??
              0,
          vehicleTypes:
          _selectedVehicleTypes.toList(),
          brandSpecialties:
          _selectedBrands.toList(),
          servicesOffered:
          _selectedServices.toList(),
          offersRoadsideService:
          _offersRoadsideService,
          ghanaCardNumber:
          _ghanaCardController.text.trim(),
          ghanaCardPhotoUrl:
          ghanaCardPhotoUrl,
          mechanicPhoto:
          _providerPhoto,
        );
      }

      // -----------------------------------------------------------------
      // STEEL BENDER
      // -----------------------------------------------------------------

      if (_isSteelBender) {
        await AuthService.instance
            .registerAsSteelBender(
          fullName:
          _nameController.text.trim(),
          phoneNumber:
          _phoneController.text.trim(),
          workshopName:
          _workshopController.text.trim(),
          stationArea:
          _areaController.text.trim(),
          yearsOfExperience:
          int.tryParse(
            _experienceController.text
                .trim(),
          ) ??
              0,
          specialties:
          _selectedSteelSpecialties.toList(),
          rebarSizesHandled:
          _selectedRebarSizes.toList(),
          offersOnSiteService:
          _offersOnSiteService,
          ghanaCardNumber:
          _ghanaCardController.text.trim(),
          ghanaCardPhotoUrl:
          ghanaCardPhotoUrl,
          steelBenderPhoto:
          _providerPhoto,
        );
      }

      // -----------------------------------------------------------------
      // ELECTRICIAN
      // -----------------------------------------------------------------

      if (_isElectrician) {
        await AuthService.instance
            .registerAsElectrician(
          fullName:
          _nameController.text.trim(),
          phoneNumber:
          _phoneController.text.trim(),
          businessName:
          _workshopController.text.trim(),
          stationArea:
          _areaController.text.trim(),
          yearsOfExperience:
          int.tryParse(
            _experienceController.text
                .trim(),
          ) ??
              0,
          propertyTypesServiced:
          _selectedPropertyTypes.toList(),
          servicesOffered:
          _selectedElectricianServices
              .toList(),
          offersEmergencyService:
          _offersEmergencyService,
          ghanaCardNumber:
          _ghanaCardController.text.trim(),
          ghanaCardPhotoUrl:
          ghanaCardPhotoUrl,
          electricianPhoto:
          _providerPhoto,
        );
      }

      // -----------------------------------------------------------------
      // TAILOR
      // -----------------------------------------------------------------

      if (_isTailor) {
        await AuthService.instance
            .registerAsTailor(
          fullName:
          _nameController.text.trim(),
          phoneNumber:
          _phoneController.text.trim(),
          businessName:
          _workshopController.text.trim(),
          stationArea:
          _areaController.text.trim(),
          yearsOfExperience:
          int.tryParse(
            _experienceController.text
                .trim(),
          ) ??
              0,
          garmentTypesServiced:
          _selectedGarmentTypes.toList(),
          fabricSpecialties:
          _selectedFabrics.toList(),
          servicesOffered:
          _selectedTailoringServices
              .toList(),
          offersRushService:
          _offersRushService,
          ghanaCardNumber:
          _ghanaCardController.text.trim(),
          ghanaCardPhotoUrl:
          ghanaCardPhotoUrl,
          tailorPhoto:
          _providerPhoto,
        );
      }

      // -----------------------------------------------------------------
      // PLUMBER
      // -----------------------------------------------------------------

      if (_isPlumber) {
        await AuthService.instance
            .registerAsPlumber(
          fullName:
          _nameController.text.trim(),
          phoneNumber:
          _phoneController.text.trim(),
          businessName:
          _workshopController.text.trim(),
          stationArea:
          _areaController.text.trim(),
          yearsOfExperience:
          int.tryParse(
            _experienceController.text
                .trim(),
          ) ??
              0,
          propertyTypesServiced:
          _selectedPlumberPropertyTypes
              .toList(),
          fixtureBrands:
          _selectedFixtureBrands.toList(),
          servicesOffered:
          _selectedPlumbingServices
              .toList(),
          offersEmergencyService:
          _offersPlumberEmergencyService,
          ghanaCardNumber:
          _ghanaCardController.text.trim(),
          ghanaCardPhotoUrl:
          ghanaCardPhotoUrl,
          plumberPhoto:
          _providerPhoto,
        );
      }

      if (!mounted) return;

      // -----------------------------------------------------------------
      // OKADA dialog
      // -----------------------------------------------------------------

      if (_isOkada) {
        final goOnline =
        await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title:
            const Text("You're registered!"),
            content: const Text(
              'An admin will review your Ghana Card before '
                  'you appear publicly in the rider list. '
                  'Do you want to go online and start receiving '
                  'rides now?',
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.pop(ctx, false),
                child:
                const Text('Not yet'),
              ),
              ElevatedButton(
                onPressed: () =>
                    Navigator.pop(ctx, true),
                child:
                const Text('Go Online'),
              ),
            ],
          ),
        );

        if (!mounted) return;

        if (goOnline == true) {
          await _clearDraft();

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) =>
              const RiderModeScreen(),
            ),
          );

          return;
        }
      }

      // -----------------------------------------------------------------
      // Aboboyaa dialog
      // -----------------------------------------------------------------

      if (_isAboboyaa) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title:
            const Text("You're registered!"),
            content: const Text(
              'Your Aboboyaa registration has been '
                  'submitted successfully. An admin will review '
                  'your Ghana Card before you appear publicly '
                  'in the Aboboyaa rider list.',
            ),
            actions: [
              ElevatedButton(
                onPressed: () =>
                    Navigator.pop(ctx),
                child:
                const Text('OK'),
              ),
            ],
          ),
        );
      }

      // -----------------------------------------------------------------
      // Ride Along dialog
      // -----------------------------------------------------------------

      if (_isRideAlong) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title:
            const Text("Ride posted!"),
            content: const Text(
              'Your Ride Along post has been submitted. '
                  'An admin will review your Ghana Card before '
                  'the ride becomes visible to passengers.',
            ),
            actions: [
              ElevatedButton(
                onPressed: () =>
                    Navigator.pop(ctx),
                child:
                const Text('OK'),
              ),
            ],
          ),
        );
      }

      // -----------------------------------------------------------------
      // Mechanic dialog
      // -----------------------------------------------------------------

      if (_isMechanic && mounted) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title:
            const Text("You're registered!"),
            content: const Text(
              'An admin will review your Ghana Card '
                  'before you appear publicly in the '
                  'Mechanics list.',
            ),
            actions: [
              ElevatedButton(
                onPressed: () =>
                    Navigator.pop(ctx),
                child:
                const Text('OK'),
              ),
            ],
          ),
        );
      }

      // -----------------------------------------------------------------
      // Steel Bender dialog
      // -----------------------------------------------------------------

      if (_isSteelBender && mounted) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title:
            const Text("You're registered!"),
            content: const Text(
              'An admin will review your Ghana Card '
                  'before you appear publicly in the '
                  'Steel Benders list.',
            ),
            actions: [
              ElevatedButton(
                onPressed: () =>
                    Navigator.pop(ctx),
                child:
                const Text('OK'),
              ),
            ],
          ),
        );
      }

      // -----------------------------------------------------------------
      // Electrician dialog
      // -----------------------------------------------------------------

      if (_isElectrician && mounted) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title:
            const Text("You're registered!"),
            content: const Text(
              'An admin will review your Ghana Card '
                  'before you appear publicly in the '
                  'Electricians list.',
            ),
            actions: [
              ElevatedButton(
                onPressed: () =>
                    Navigator.pop(ctx),
                child:
                const Text('OK'),
              ),
            ],
          ),
        );
      }

      // -----------------------------------------------------------------
      // Tailor dialog
      // -----------------------------------------------------------------

      if (_isTailor && mounted) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title:
            const Text("You're registered!"),
            content: const Text(
              'An admin will review your Ghana Card '
                  'before you appear publicly in the '
                  'Tailors list.',
            ),
            actions: [
              ElevatedButton(
                onPressed: () =>
                    Navigator.pop(ctx),
                child:
                const Text('OK'),
              ),
            ],
          ),
        );
      }

      // -----------------------------------------------------------------
      // Plumber dialog
      // -----------------------------------------------------------------

      if (_isPlumber && mounted) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title:
            const Text("You're registered!"),
            content: const Text(
              'An admin will review your Ghana Card '
                  'before you appear publicly in the '
                  'Plumbers list.',
            ),
            actions: [
              ElevatedButton(
                onPressed: () =>
                    Navigator.pop(ctx),
                child:
                const Text('OK'),
              ),
            ],
          ),
        );
      }

      if (!mounted) return;

      await _clearDraft();

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content:
          Text('Profile saved successfully'),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      // ignore: avoid_print
      print(
        '[BioDataScreen] Save failed: $e',
      );

      if (!mounted) return;

      setState(() {
        _error =
        'Failed to save profile: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // ---------------------------------------------------------------------
  // Dispose
  // ---------------------------------------------------------------------

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _areaController.dispose();
    _ghanaCardController.dispose();
    _plateController.dispose();
    _stationController.dispose();

    _workshopController.dispose();
    _experienceController.dispose();

    _rideFromController.dispose();
    _rideToController.dispose();
    _rideStationController.dispose();
    _rideSeatsController.dispose();
    _ridePriceController.dispose();
    _rideCarModelController.dispose();
    _rideCarColorController.dispose();
    _rideNotesController.dispose();

    super.dispose();
  }

  // ---------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
        const Text('Complete Your Profile'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding:
          const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.stretch,
              children: [
                // ---------------------------------------------------------
                // Error
                // ---------------------------------------------------------

                if (_error != null) ...[
                  Container(
                    padding:
                    const EdgeInsets.all(12),
                    decoration:
                    BoxDecoration(
                      color: Colors.red[50],
                      borderRadius:
                      BorderRadius.circular(8),
                      border: Border.all(
                        color:
                        Colors.red[200]!,
                      ),
                    ),
                    child: Text(
                      _error!,
                      style:
                      const TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // ---------------------------------------------------------
                // Intro
                // ---------------------------------------------------------

                Text(
                  _isProvider
                      ? 'As a service provider, we need a few more details to verify your identity.'
                      : 'Just a few details to finish setting up your account.',
                  style: TextStyle(
                    color:
                    Colors.grey[700],
                  ),
                ),

                const SizedBox(height: 20),

                // ---------------------------------------------------------
                // Profile photo
                // ---------------------------------------------------------

                Center(
                  child:
                  GestureDetector(
                    onTap:
                    _pickProfilePhoto,
                    child:
                    CircleAvatar(
                      radius: 44,
                      backgroundColor:
                      Colors.grey[200],
                      backgroundImage:
                      _profilePhoto !=
                          null
                          ? FileImage(
                        _profilePhoto!,
                      )
                          : null,
                      child:
                      _profilePhoto ==
                          null
                          ? Icon(
                        Icons
                            .add_a_photo_outlined,
                        color: Colors
                            .grey[600],
                        size: 26,
                      )
                          : null,
                    ),
                  ),
                ),

                const SizedBox(height: 6),

                Center(
                  child: Text(
                    'Profile photo (optional)',
                    style: TextStyle(
                      fontSize: 12,
                      color:
                      Colors.grey[600],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ---------------------------------------------------------
                // Basic fields
                // ---------------------------------------------------------

                TextFormField(
                  controller:
                  _nameController,
                  textCapitalization:
                  TextCapitalization
                      .words,
                  decoration:
                  const InputDecoration(
                    labelText:
                    'Full Name',
                    border:
                    OutlineInputBorder(),
                  ),
                  validator: (v) =>
                  (v == null ||
                      v.trim()
                          .isEmpty)
                      ? 'Required'
                      : null,
                ),

                const SizedBox(height: 12),

                TextFormField(
                  controller:
                  _phoneController,
                  keyboardType:
                  TextInputType.phone,
                  decoration:
                  const InputDecoration(
                    labelText:
                    'Phone Number',
                    border:
                    OutlineInputBorder(),
                  ),
                  validator: (v) =>
                  (v == null ||
                      v.trim()
                          .isEmpty)
                      ? 'Required'
                      : null,
                ),

                const SizedBox(height: 12),

                TextFormField(
                  controller:
                  _areaController,
                  decoration:
                  const InputDecoration(
                    labelText:
                    'Area / Location',
                    hintText:
                    'e.g. Mataheko, Afienya',
                    border:
                    OutlineInputBorder(),
                  ),
                  validator: (v) =>
                  (v == null ||
                      v.trim()
                          .isEmpty)
                      ? 'Required'
                      : null,
                ),

                // =========================================================
                // PROVIDER SECTION
                // =========================================================

                if (_isProvider) ...[
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 12),

                  const Text(
                    'Service Category',
                    style: TextStyle(
                      fontWeight:
                      FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),

                  const SizedBox(height: 12),

                  DropdownButtonFormField<
                      String>(
                    value:
                    _selectedCategory,
                    decoration:
                    const InputDecoration(
                      labelText:
                      'Category',
                      border:
                      OutlineInputBorder(),
                    ),
                    items: categories
                        .map(
                          (category) =>
                          DropdownMenuItem(
                            value:
                            category,
                            child:
                            Text(
                              category,
                            ),
                          ),
                    )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedCategory =
                            value;
                      });

                      _saveDraft();
                    },
                    validator: (v) =>
                    (_isProvider &&
                        v == null)
                        ? 'Please select a category'
                        : null,
                  ),

                  // =======================================================
                  // PUBLIC PHOTO
                  // =======================================================

                  if (_needsProviderPhoto) ...[
                    const SizedBox(height: 20),

                    Text(
                      _isOkada ||
                          _isAboboyaa
                          ? 'Rider Details'
                          : _isRideAlong
                          ? 'Ride Along Details'
                          : _isSteelBender
                          ? 'Steel Bender Details'
                          : _isElectrician
                          ? 'Electrician Details'
                          : _isTailor
                          ? 'Tailor Details'
                          : _isPlumber
                          ? 'Plumber Details'
                          : 'Mechanic Details',
                      style:
                      const TextStyle(
                        fontWeight:
                        FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      _isRideAlong
                          ? 'Add a photo of yourself or your vehicle. It may be shown with the ride.'
                          : 'Shown to app users when they view your profile.',
                      style: TextStyle(
                        fontSize: 12,
                        color:
                        Colors.grey[600],
                      ),
                    ),

                    const SizedBox(height: 12),

                    Center(
                      child:
                      GestureDetector(
                        onTap:
                        _pickProviderPhoto,
                        child:
                        CircleAvatar(
                          radius: 50,
                          backgroundColor:
                          Colors.green[
                          50],
                          backgroundImage:
                          _providerPhoto !=
                              null
                              ? FileImage(
                            _providerPhoto!,
                          )
                              : null,
                          child:
                          _providerPhoto ==
                              null
                              ? Icon(
                            Icons
                                .add_a_photo,
                            color: Colors
                                .green[
                            700],
                            size: 28,
                          )
                              : null,
                        ),
                      ),
                    ),

                    const SizedBox(height: 6),

                    const Center(
                      child: Text(
                        'Public photo',
                        style:
                        TextStyle(
                          fontSize: 12,
                          color:
                          Colors.grey,
                        ),
                      ),
                    ),
                  ],

                  // =======================================================
                  // OKADA
                  // =======================================================

                  if (_isOkada) ...[
                    const SizedBox(height: 16),

                    TextFormField(
                      controller:
                      _plateController,
                      textCapitalization:
                      TextCapitalization
                          .characters,
                      decoration:
                      const InputDecoration(
                        labelText:
                        'Number Plate',
                        hintText:
                        'e.g. GT 1234-24',
                        border:
                        OutlineInputBorder(),
                      ),
                      validator: (v) =>
                      (_isOkada &&
                          (v == null ||
                              v.trim()
                                  .isEmpty))
                          ? 'Required'
                          : null,
                    ),

                    const SizedBox(height: 12),

                    TextFormField(
                      controller:
                      _stationController,
                      decoration:
                      const InputDecoration(
                        labelText:
                        'Station / Base',
                        hintText:
                        'e.g. Mataheko main stop',
                        border:
                        OutlineInputBorder(),
                      ),
                      validator: (v) =>
                      (_isOkada &&
                          (v == null ||
                              v.trim()
                                  .isEmpty))
                          ? 'Required'
                          : null,
                    ),
                  ],

                  // =======================================================
                  // ABOBOYAA
                  // =======================================================

                  if (_isAboboyaa) ...[
                    const SizedBox(height: 16),

                    TextFormField(
                      controller:
                      _plateController,
                      textCapitalization:
                      TextCapitalization
                          .characters,
                      decoration:
                      const InputDecoration(
                        labelText:
                        'Number Plate',
                        hintText:
                        'e.g. GR 1234-24',
                        border:
                        OutlineInputBorder(),
                      ),
                      validator: (v) =>
                      (_isAboboyaa &&
                          (v == null ||
                              v.trim()
                                  .isEmpty))
                          ? 'Required'
                          : null,
                    ),

                    const SizedBox(height: 12),

                    TextFormField(
                      controller:
                      _stationController,
                      decoration:
                      const InputDecoration(
                        labelText:
                        'Station / Base',
                        hintText:
                        'e.g. Mataheko main station',
                        border:
                        OutlineInputBorder(),
                      ),
                      validator: (v) =>
                      (_isAboboyaa &&
                          (v == null ||
                              v.trim()
                                  .isEmpty))
                          ? 'Required'
                          : null,
                    ),
                  ],

                  // =======================================================
                  // RIDE ALONG
                  // =======================================================

                  if (_isRideAlong) ...[
                    const SizedBox(height: 16),

                    TextFormField(
                      controller:
                      _rideFromController,
                      textCapitalization:
                      TextCapitalization
                          .words,
                      decoration:
                      const InputDecoration(
                        labelText:
                        'From',
                        hintText:
                        'e.g. Mataheko',
                        border:
                        OutlineInputBorder(),
                      ),
                      validator: (v) =>
                      (_isRideAlong &&
                          (v == null ||
                              v.trim()
                                  .isEmpty))
                          ? 'Required'
                          : null,
                    ),

                    const SizedBox(height: 12),

                    TextFormField(
                      controller:
                      _rideToController,
                      textCapitalization:
                      TextCapitalization
                          .words,
                      decoration:
                      const InputDecoration(
                        labelText:
                        'To',
                        hintText:
                        'e.g. Accra Central',
                        border:
                        OutlineInputBorder(),
                      ),
                      validator: (v) =>
                      (_isRideAlong &&
                          (v == null ||
                              v.trim()
                                  .isEmpty))
                          ? 'Required'
                          : null,
                    ),

                    const SizedBox(height: 12),

                    TextFormField(
                      controller:
                      _rideStationController,
                      textCapitalization:
                      TextCapitalization
                          .words,
                      decoration:
                      const InputDecoration(
                        labelText:
                        'Meeting / Pickup Area',
                        hintText:
                        'e.g. Mataheko main station',
                        border:
                        OutlineInputBorder(),
                      ),
                      validator: (v) =>
                      (_isRideAlong &&
                          (v == null ||
                              v.trim()
                                  .isEmpty))
                          ? 'Required'
                          : null,
                    ),

                    const SizedBox(height: 18),

                    const Text(
                      'Ride Type',
                      style:
                      TextStyle(
                        fontWeight:
                        FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),

                    const SizedBox(height: 8),

                    SegmentedButton<
                        String>(
                      segments: const [
                        ButtonSegment(
                          value:
                          'oneTime',
                          label:
                          Text(
                            'One-Time',
                          ),
                          icon: Icon(
                            Icons
                                .event_outlined,
                          ),
                        ),
                        ButtonSegment(
                          value:
                          'recurring',
                          label:
                          Text(
                            'Recurring',
                          ),
                          icon: Icon(
                            Icons
                                .repeat,
                          ),
                        ),
                      ],
                      selected: {
                        _rideType,
                      },
                      onSelectionChanged:
                          (values) {
                        setState(() {
                          _rideType =
                              values
                                  .first;
                        });

                        _saveDraft();
                      },
                    ),

                    const SizedBox(height: 18),

                    // -----------------------------------------------------
                    // One-time date
                    // -----------------------------------------------------

                    if (_rideType ==
                        'oneTime') ...[
                      InkWell(
                        onTap:
                        _pickRideDate,
                        borderRadius:
                        BorderRadius
                            .circular(
                          8,
                        ),
                        child:
                        InputDecorator(
                          decoration:
                          const InputDecoration(
                            labelText:
                            'Departure Date',
                            border:
                            OutlineInputBorder(),
                          ),
                          child: Text(
                            _departureDateTime ==
                                null
                                ? 'Select date'
                                : '${_departureDateTime!.day.toString().padLeft(2, '0')}/'
                                '${_departureDateTime!.month.toString().padLeft(2, '0')}/'
                                '${_departureDateTime!.year}',
                          ),
                        ),
                      ),
                    ],

                    if (_rideType ==
                        'recurring') ...[
                      const Text(
                        'Recurring Days',
                        style:
                        TextStyle(
                          fontWeight:
                          FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),

                      const SizedBox(
                          height: 8),

                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _rideDayChip(
                              'Monday'),
                          _rideDayChip(
                              'Tuesday'),
                          _rideDayChip(
                              'Wednesday'),
                          _rideDayChip(
                              'Thursday'),
                          _rideDayChip(
                              'Friday'),
                          _rideDayChip(
                              'Saturday'),
                          _rideDayChip(
                              'Sunday'),
                        ],
                      ),
                    ],

                    const SizedBox(height: 12),

                    InkWell(
                      onTap:
                      _pickRideTime,
                      borderRadius:
                      BorderRadius
                          .circular(
                        8,
                      ),
                      child:
                      InputDecorator(
                        decoration:
                        const InputDecoration(
                          labelText:
                          'Departure Time',
                          border:
                          OutlineInputBorder(),
                        ),
                        child: Text(
                          _departureTime ==
                              null
                              ? 'Select time'
                              : _departureTime!
                              .format(
                            context,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child:
                          TextFormField(
                            controller:
                            _rideSeatsController,
                            keyboardType:
                            TextInputType
                                .number,
                            decoration:
                            const InputDecoration(
                              labelText:
                              'Available Seats',
                              hintText:
                              'e.g. 3',
                              border:
                              OutlineInputBorder(),
                            ),
                            validator:
                                (v) {
                              if (!_isRideAlong) {
                                return null;
                              }

                              final value =
                              int.tryParse(
                                v?.trim() ??
                                    '',
                              );

                              if (value ==
                                  null ||
                                  value <=
                                      0) {
                                return 'Enter valid seats';
                              }

                              return null;
                            },
                          ),
                        ),

                        const SizedBox(
                            width: 12),

                        Expanded(
                          child:
                          TextFormField(
                            controller:
                            _ridePriceController,
                            keyboardType:
                            const TextInputType
                                .numberWithOptions(
                              decimal:
                              true,
                            ),
                            decoration:
                            const InputDecoration(
                              labelText:
                              'Price / Seat',
                              hintText:
                              'e.g. 10',
                              prefixText:
                              'GH₵ ',
                              border:
                              OutlineInputBorder(),
                            ),
                            validator:
                                (v) {
                              if (!_isRideAlong) {
                                return null;
                              }

                              final value =
                              double.tryParse(
                                v?.trim() ??
                                    '',
                              );

                              if (value ==
                                  null ||
                                  value < 0) {
                                return 'Enter valid price';
                              }

                              return null;
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    TextFormField(
                      controller:
                      _rideCarModelController,
                      textCapitalization:
                      TextCapitalization
                          .words,
                      decoration:
                      const InputDecoration(
                        labelText:
                        'Car Model (optional)',
                        hintText:
                        'e.g. Toyota Corolla',
                        border:
                        OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 12),

                    TextFormField(
                      controller:
                      _rideCarColorController,
                      textCapitalization:
                      TextCapitalization
                          .words,
                      decoration:
                      const InputDecoration(
                        labelText:
                        'Car Color (optional)',
                        hintText:
                        'e.g. Silver',
                        border:
                        OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Ride Along uses the main plate
                    // controller.
                    TextFormField(
                      controller:
                      _plateController,
                      textCapitalization:
                      TextCapitalization
                          .characters,
                      decoration:
                      const InputDecoration(
                        labelText:
                        'Vehicle Number Plate',
                        hintText:
                        'e.g. GT 1234-24',
                        border:
                        OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 12),

                    TextFormField(
                      controller:
                      _rideNotesController,
                      maxLines: 3,
                      decoration:
                      const InputDecoration(
                        labelText:
                        'Additional Notes (optional)',
                        hintText:
                        'Anything passengers should know...',
                        border:
                        OutlineInputBorder(),
                      ),
                    ),
                  ],

                  // =======================================================
                  // MECHANIC
                  // =======================================================

                  if (_isMechanic) ...[
                    const SizedBox(height: 16),

                    TextFormField(
                      controller:
                      _workshopController,
                      textCapitalization:
                      TextCapitalization
                          .words,
                      decoration:
                      const InputDecoration(
                        labelText:
                        'Workshop / Garage Name',
                        border:
                        OutlineInputBorder(),
                      ),
                      validator: (v) =>
                      (_isMechanic &&
                          (v == null ||
                              v.trim()
                                  .isEmpty))
                          ? 'Required'
                          : null,
                    ),

                    const SizedBox(height: 12),

                    TextFormField(
                      controller:
                      _experienceController,
                      keyboardType:
                      TextInputType
                          .number,
                      decoration:
                      const InputDecoration(
                        labelText:
                        'Years of Experience',
                        border:
                        OutlineInputBorder(),
                      ),
                      validator: (v) =>
                      (_isMechanic &&
                          (v == null ||
                              v.trim()
                                  .isEmpty))
                          ? 'Required'
                          : null,
                    ),

                    const SizedBox(height: 20),

                    _chipSection(
                      'Vehicle Types You Work On',
                      vehicleTypeOptions,
                      _selectedVehicleTypes,
                    ),

                    const SizedBox(height: 20),

                    _chipSection(
                      'Brand Specialties (optional)',
                      brandSpecialtyOptions,
                      _selectedBrands,
                    ),

                    const SizedBox(height: 20),

                    _chipSection(
                      'Services You Offer',
                      serviceOptions,
                      _selectedServices,
                    ),

                    const SizedBox(height: 12),

                    SwitchListTile(
                      contentPadding:
                      EdgeInsets.zero,
                      title:
                      const Text(
                        'Offers Roadside / Breakdown Service',
                        style:
                        TextStyle(
                          fontSize: 13,
                        ),
                      ),
                      value:
                      _offersRoadsideService,
                      activeColor:
                      Colors.green[700],
                      onChanged: (value) {
                        setState(() {
                          _offersRoadsideService =
                              value;
                        });
                      },
                    ),
                  ],

                  // =======================================================
                  // STEEL BENDER
                  // =======================================================

                  if (_isSteelBender) ...[
                    const SizedBox(height: 16),

                    TextFormField(
                      controller:
                      _workshopController,
                      textCapitalization:
                      TextCapitalization
                          .words,
                      decoration:
                      const InputDecoration(
                        labelText:
                        'Workshop / Site Name',
                        hintText:
                        'e.g. Kofi Steel Works',
                        border:
                        OutlineInputBorder(),
                      ),
                      validator: (v) =>
                      (_isSteelBender &&
                          (v == null ||
                              v.trim()
                                  .isEmpty))
                          ? 'Required'
                          : null,
                    ),

                    const SizedBox(height: 12),

                    TextFormField(
                      controller:
                      _experienceController,
                      keyboardType:
                      TextInputType
                          .number,
                      decoration:
                      const InputDecoration(
                        labelText:
                        'Years of Experience',
                        border:
                        OutlineInputBorder(),
                      ),
                      validator: (v) =>
                      (_isSteelBender &&
                          (v == null ||
                              v.trim()
                                  .isEmpty))
                          ? 'Required'
                          : null,
                    ),

                    const SizedBox(height: 20),

                    _chipSection(
                      'Specialties',
                      SteelBender
                          .specialtyOptions,
                      _selectedSteelSpecialties,
                    ),

                    const SizedBox(height: 20),

                    _chipSection(
                      'Rebar Sizes Handled',
                      SteelBender
                          .rebarSizeOptions,
                      _selectedRebarSizes,
                    ),

                    const SizedBox(height: 12),

                    SwitchListTile(
                      contentPadding:
                      EdgeInsets.zero,
                      title:
                      const Text(
                        'Available for On-Site / Mobile Service',
                        style:
                        TextStyle(
                          fontSize: 13,
                        ),
                      ),
                      subtitle:
                      const Text(
                        'Willing to work at construction sites, not just a fixed shop',
                        style:
                        TextStyle(
                          fontSize: 11,
                        ),
                      ),
                      value:
                      _offersOnSiteService,
                      activeColor:
                      Colors.green[700],
                      onChanged: (value) {
                        setState(() {
                          _offersOnSiteService =
                              value;
                        });
                      },
                    ),
                  ],

                  // =======================================================
                  // ELECTRICIAN
                  // =======================================================

                  if (_isElectrician) ...[
                    const SizedBox(height: 16),

                    TextFormField(
                      controller:
                      _workshopController,
                      textCapitalization:
                      TextCapitalization
                          .words,
                      decoration:
                      const InputDecoration(
                        labelText:
                        'Business / Shop Name',
                        hintText:
                        'e.g. Kofi Electricals',
                        border:
                        OutlineInputBorder(),
                      ),
                      validator: (v) =>
                      (_isElectrician &&
                          (v == null ||
                              v.trim()
                                  .isEmpty))
                          ? 'Required'
                          : null,
                    ),

                    const SizedBox(height: 12),

                    TextFormField(
                      controller:
                      _experienceController,
                      keyboardType:
                      TextInputType
                          .number,
                      decoration:
                      const InputDecoration(
                        labelText:
                        'Years of Experience',
                        border:
                        OutlineInputBorder(),
                      ),
                      validator: (v) =>
                      (_isElectrician &&
                          (v == null ||
                              v.trim()
                                  .isEmpty))
                          ? 'Required'
                          : null,
                    ),

                    const SizedBox(height: 20),

                    _chipSection(
                      'Property Types You Service',
                      propertyTypeOptions,
                      _selectedPropertyTypes,
                    ),

                    const SizedBox(height: 20),

                    _chipSection(
                      'Services You Offer',
                      electricalServiceOptions,
                      _selectedElectricianServices,
                    ),

                    const SizedBox(height: 12),

                    SwitchListTile(
                      contentPadding:
                      EdgeInsets.zero,
                      title:
                      const Text(
                        'Offers Emergency Service',
                        style:
                        TextStyle(
                          fontSize: 13,
                        ),
                      ),
                      subtitle:
                      const Text(
                        'Available for urgent electrical faults, not just scheduled jobs',
                        style:
                        TextStyle(
                          fontSize: 11,
                        ),
                      ),
                      value:
                      _offersEmergencyService,
                      activeColor:
                      Colors.green[700],
                      onChanged: (value) {
                        setState(() {
                          _offersEmergencyService =
                              value;
                        });
                      },
                    ),
                  ],

                  // =======================================================
                  // TAILOR
                  // =======================================================

                  if (_isTailor) ...[
                    const SizedBox(height: 16),

                    TextFormField(
                      controller:
                      _workshopController,
                      textCapitalization:
                      TextCapitalization
                          .words,
                      decoration:
                      const InputDecoration(
                        labelText:
                        'Shop / Business Name',
                        hintText:
                        "e.g. Ama's Fashion House",
                        border:
                        OutlineInputBorder(),
                      ),
                      validator: (v) =>
                      (_isTailor &&
                          (v == null ||
                              v.trim()
                                  .isEmpty))
                          ? 'Required'
                          : null,
                    ),

                    const SizedBox(height: 12),

                    TextFormField(
                      controller:
                      _experienceController,
                      keyboardType:
                      TextInputType
                          .number,
                      decoration:
                      const InputDecoration(
                        labelText:
                        'Years of Experience',
                        border:
                        OutlineInputBorder(),
                      ),
                      validator: (v) =>
                      (_isTailor &&
                          (v == null ||
                              v.trim()
                                  .isEmpty))
                          ? 'Required'
                          : null,
                    ),

                    const SizedBox(height: 20),

                    _chipSection(
                      'Garment Types You Work On',
                      garmentCategoryOptions,
                      _selectedGarmentTypes,
                    ),

                    const SizedBox(height: 20),

                    _chipSection(
                      'Fabric Specialties (optional)',
                      fabricSpecialtyOptions,
                      _selectedFabrics,
                    ),

                    const SizedBox(height: 20),

                    _chipSection(
                      'Services You Offer',
                      tailoringServiceOptions,
                      _selectedTailoringServices,
                    ),

                    const SizedBox(height: 12),

                    SwitchListTile(
                      contentPadding:
                      EdgeInsets.zero,
                      title:
                      const Text(
                        'Offers Rush / Express Orders',
                        style:
                        TextStyle(
                          fontSize: 13,
                        ),
                      ),
                      value:
                      _offersRushService,
                      activeColor:
                      Colors.green[700],
                      onChanged: (value) {
                        setState(() {
                          _offersRushService =
                              value;
                        });
                      },
                    ),
                  ],

                  // =======================================================
                  // PLUMBER
                  // =======================================================

                  if (_isPlumber) ...[
                    const SizedBox(height: 16),

                    TextFormField(
                      controller:
                      _workshopController,
                      textCapitalization:
                      TextCapitalization
                          .words,
                      decoration:
                      const InputDecoration(
                        labelText:
                        'Business Name',
                        hintText:
                        'e.g. Kwesi Plumbing Services',
                        border:
                        OutlineInputBorder(),
                      ),
                      validator: (v) =>
                      (_isPlumber &&
                          (v == null ||
                              v.trim()
                                  .isEmpty))
                          ? 'Required'
                          : null,
                    ),

                    const SizedBox(height: 12),

                    TextFormField(
                      controller:
                      _experienceController,
                      keyboardType:
                      TextInputType
                          .number,
                      decoration:
                      const InputDecoration(
                        labelText:
                        'Years of Experience',
                        border:
                        OutlineInputBorder(),
                      ),
                      validator: (v) =>
                      (_isPlumber &&
                          (v == null ||
                              v.trim()
                                  .isEmpty))
                          ? 'Required'
                          : null,
                    ),

                    const SizedBox(height: 20),

                    _chipSection(
                      'Property Types Serviced',
                      propertyTypeOptions,
                      _selectedPlumberPropertyTypes,
                    ),

                    const SizedBox(height: 20),

                    _chipSection(
                      'Fixture Brands (optional)',
                      fixtureBrandOptions,
                      _selectedFixtureBrands,
                    ),

                    const SizedBox(height: 20),

                    _chipSection(
                      'Services You Offer',
                      plumbingServiceOptions,
                      _selectedPlumbingServices,
                    ),

                    const SizedBox(height: 12),

                    SwitchListTile(
                      contentPadding:
                      EdgeInsets.zero,
                      title:
                      const Text(
                        'Offers Emergency / After-Hours Call-Out',
                        style:
                        TextStyle(
                          fontSize: 13,
                        ),
                      ),
                      value:
                      _offersPlumberEmergencyService,
                      activeColor:
                      Colors.green[700],
                      onChanged: (value) {
                        setState(() {
                          _offersPlumberEmergencyService =
                              value;
                        });
                      },
                    ),
                  ],

                  // =======================================================
                  // GHANA CARD
                  // =======================================================

                  const SizedBox(height: 24),

                  const Divider(),

                  const SizedBox(height: 8),

                  Row(
                    children: [
                      const Icon(
                        Icons.lock_outline,
                        size: 14,
                        color:
                        Colors.redAccent,
                      ),
                      const SizedBox(
                          width: 4),
                      Expanded(
                        child: Text(
                          'Identity record — admin only, never shown to app users',
                          style:
                          TextStyle(
                            fontSize: 12,
                            color:
                            Colors.grey[700],
                            fontWeight:
                            FontWeight
                                .w600,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  Text(
                    'Required for anyone offering services on Mataheko, to keep the community safe.',
                    style: TextStyle(
                      fontSize: 12,
                      color:
                      Colors.grey[600],
                    ),
                  ),

                  const SizedBox(height: 12),

                  TextFormField(
                    controller:
                    _ghanaCardController,
                    decoration:
                    const InputDecoration(
                      labelText:
                      'Ghana Card Number',
                      hintText:
                      'GHA-XXXXXXXXX-X',
                      border:
                      OutlineInputBorder(),
                    ),
                    validator: (v) =>
                    (_isProvider &&
                        (v == null ||
                            v.trim()
                                .isEmpty))
                        ? 'Required for service providers'
                        : null,
                  ),

                  const SizedBox(height: 12),

                  InkWell(
                    onTap:
                    _pickCardImage,
                    child: Container(
                      height: 140,
                      width: double.infinity,
                      decoration:
                      BoxDecoration(
                        color:
                        Colors.red[50],
                        borderRadius:
                        BorderRadius
                            .circular(
                          12,
                        ),
                        border:
                        Border.all(
                          color:
                          Colors.red[
                          100]!,
                        ),
                      ),
                      child:
                      _cardImage ==
                          null
                          ? Column(
                        mainAxisAlignment:
                        MainAxisAlignment
                            .center,
                        children: [
                          Icon(
                            Icons
                                .badge_outlined,
                            color: Colors
                                .red[
                            300],
                            size:
                            32,
                          ),
                          const SizedBox(
                              height:
                              6),
                          Text(
                            'Tap to add Ghana Card photo',
                            style:
                            TextStyle(
                              color:
                              Colors.red[300],
                              fontSize:
                              12,
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
                        child:
                        Image.file(
                          _cardImage!,
                          fit: BoxFit
                              .cover,
                          width:
                          double.infinity,
                        ),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // =========================================================
                // SUBMIT
                // =========================================================

                ElevatedButton(
                  onPressed:
                  _loading
                      ? null
                      : _submit,
                  style:
                  ElevatedButton
                      .styleFrom(
                    backgroundColor:
                    Colors.green[700],
                    padding:
                    const EdgeInsets
                        .symmetric(
                      vertical: 14,
                    ),
                  ),
                  child: _loading
                      ? const SizedBox(
                    height: 18,
                    width: 18,
                    child:
                    CircularProgressIndicator(
                      strokeWidth:
                      2,
                      color: Colors
                          .white,
                    ),
                  )
                      : Text(
                    _isRideAlong
                        ? 'Post Ride'
                        : 'Save & Continue',
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