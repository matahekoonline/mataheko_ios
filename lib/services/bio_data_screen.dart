import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_role.dart';
import '../models/mechanic.dart';
import '../models/steel_bender.dart';
import '../models/carpenter.dart';
import '../models/tailor.dart';
import '../models/plumber.dart';
import '../models/teacher.dart';
import '../services/auth_service.dart';
import '../services/photo_upload_service.dart';
// Adjust this path if sample_listings.dart lives somewhere other than
// lib/data/ in your project — it's only used here for the `categories` list.
import '../data/sample_listings.dart';
import '../screens/rider_mode_screen.dart';

class BioDataScreen extends StatefulWidget {
  final UserRole role;
  const BioDataScreen({super.key, required this.role});

  @override
  State<BioDataScreen> createState() => _BioDataScreenState();
}

class _BioDataScreenState extends State<BioDataScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _areaController = TextEditingController();
  final _ghanaCardController = TextEditingController();
  final _plateController = TextEditingController();
  final _stationController = TextEditingController();

  // Mechanic-specific controllers
  final _workshopController = TextEditingController();
  final _experienceController = TextEditingController();
  final Set<String> _selectedVehicleTypes = {};
  final Set<String> _selectedBrands = {};
  final Set<String> _selectedServices = {};
  bool _offersRoadsideService = false;

  // Steel Bender-specific state (reuses _workshopController/_experienceController
  // above for "Workshop / Site Name" and "Years of Experience" — the labels
  // just change based on category).
  final Set<String> _selectedSteelSpecialties = {};
  final Set<String> _selectedRebarSizes = {};
  bool _offersOnSiteService = false;

  // Carpenter-specific state (reuses _workshopController/_experienceController
  // above for "Workshop / Site Name" and "Years of Experience", and its own
  // _offersOnSiteServiceCarpenter switch since a carpenter's on-site meaning
  // is distinct from a steel bender's).
  final Set<String> _selectedCarpentrySpecialties = {};
  final Set<String> _selectedCarpentryMaterials = {};
  final Set<String> _selectedCarpentryServices = {};
  bool _offersOnSiteServiceCarpenter = false;

  // Tailor-specific state (reuses _workshopController/_experienceController
  // above for "Shop / Business Name" and "Years of Experience" — the labels
  // just change based on category).
  final Set<String> _selectedGarmentTypes = {};
  final Set<String> _selectedFabrics = {};
  final Set<String> _selectedTailoringServices = {};
  bool _offersRushService = false;

  // Plumber-specific state (reuses _workshopController/_experienceController
  // above for "Business Name" and "Years of Experience").
  final Set<String> _selectedPropertyTypes = {};
  final Set<String> _selectedFixtureBrands = {};
  final Set<String> _selectedPlumbingServices = {};
  bool _offersEmergencyService = false;

  // Tiler-specific state (reuses _workshopController/_experienceController
  // above for "Business Name" and "Years of Experience").
  final Set<String> _selectedTilerSpecialties = {};
  final Set<String> _selectedTilerMaterials = {};
  final Set<String> _selectedTilerServices = {};
  bool _offersOnSiteConsultation = false;

  // Teacher-specific state (reuses _workshopController/_experienceController
  // above for "School / Institution" and "Years of Experience").
  final Set<String> _selectedSubjects = {};
  final Set<String> _selectedClassLevels = {};
  String? _selectedQualification;
  bool _offersHomeTutoring = false;
  bool _offersOnlineTutoring = false;

  File? _cardImage;
  File? _providerPhoto; // "shown to buyers" photo — Okada riders, mechanics, etc.
  File? _profilePhoto; // basic account photo — every user, buyer or provider
  String? _selectedCategory;
  bool _loading = false;
  String? _error;
  final _picker = ImagePicker();

  // --- Draft persistence -------------------------------------------------
  // On budget/low-RAM Android phones, opening the camera can cause the OS
  // to kill the app's whole process to free memory (not just pause it).
  // When Flutter restarts, every in-memory field on this screen — typed
  // text, selected chips, selected category — is gone, even though the
  // user never left the screen from their perspective. To survive that,
  // we snapshot the form to SharedPreferences right before handing off to
  // the camera, and silently restore it in initState if we come back to a
  // freshly-recreated (empty) version of this screen.
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
      'carpentrySpecialties': _selectedCarpentrySpecialties.toList(),
      'carpentryMaterials': _selectedCarpentryMaterials.toList(),
      'carpentryServices': _selectedCarpentryServices.toList(),
      'onSiteCarpenter': _offersOnSiteServiceCarpenter,
      'garmentTypes': _selectedGarmentTypes.toList(),
      'fabrics': _selectedFabrics.toList(),
      'tailoringServices': _selectedTailoringServices.toList(),
      'rushService': _offersRushService,
      'propertyTypes': _selectedPropertyTypes.toList(),
      'fixtureBrands': _selectedFixtureBrands.toList(),
      'plumbingServices': _selectedPlumbingServices.toList(),
      'emergencyService': _offersEmergencyService,
      'tilerSpecialties': _selectedTilerSpecialties.toList(),
      'tilerMaterials': _selectedTilerMaterials.toList(),
      'tilerServices': _selectedTilerServices.toList(),
      'onSiteConsultation': _offersOnSiteConsultation,
      'subjects': _selectedSubjects.toList(),
      'classLevels': _selectedClassLevels.toList(),
      'qualification': _selectedQualification,
      'homeTutoring': _offersHomeTutoring,
      'onlineTutoring': _offersOnlineTutoring,
      'cardImagePath': _cardImage?.path,
      'providerPhotoPath': _providerPhoto?.path,
      'profilePhotoPath': _profilePhoto?.path,
    };
    await prefs.setString(_draftKey, jsonEncode(draft));
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
        ..addAll(List<String>.from(draft['vehicleTypes'] as List? ?? const []));
      _selectedBrands
        ..clear()
        ..addAll(List<String>.from(draft['brands'] as List? ?? const []));
      _selectedServices
        ..clear()
        ..addAll(List<String>.from(draft['services'] as List? ?? const []));
      _offersRoadsideService = draft['roadside'] as bool? ?? false;
      _selectedSteelSpecialties
        ..clear()
        ..addAll(List<String>.from(draft['steelSpecialties'] as List? ?? const []));
      _selectedRebarSizes
        ..clear()
        ..addAll(List<String>.from(draft['rebarSizes'] as List? ?? const []));
      _offersOnSiteService = draft['onSite'] as bool? ?? false;
      _selectedCarpentrySpecialties
        ..clear()
        ..addAll(List<String>.from(draft['carpentrySpecialties'] as List? ?? const []));
      _selectedCarpentryMaterials
        ..clear()
        ..addAll(List<String>.from(draft['carpentryMaterials'] as List? ?? const []));
      _selectedCarpentryServices
        ..clear()
        ..addAll(List<String>.from(draft['carpentryServices'] as List? ?? const []));
      _offersOnSiteServiceCarpenter = draft['onSiteCarpenter'] as bool? ?? false;
      _selectedGarmentTypes
        ..clear()
        ..addAll(List<String>.from(draft['garmentTypes'] as List? ?? const []));
      _selectedFabrics
        ..clear()
        ..addAll(List<String>.from(draft['fabrics'] as List? ?? const []));
      _selectedTailoringServices
        ..clear()
        ..addAll(List<String>.from(draft['tailoringServices'] as List? ?? const []));
      _offersRushService = draft['rushService'] as bool? ?? false;
      _selectedPropertyTypes
        ..clear()
        ..addAll(List<String>.from(draft['propertyTypes'] as List? ?? const []));
      _selectedFixtureBrands
        ..clear()
        ..addAll(List<String>.from(draft['fixtureBrands'] as List? ?? const []));
      _selectedPlumbingServices
        ..clear()
        ..addAll(List<String>.from(draft['plumbingServices'] as List? ?? const []));
      _offersEmergencyService = draft['emergencyService'] as bool? ?? false;
      _selectedTilerSpecialties
        ..clear()
        ..addAll(List<String>.from(draft['tilerSpecialties'] as List? ?? const []));
      _selectedTilerMaterials
        ..clear()
        ..addAll(List<String>.from(draft['tilerMaterials'] as List? ?? const []));
      _selectedTilerServices
        ..clear()
        ..addAll(List<String>.from(draft['tilerServices'] as List? ?? const []));
      _offersOnSiteConsultation = draft['onSiteConsultation'] as bool? ?? false;
      _selectedSubjects
        ..clear()
        ..addAll(List<String>.from(draft['subjects'] as List? ?? const []));
      _selectedClassLevels
        ..clear()
        ..addAll(List<String>.from(draft['classLevels'] as List? ?? const []));
      _selectedQualification = draft['qualification'] as String?;
      _offersHomeTutoring = draft['homeTutoring'] as bool? ?? false;
      _offersOnlineTutoring = draft['onlineTutoring'] as bool? ?? false;

      // Only reattach a photo if the file the path points to still exists —
      // the OS may have cleared the app's cache/temp dir independently of
      // killing the process.
      final cardPath = draft['cardImagePath'] as String?;
      final providerPath = draft['providerPhotoPath'] as String?;
      final profilePath = draft['profilePhotoPath'] as String?;
      if (cardPath != null && File(cardPath).existsSync()) _cardImage = File(cardPath);
      if (providerPath != null && File(providerPath).existsSync()) _providerPhoto = File(providerPath);
      if (profilePath != null && File(profilePath).existsSync()) _profilePhoto = File(profilePath);

      if (mounted) setState(() {});
    } catch (_) {
      // Corrupt or unreadable draft — ignore and start fresh rather than crash.
    }
  }

  Future<void> _clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftKey);
  }

  bool get _isProvider => widget.role == UserRole.provider;
  bool get _isOkada => _isProvider && _selectedCategory == 'Okada';
  bool get _isMechanic => _isProvider && _selectedCategory == 'Mechanic';
  bool get _isSteelBender => _isProvider && _selectedCategory == 'Steel Bender';
  bool get _isCarpenter => _isProvider && _selectedCategory == 'Carpenter';
  bool get _isTailor => _isProvider && _selectedCategory == 'Tailor';
  bool get _isPlumber => _isProvider && _selectedCategory == 'Plumber';
  bool get _isTeacher => _isProvider && _selectedCategory == 'Teacher';
  bool get _isTiler => _isProvider && _selectedCategory == 'Tiler';
  bool get _needsProviderPhoto =>
      _isOkada || _isMechanic || _isSteelBender || _isCarpenter || _isTailor || _isPlumber || _isTeacher || _isTiler;

  Future<void> _pickProfilePhoto() async {
    await _saveDraft();
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      setState(() => _profilePhoto = File(picked.path));
      _saveDraft();
    }
  }

  Future<void> _pickCardImage() async {
    await _saveDraft();
    final picked = await _picker.pickImage(source: ImageSource.camera, imageQuality: 80);
    if (picked != null) {
      setState(() => _cardImage = File(picked.path));
      _saveDraft();
    }
  }

  Future<void> _pickProviderPhoto() async {
    await _saveDraft();
    final picked = await _picker.pickImage(source: ImageSource.camera, imageQuality: 80);
    if (picked != null) {
      setState(() => _providerPhoto = File(picked.path));
      _saveDraft();
    }
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
              selectedColor: Colors.green[100],
              checkmarkColor: Colors.green[800],
            );
          }).toList(),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isProvider && _cardImage == null) {
      setState(() => _error = 'Please take a photo of your Ghana Card.');
      return;
    }
    if (_isProvider && _selectedCategory == null) {
      setState(() => _error = 'Please select a service category.');
      return;
    }
    if (_needsProviderPhoto && _providerPhoto == null) {
      setState(() => _error = 'Please take a photo (this is shown to buyers).');
      return;
    }
    if (_isMechanic && _selectedVehicleTypes.isEmpty) {
      setState(() => _error = 'Select at least one vehicle type you work on.');
      return;
    }
    if (_isSteelBender && _selectedSteelSpecialties.isEmpty) {
      setState(() => _error = 'Select at least one specialty.');
      return;
    }
    if (_isCarpenter && _selectedCarpentrySpecialties.isEmpty) {
      setState(() => _error = 'Select at least one specialty.');
      return;
    }
    if (_isTailor && _selectedGarmentTypes.isEmpty) {
      setState(() => _error = 'Select at least one garment type you work on.');
      return;
    }
    if (_isPlumber && _selectedPropertyTypes.isEmpty) {
      setState(() => _error = 'Select at least one property type you service.');
      return;
    }
    if (_isTiler && _selectedTilerSpecialties.isEmpty) {
      setState(() => _error = 'Select at least one specialty you work on.');
      return;
    }
    if (_isTeacher && _selectedSubjects.isEmpty) {
      setState(() => _error = 'Select at least one subject you teach.');
      return;
    }
    if (_isTeacher && _selectedClassLevels.isEmpty) {
      setState(() => _error = 'Select at least one class level you teach.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      String? ghanaCardPhotoUrl;
      String? profilePhotoUrl;
      final uid = AuthService.instance.currentUser?.uid;

      if (_isProvider && _cardImage != null && uid != null) {
        ghanaCardPhotoUrl = await PhotoUploadService.uploadGhanaCardPhoto(uid: uid, photo: _cardImage!);
      }

      // Every user — buyer or provider — can optionally add a profile photo.
      if (_profilePhoto != null && uid != null) {
        profilePhotoUrl = await PhotoUploadService.uploadProfilePhoto(uid: uid, photo: _profilePhoto!);
      }

      await AuthService.instance.saveUserProfile(
        fullName: _nameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        area: _areaController.text.trim(),
        category: _isProvider ? _selectedCategory : null,
        ghanaCardNumber: _isProvider ? _ghanaCardController.text.trim() : null,
        ghanaCardPhotoUrl: ghanaCardPhotoUrl,
        photoUrl: profilePhotoUrl,
      );

      if (_isOkada) {
        await AuthService.instance.registerAsOkadaRider(
          fullName: _nameController.text.trim(),
          phoneNumber: _phoneController.text.trim(),
          plateNumber: _plateController.text.trim(),
          station: _stationController.text.trim(),
          ghanaCardNumber: _ghanaCardController.text.trim(),
          ghanaCardPhotoUrl: ghanaCardPhotoUrl,
          riderPhoto: _providerPhoto,
        );
      }

      if (_isMechanic) {
        await AuthService.instance.registerAsMechanic(
          fullName: _nameController.text.trim(),
          phoneNumber: _phoneController.text.trim(),
          workshopName: _workshopController.text.trim(),
          stationArea: _areaController.text.trim(),
          yearsOfExperience: int.tryParse(_experienceController.text.trim()) ?? 0,
          vehicleTypes: _selectedVehicleTypes.toList(),
          brandSpecialties: _selectedBrands.toList(),
          servicesOffered: _selectedServices.toList(),
          offersRoadsideService: _offersRoadsideService,
          ghanaCardNumber: _ghanaCardController.text.trim(),
          ghanaCardPhotoUrl: ghanaCardPhotoUrl,
          mechanicPhoto: _providerPhoto,
        );
      }

      if (_isSteelBender) {
        await AuthService.instance.registerAsSteelBender(
          fullName: _nameController.text.trim(),
          phoneNumber: _phoneController.text.trim(),
          workshopName: _workshopController.text.trim(),
          stationArea: _areaController.text.trim(),
          yearsOfExperience: int.tryParse(_experienceController.text.trim()) ?? 0,
          specialties: _selectedSteelSpecialties.toList(),
          rebarSizesHandled: _selectedRebarSizes.toList(),
          offersOnSiteService: _offersOnSiteService,
          ghanaCardNumber: _ghanaCardController.text.trim(),
          ghanaCardPhotoUrl: ghanaCardPhotoUrl,
          steelBenderPhoto: _providerPhoto,
        );
      }

      if (_isCarpenter) {
        await AuthService.instance.registerAsCarpenter(
          fullName: _nameController.text.trim(),
          phoneNumber: _phoneController.text.trim(),
          workshopName: _workshopController.text.trim(),
          stationArea: _areaController.text.trim(),
          yearsOfExperience: int.tryParse(_experienceController.text.trim()) ?? 0,
          specialties: _selectedCarpentrySpecialties.toList(),
          materialsWorkedWith: _selectedCarpentryMaterials.toList(),
          servicesOffered: _selectedCarpentryServices.toList(),
          offersOnSiteService: _offersOnSiteServiceCarpenter,
          ghanaCardNumber: _ghanaCardController.text.trim(),
          ghanaCardPhotoUrl: ghanaCardPhotoUrl,
          carpenterPhoto: _providerPhoto,
        );
      }

      if (_isTailor) {
        await AuthService.instance.registerAsTailor(
          fullName: _nameController.text.trim(),
          phoneNumber: _phoneController.text.trim(),
          businessName: _workshopController.text.trim(),
          stationArea: _areaController.text.trim(),
          yearsOfExperience: int.tryParse(_experienceController.text.trim()) ?? 0,
          garmentTypesServiced: _selectedGarmentTypes.toList(),
          fabricSpecialties: _selectedFabrics.toList(),
          servicesOffered: _selectedTailoringServices.toList(),
          offersRushService: _offersRushService,
          ghanaCardNumber: _ghanaCardController.text.trim(),
          ghanaCardPhotoUrl: ghanaCardPhotoUrl,
          tailorPhoto: _providerPhoto,
        );
      }

      if (_isPlumber) {
        await AuthService.instance.registerAsPlumber(
          fullName: _nameController.text.trim(),
          phoneNumber: _phoneController.text.trim(),
          businessName: _workshopController.text.trim(),
          stationArea: _areaController.text.trim(),
          yearsOfExperience: int.tryParse(_experienceController.text.trim()) ?? 0,
          propertyTypesServiced: _selectedPropertyTypes.toList(),
          fixtureBrands: _selectedFixtureBrands.toList(),
          servicesOffered: _selectedPlumbingServices.toList(),
          offersEmergencyService: _offersEmergencyService,
          ghanaCardNumber: _ghanaCardController.text.trim(),
          ghanaCardPhotoUrl: ghanaCardPhotoUrl,
          plumberPhoto: _providerPhoto,
        );
      }

      if (_isTiler) {
        await AuthService.instance.registerAsTiler(
          fullName: _nameController.text.trim(),
          phoneNumber: _phoneController.text.trim(),
          businessName: _workshopController.text.trim(),
          stationArea: _areaController.text.trim(),
          yearsOfExperience: int.tryParse(_experienceController.text.trim()) ?? 0,
          specialtiesServiced: _selectedTilerSpecialties.toList(),
          materialsWorkedWith: _selectedTilerMaterials.toList(),
          servicesOffered: _selectedTilerServices.toList(),
          offersOnSiteConsultation: _offersOnSiteConsultation,
          ghanaCardNumber: _ghanaCardController.text.trim(),
          ghanaCardPhotoUrl: ghanaCardPhotoUrl,
          tilerPhoto: _providerPhoto,
        );
      }

      if (_isTeacher) {
        // NOTE: add a matching registerAsTeacher method to AuthService if
        // it doesn't exist yet — same shape as registerAsMechanic etc,
        // writing to the 'teachers' collection keyed by uid, with
        // isPending: true / isApproved: false.
        await AuthService.instance.registerAsTeacher(
          fullName: _nameController.text.trim(),
          phoneNumber: _phoneController.text.trim(),
          schoolOrInstitution: _workshopController.text.trim(),
          stationArea: _areaController.text.trim(),
          yearsOfExperience: int.tryParse(_experienceController.text.trim()) ?? 0,
          qualification: _selectedQualification ?? '',
          subjectsTaught: _selectedSubjects.toList(),
          classLevelsTaught: _selectedClassLevels.toList(),
          offersHomeTutoring: _offersHomeTutoring,
          offersOnlineTutoring: _offersOnlineTutoring,
          ghanaCardNumber: _ghanaCardController.text.trim(),
          ghanaCardPhotoUrl: ghanaCardPhotoUrl,
          teacherPhoto: _providerPhoto,
        );
      }

      if (!mounted) return;

      if (_isOkada) {
        final goOnline = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('You\'re registered!'),
            content: const Text(
              'An admin will review your Ghana Card before you appear publicly in the rider list. '
                  'Do you want to go online and start receiving rides now?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Not yet'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Go Online'),
              ),
            ],
          ),
        );

        if (!mounted) return;
        if (goOnline == true) {
          await _clearDraft();
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const RiderModeScreen()),
          );
          return;
        }
      }

      if (_isMechanic && mounted) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('You\'re registered!'),
            content: const Text(
              'An admin will review your Ghana Card before you appear publicly in the Mechanics list.',
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }

      if (_isSteelBender && mounted) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('You\'re registered!'),
            content: const Text(
              'An admin will review your Ghana Card before you appear publicly in the Steel Benders list.',
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }

      if (_isCarpenter && mounted) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('You\'re registered!'),
            content: const Text(
              'An admin will review your Ghana Card before you appear publicly in the Carpenters list.',
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }

      if (_isTailor && mounted) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('You\'re registered!'),
            content: const Text(
              'An admin will review your Ghana Card before you appear publicly in the Tailors list.',
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }

      if (_isPlumber && mounted) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('You\'re registered!'),
            content: const Text(
              'An admin will review your Ghana Card before you appear publicly in the Plumbers list.',
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }

      if (_isTeacher && mounted) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('You\'re registered!'),
            content: const Text(
              'An admin will review your Ghana Card before you appear publicly in the Teachers list.',
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }

      if (!mounted) return;
      await _clearDraft();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile saved')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      // ignore: avoid_print
      print('[BioDataScreen] Save failed: $e');
      if (!mounted) return;
      setState(() => _error = 'Failed to save profile: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Complete Your Profile')),
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

                Text(
                  _isProvider
                      ? 'As a service provider, we need a few more details to verify your identity.'
                      : 'Just a few details to finish setting up your account.',
                  style: TextStyle(color: Colors.grey[700]),
                ),
                const SizedBox(height: 20),

                // Basic profile photo — every user, buyer or provider.
                Center(
                  child: GestureDetector(
                    onTap: _pickProfilePhoto,
                    child: CircleAvatar(
                      radius: 44,
                      backgroundColor: Colors.grey[200],
                      backgroundImage: _profilePhoto != null ? FileImage(_profilePhoto!) : null,
                      child: _profilePhoto == null
                          ? Icon(Icons.add_a_photo_outlined, color: Colors.grey[600], size: 26)
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Text('Profile photo (optional)', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ),
                const SizedBox(height: 20),

                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder()),
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
                  controller: _areaController,
                  decoration: const InputDecoration(
                    labelText: 'Area / Location',
                    hintText: 'e.g. Adenta, Accra',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),

                if (_isProvider) ...[
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 12),
                  const Text('Service Category', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                    items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (v) => setState(() => _selectedCategory = v),
                    validator: (v) => (_isProvider && v == null) ? 'Please select a category' : null,
                  ),

                  if (_needsProviderPhoto) ...[
                    const SizedBox(height: 20),
                    Text(
                      _isOkada
                          ? 'Rider Details'
                          : _isSteelBender
                          ? 'Steel Bender Details'
                          : _isCarpenter
                          ? 'Carpenter Details'
                          : _isTailor
                          ? 'Tailor Details'
                          : _isPlumber
                          ? 'Plumber Details'
                          : _isTeacher
                          ? 'Teacher Details'
                          : _isTiler
                          ? 'Tiler Details'
                          : 'Mechanic Details',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text('Shown to buyers when they view your profile.',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    const SizedBox(height: 12),
                    Center(
                      child: GestureDetector(
                        onTap: _pickProviderPhoto,
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.green[50],
                          backgroundImage: _providerPhoto != null ? FileImage(_providerPhoto!) : null,
                          child: _providerPhoto == null
                              ? Icon(Icons.add_a_photo, color: Colors.green[700], size: 28)
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Center(
                      child: Text('Public photo (shown to app users)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (_isOkada) ...[
                    TextFormField(
                      controller: _plateController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Number Plate',
                        hintText: 'e.g. GT 1234-24',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (_isOkada && (v == null || v.trim().isEmpty)) ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _stationController,
                      decoration: const InputDecoration(
                        labelText: 'Station / Base',
                        hintText: 'e.g. Mataheko main stop',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (_isOkada && (v == null || v.trim().isEmpty)) ? 'Required' : null,
                    ),
                  ],

                  if (_isMechanic) ...[
                    TextFormField(
                      controller: _workshopController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Workshop / Garage Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (_isMechanic && (v == null || v.trim().isEmpty)) ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _experienceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Years of Experience',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (_isMechanic && (v == null || v.trim().isEmpty)) ? 'Required' : null,
                    ),
                    const SizedBox(height: 20),
                    _chipSection('Vehicle Types You Work On', vehicleTypeOptions, _selectedVehicleTypes),
                    const SizedBox(height: 20),
                    _chipSection('Brand Specialties (optional)', brandSpecialtyOptions, _selectedBrands),
                    const SizedBox(height: 20),
                    _chipSection('Services You Offer', serviceOptions, _selectedServices),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Offers Roadside / Breakdown Service', style: TextStyle(fontSize: 13)),
                      value: _offersRoadsideService,
                      activeColor: Colors.green[700],
                      onChanged: (val) => setState(() => _offersRoadsideService = val),
                    ),
                  ],

                  if (_isSteelBender) ...[
                    TextFormField(
                      controller: _workshopController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Workshop / Site Name',
                        hintText: 'e.g. Kofi Steel Works',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (_isSteelBender && (v == null || v.trim().isEmpty)) ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _experienceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Years of Experience',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (_isSteelBender && (v == null || v.trim().isEmpty)) ? 'Required' : null,
                    ),
                    const SizedBox(height: 20),
                    _chipSection('Specialties', SteelBender.specialtyOptions, _selectedSteelSpecialties),
                    const SizedBox(height: 20),
                    _chipSection('Rebar Sizes Handled', SteelBender.rebarSizeOptions, _selectedRebarSizes),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Available for On-Site / Mobile Service', style: TextStyle(fontSize: 13)),
                      subtitle: const Text(
                        'Willing to work at construction sites, not just a fixed shop',
                        style: TextStyle(fontSize: 11),
                      ),
                      value: _offersOnSiteService,
                      activeColor: Colors.green[700],
                      onChanged: (val) => setState(() => _offersOnSiteService = val),
                    ),
                  ],

                  if (_isCarpenter) ...[
                    TextFormField(
                      controller: _workshopController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Workshop / Site Name',
                        hintText: 'e.g. Kwame Carpentry Works',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (_isCarpenter && (v == null || v.trim().isEmpty)) ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _experienceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Years of Experience',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (_isCarpenter && (v == null || v.trim().isEmpty)) ? 'Required' : null,
                    ),
                    const SizedBox(height: 20),
                    _chipSection('Specialties', Carpenter.specialtyOptions, _selectedCarpentrySpecialties),
                    const SizedBox(height: 20),
                    _chipSection('Materials Worked With', Carpenter.materialOptions, _selectedCarpentryMaterials),
                    const SizedBox(height: 20),
                    _chipSection('Services Offered', Carpenter.serviceOptions, _selectedCarpentryServices),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Available for On-Site Installation / Repair', style: TextStyle(fontSize: 13)),
                      subtitle: const Text(
                        'Willing to work at a customer\'s home or site, not just a fixed workshop',
                        style: TextStyle(fontSize: 11),
                      ),
                      value: _offersOnSiteServiceCarpenter,
                      activeColor: Colors.green[700],
                      onChanged: (val) => setState(() => _offersOnSiteServiceCarpenter = val),
                    ),
                  ],

                  if (_isTailor) ...[
                    TextFormField(
                      controller: _workshopController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Shop / Business Name',
                        hintText: 'e.g. Ama\'s Fashion House',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (_isTailor && (v == null || v.trim().isEmpty)) ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _experienceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Years of Experience',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (_isTailor && (v == null || v.trim().isEmpty)) ? 'Required' : null,
                    ),
                    const SizedBox(height: 20),
                    _chipSection('Garment Types You Work On', garmentCategoryOptions, _selectedGarmentTypes),
                    const SizedBox(height: 20),
                    _chipSection('Fabric Specialties (optional)', fabricSpecialtyOptions, _selectedFabrics),
                    const SizedBox(height: 20),
                    _chipSection('Services You Offer', tailoringServiceOptions, _selectedTailoringServices),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Offers Rush / Express Orders', style: TextStyle(fontSize: 13)),
                      value: _offersRushService,
                      activeColor: Colors.green[700],
                      onChanged: (val) => setState(() => _offersRushService = val),
                    ),
                  ],

                  if (_isPlumber) ...[
                    TextFormField(
                      controller: _workshopController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Business Name',
                        hintText: 'e.g. Kwesi Plumbing Services',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (_isPlumber && (v == null || v.trim().isEmpty)) ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _experienceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Years of Experience',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (_isPlumber && (v == null || v.trim().isEmpty)) ? 'Required' : null,
                    ),
                    const SizedBox(height: 20),
                    _chipSection('Property Types Serviced', propertyTypeOptions, _selectedPropertyTypes),
                    const SizedBox(height: 20),
                    _chipSection('Fixture Brands (optional)', fixtureBrandOptions, _selectedFixtureBrands),
                    const SizedBox(height: 20),
                    _chipSection('Services You Offer', plumbingServiceOptions, _selectedPlumbingServices),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Offers Emergency / After-Hours Call-Out', style: TextStyle(fontSize: 13)),
                      value: _offersEmergencyService,
                      activeColor: Colors.green[700],
                      onChanged: (val) => setState(() => _offersEmergencyService = val),
                    ),
                  ],

                  if (_isTiler) ...[
                    TextFormField(
                      controller: _workshopController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Business Name',
                        hintText: 'e.g. Kofi Tiling & Décor',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (_isTiler && (v == null || v.trim().isEmpty)) ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _experienceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Years of Experience',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (_isTiler && (v == null || v.trim().isEmpty)) ? 'Required' : null,
                    ),
                    const SizedBox(height: 20),
                    _chipSection('Specialties You Work On', tilerSpecialtyOptions, _selectedTilerSpecialties),
                    const SizedBox(height: 20),
                    _chipSection('Materials (optional)', tilerMaterialOptions, _selectedTilerMaterials),
                    const SizedBox(height: 20),
                    _chipSection('Services You Offer', tilerServiceOptions, _selectedTilerServices),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Offers On-Site Consultation', style: TextStyle(fontSize: 13)),
                      value: _offersOnSiteConsultation,
                      activeColor: Colors.green[700],
                      onChanged: (val) => setState(() => _offersOnSiteConsultation = val),
                    ),
                  ],

                  if (_isTeacher) ...[
                    TextFormField(
                      controller: _workshopController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'School / Institution',
                        hintText: 'e.g. Mataheko M/A JHS, or "Private Tutor"',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (_isTeacher && (v == null || v.trim().isEmpty)) ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _experienceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Years of Experience',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (_isTeacher && (v == null || v.trim().isEmpty)) ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _selectedQualification,
                      decoration: const InputDecoration(
                        labelText: 'Highest Qualification',
                        border: OutlineInputBorder(),
                      ),
                      items: teacherQualificationOptions
                          .map((q) => DropdownMenuItem(value: q, child: Text(q, style: const TextStyle(fontSize: 13))))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedQualification = v),
                      validator: (v) => (_isTeacher && v == null) ? 'Please select a qualification' : null,
                    ),
                    const SizedBox(height: 20),
                    _chipSection('Class Levels You Teach', classLevelOptions, _selectedClassLevels),
                    const SizedBox(height: 20),
                    _chipSection('Subjects You Teach', subjectOptions, _selectedSubjects),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Offers Home Tutoring', style: TextStyle(fontSize: 13)),
                      value: _offersHomeTutoring,
                      activeColor: Colors.green[700],
                      onChanged: (val) => setState(() => _offersHomeTutoring = val),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Offers Online Tutoring', style: TextStyle(fontSize: 13)),
                      value: _offersOnlineTutoring,
                      activeColor: Colors.green[700],
                      onChanged: (val) => setState(() => _offersOnlineTutoring = val),
                    ),
                  ],

                  const SizedBox(height: 24),
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
                  const SizedBox(height: 4),
                  Text(
                    'Required for anyone offering services on Mataheko, to keep the community safe.',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _ghanaCardController,
                    decoration: const InputDecoration(
                      labelText: 'Ghana Card Number',
                      hintText: 'GHA-XXXXXXXXX-X',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                    (_isProvider && (v == null || v.trim().isEmpty)) ? 'Required for service providers' : null,
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: _pickCardImage,
                    child: Container(
                      height: 140,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red[100]!),
                      ),
                      child: _cardImage == null
                          ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.badge_outlined, color: Colors.red[300], size: 32),
                          const SizedBox(height: 6),
                          Text('Tap to add Ghana Card photo', style: TextStyle(color: Colors.red[300], fontSize: 12)),
                        ],
                      )
                          : ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(_cardImage!, fit: BoxFit.cover, width: double.infinity),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _loading
                      ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                      : const Text('Save & Continue'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}