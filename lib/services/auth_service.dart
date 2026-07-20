import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_role.dart';
import '../models/review.dart';
import '../models/admin_provider_record.dart';
import '../models/home_cook.dart' show MenuItem;
import 'photo_upload_service.dart';
import 'notification_service.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  bool _googleInitialized = false;

  User? get currentUser => _auth.currentUser;
  bool get isLoggedIn => _auth.currentUser != null;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<void> _ensureGoogleInitialized() async {
    if (_googleInitialized) return;
    await _googleSignIn.initialize(
      serverClientId: '621284698388-t53ptqndqirdo1rvsii7ajclcoducva0.apps.googleusercontent.com',
    );
    _googleInitialized = true;
  }

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _db.collection('users').doc(uid);

  /// Saves the role for a user (call right after registration / first Google sign-in).
  Future<void> setUserRole(String uid, UserRole role) async {
    await _userDoc(uid).set({
      'role': role.name,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Returns null if the user has no role saved yet (i.e. needs to pick one).
  Future<UserRole?> getUserRole(String uid) async {
    final snap = await _userDoc(uid).get();
    if (!snap.exists || snap.data()?['role'] == null) return null;
    return UserRole.fromString(snap.data()!['role'] as String);
  }

  /// Returns true if this Firestore user doc already existed before this call.
  Future<bool> _userDocExists(String uid) async {
    final snap = await _userDoc(uid).get();
    return snap.exists;
  }

  Future<User?> signInWithGoogle() async {
    await _ensureGoogleInitialized();

    late final GoogleSignInAccount googleUser;
    try {
      googleUser = await _googleSignIn.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }

    final idToken = googleUser.authentication.idToken;
    final authorization =
        await googleUser.authorizationClient.authorizationForScopes(['email']) ??
            await googleUser.authorizationClient.authorizeScopes(['email']);

    final credential = GoogleAuthProvider.credential(
      accessToken: authorization.accessToken,
      idToken: idToken,
    );

    final result = await _auth.signInWithCredential(credential);
    return result.user;
  }

  /// True if this Google user is brand new and hasn't picked buyer/provider yet.
  Future<bool> isNewGoogleUser(String uid) async => !(await _userDocExists(uid));

  Future<User?> signInWithEmail(String email, String password) async {
    final result = await _auth.signInWithEmailAndPassword(email: email, password: password);
    return result.user;
  }

  Future<User?> registerWithEmail(
      String email,
      String password,
      UserRole role, {
        String? displayName,
      }) async {
    final result = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    if (displayName != null) await result.user?.updateDisplayName(displayName);
    if (result.user != null) {
      await setUserRole(result.user!.uid, role);
    }
    return result.user;
  }

  /// Saves basic profile info + optional Ghana Card details for the
  /// currently signed-in user. Call after registration (and after the
  /// BioDataScreen for providers).
  ///
  /// [category] is the provider's service category (e.g. 'Okada',
  /// 'Electrician'). Only meaningful when role == UserRole.provider, but
  /// it's a plain field on saveUserProfile so buyers just never pass it.
  Future<void> saveUserProfile({
    required String fullName,
    required String phoneNumber,
    required String area,
    String? category,
    String? ghanaCardNumber,
    String? ghanaCardPhotoUrl,
    String? photoUrl,
  }) async {
    final uid = currentUser?.uid;
    if (uid == null) throw Exception('No signed-in user');

    await _userDoc(uid).set({
      'fullName': fullName,
      'phoneNumber': phoneNumber,
      'area': area,
      if (category != null) 'category': category,
      if (ghanaCardNumber != null) 'ghanaCardNumber': ghanaCardNumber,
      if (ghanaCardPhotoUrl != null) 'ghanaCardPhotoUrl': ghanaCardPhotoUrl,
      if (photoUrl != null) 'photoUrl': photoUrl,
      if (ghanaCardNumber != null) 'verificationStatus': 'pending',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Uploads a Ghana Card photo to the PHP host and returns its public URL.
  Future<String> uploadGhanaCardPhoto(String uid, File file) {
    return PhotoUploadService.uploadGhanaCardPhoto(uid: uid, photo: file);
  }

  // ---------------------------------------------------------------------
  // Okada rider registration
  // ---------------------------------------------------------------------

  DocumentReference<Map<String, dynamic>> _riderDoc(String uid) =>
      _db.collection('okada_riders').doc(uid);

  /// Creates/updates the currently signed-in user's doc in `okada_riders`,
  /// keyed by their Firebase UID. Call this from BioDataScreen right after
  /// saveUserProfile() when role == provider and category == 'Okada'.
  ///
  /// Field names here must match OkadaRider.fromMap() exactly
  /// (riderName / numberPlate / stationName / riderPhotoUrl), since that's
  /// what OkadaRidersScreen and RiderDetailScreen read from.
  ///
  /// [riderPhoto] is the rider's public profile photo (separate from the
  /// Ghana Card photo, which stays admin-only and is never shown publicly).
  /// [ghanaCardNumber] / [ghanaCardPhotoUrl] are the same values already
  /// collected/uploaded for the user doc in BioDataScreen -- pass them
  /// through rather than re-collecting them.
  ///
  /// Self-registered riders start as verificationStatus: 'pending' and
  /// won't appear in the public OkadaRidersScreen list until an admin
  /// approves them.
  Future<void> registerAsOkadaRider({
    required String fullName,
    required String phoneNumber,
    required String plateNumber,
    required String station,
    required String ghanaCardNumber,
    String? ghanaCardPhotoUrl,
    File? riderPhoto,
  }) async {
    final uid = currentUser?.uid;
    if (uid == null) throw Exception('No signed-in user');

    String? photoUrl;
    if (riderPhoto != null) {
      photoUrl = await PhotoUploadService.uploadRiderPhoto(uid: uid, photo: riderPhoto);
    }

    await _riderDoc(uid).set({
      'uid': uid,
      'riderName': fullName,
      'phoneNumber': phoneNumber,
      'numberPlate': plateNumber,
      'stationName': station,
      'ghanaCardNumber': ghanaCardNumber,
      if (ghanaCardPhotoUrl != null) 'ghanaCardPhotoUrl': ghanaCardPhotoUrl,
      if (photoUrl != null) 'riderPhotoUrl': photoUrl,
      'verificationStatus': 'pending',
      'isOnline': false,
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Also flag the main user doc, same pattern as isAdmin, so any screen
    // can check "is this user a rider" with a single cheap doc read
    // instead of a second query against okada_riders.
    await _userDoc(uid).set({
      'isRider': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Returns true if the currently signed-in user has isRider: true set
  /// on their Firestore user doc.
  Future<bool> isOkadaRider() async {
    final uid = currentUser?.uid;
    if (uid == null) return false;
    final snap = await _userDoc(uid).get();
    return snap.data()?['isRider'] == true;
  }

  /// Returns true if the currently signed-in user already has a doc in
  /// `okada_riders`. Used by RiderModeScreen to decide whether to show
  /// "Go Online" immediately or ask them to register first.
  Future<bool> isRegisteredOkadaRider() async {
    final uid = currentUser?.uid;
    if (uid == null) return false;
    final snap = await _riderDoc(uid).get();
    return snap.exists;
  }

  /// Fetches the current rider doc (or null if not registered).
  Future<Map<String, dynamic>?> getOkadaRiderDoc() async {
    final uid = currentUser?.uid;
    if (uid == null) return null;
    final snap = await _riderDoc(uid).get();
    return snap.data();
  }

  /// Flips the rider's `isOnline` flag. Called from RiderModeScreen's
  /// "Go Online" / "Go Offline" toggle.
  Future<void> setRiderOnlineStatus(bool isOnline) async {
    final uid = currentUser?.uid;
    if (uid == null) throw Exception('No signed-in user');
    await _riderDoc(uid).set({
      'isOnline': isOnline,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Admin-only: approves a self-registered rider so they start showing up
  /// in the public OkadaRidersScreen list. Call after an admin has checked
  /// their Ghana Card details.
  Future<void> approveOkadaRider(String riderId) async {
    await _riderDoc(riderId).set({
      'verificationStatus': 'approved',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Returns true if the currently signed-in user has isAdmin: true set
  /// on their Firestore user doc.
  Future<bool> isAdmin() async {
    final uid = currentUser?.uid;
    if (uid == null) return false;
    final snap = await _userDoc(uid).get();
    return snap.data()?['isAdmin'] == true;
  }

  Future<void> registerAsMechanic({
    required String fullName,
    required String phoneNumber,
    required String workshopName,
    required String stationArea,
    required int yearsOfExperience,
    required List<String> vehicleTypes,
    required List<String> brandSpecialties,
    required List<String> servicesOffered,
    required bool offersRoadsideService,
    required String ghanaCardNumber,
    String? ghanaCardPhotoUrl,
    File? mechanicPhoto,
  }) async {
    final uid = currentUser?.uid;
    if (uid == null) throw Exception('No signed-in user');

    String? photoUrl;
    if (mechanicPhoto != null) {
      photoUrl = await PhotoUploadService.uploadRiderPhoto(uid: uid, photo: mechanicPhoto);
    }

    await _db.collection('mechanics').doc(uid).set({
      'name': fullName,
      'phoneNumber': phoneNumber,
      'workshopName': workshopName,
      'stationArea': stationArea,
      'yearsOfExperience': yearsOfExperience,
      'vehicleTypes': vehicleTypes,
      'brandSpecialties': brandSpecialties,
      'servicesOffered': servicesOffered,
      'offersRoadsideService': offersRoadsideService,
      'rating': 0.0,
      'reviewCount': 0,
      'isApproved': false,
      'isPending': true,
      'ghanaCardNumber': ghanaCardNumber,
      'photoUrl': photoUrl,
      'ghanaCardPhotoUrl': ghanaCardPhotoUrl,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> approveMechanic(String id) async {
    await _db.collection('mechanics').doc(id).update({
      'isApproved': true,
      'isPending': false,
    });
  }

  // ---------------------------------------------------------------------
  // Mason registration
  // ---------------------------------------------------------------------

  /// Admin-only: makes a mason visible in the public MasonsScreen list.
  /// Mirrors approveMechanic / approveCarpenter. AddMasonScreen currently
  /// writes masons directly with isApproved: true already set, so in
  /// practice this only matters once/if a self-registration path
  /// (registerAsMason) is added.
  Future<void> approveMason(String id) async {
    await _db.collection('masons').doc(id).update({
      'isApproved': true,
      'isPending': false,
    });
  }

  Future<void> registerAsSteelBender({
    required String fullName,
    required String phoneNumber,
    required String workshopName,
    required String stationArea,
    required int yearsOfExperience,
    required List<String> specialties,
    required List<String> rebarSizesHandled,
    required bool offersOnSiteService,
    required String ghanaCardNumber,
    String? ghanaCardPhotoUrl,
    File? steelBenderPhoto,
  }) async {
    final uid = currentUser?.uid;
    if (uid == null) throw Exception('No signed-in user');

    String? photoUrl;
    if (steelBenderPhoto != null) {
      photoUrl = await PhotoUploadService.uploadRiderPhoto(uid: uid, photo: steelBenderPhoto);
    }

    await _db.collection('steel_benders').doc(uid).set({
      'fullName': fullName,
      'phoneNumber': phoneNumber,
      'workshopName': workshopName,
      'stationArea': stationArea,
      'yearsOfExperience': yearsOfExperience,
      'specialties': specialties,
      'rebarSizesHandled': rebarSizesHandled,
      'offersOnSiteService': offersOnSiteService,
      'rating': 0.0,
      'reviewCount': 0,
      'isApproved': false,
      'isPending': true,
      'ghanaCardNumber': ghanaCardNumber,
      'photoUrl': photoUrl,
      'ghanaCardPhotoUrl': ghanaCardPhotoUrl,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> approveSteelBender(String id) async {
    await _db.collection('steel_benders').doc(id).update({
      'isApproved': true,
      'isPending': false,
    });
  }

  // ---------------------------------------------------------------------
  // Carpenter registration
  // ---------------------------------------------------------------------

  /// Self-registration path -- called from BioDataScreen when
  /// role == provider and category == 'Carpenter'. Keyed by the signed-in
  /// user's uid, same shape/lifecycle as registerAsMechanic /
  /// registerAsSteelBender: starts isPending: true / isApproved: false and
  /// only shows up in the public CarpentersScreen list once an admin
  /// approves.
  Future<void> registerAsCarpenter({
    required String fullName,
    required String phoneNumber,
    required String workshopName,
    required String stationArea,
    required int yearsOfExperience,
    required List<String> specialties,
    required List<String> materialsWorkedWith,
    required List<String> servicesOffered,
    required bool offersOnSiteService,
    required String ghanaCardNumber,
    String? ghanaCardPhotoUrl,
    File? carpenterPhoto,
  }) async {
    final uid = currentUser?.uid;
    if (uid == null) throw Exception('No signed-in user');

    String? photoUrl;
    if (carpenterPhoto != null) {
      photoUrl = await PhotoUploadService.uploadRiderPhoto(uid: uid, photo: carpenterPhoto);
    }

    await _db.collection('carpenters').doc(uid).set({
      'fullName': fullName,
      'phoneNumber': phoneNumber,
      'workshopName': workshopName,
      'stationArea': stationArea,
      'yearsOfExperience': yearsOfExperience,
      'specialties': specialties,
      'materialsWorkedWith': materialsWorkedWith,
      'servicesOffered': servicesOffered,
      'offersOnSiteService': offersOnSiteService,
      'rating': 0.0,
      'reviewCount': 0,
      'isApproved': false,
      'isPending': true,
      'ghanaCardNumber': ghanaCardNumber,
      'photoUrl': photoUrl,
      'ghanaCardPhotoUrl': ghanaCardPhotoUrl,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  /// Admin-only: makes a self-registered carpenter visible in the public
  /// CarpentersScreen list. Mirrors approveMechanic / approveSteelBender.
  Future<void> approveCarpenter(String id) async {
    await _db.collection('carpenters').doc(id).update({
      'isApproved': true,
      'isPending': false,
    });
  }

  Future<String> addCarpenterByAdmin({
    required String fullName,
    required String phoneNumber,
    required String workshopName,
    required String stationArea,
    required int yearsOfExperience,
    required List<String> specialties,
    required List<String> materialsWorkedWith,
    required List<String> servicesOffered,
    required bool offersOnSiteService,
    String? ghanaCardNumber,
    String? ghanaCardPhotoUrl,
    String? photoUrl,
  }) async {
    final docRef = _db.collection('carpenters').doc();
    await docRef.set({
      'fullName': fullName,
      'phoneNumber': phoneNumber,
      'workshopName': workshopName,
      'stationArea': stationArea,
      'yearsOfExperience': yearsOfExperience,
      'specialties': specialties,
      'materialsWorkedWith': materialsWorkedWith,
      'servicesOffered': servicesOffered,
      'offersOnSiteService': offersOnSiteService,
      'rating': 0.0,
      'reviewCount': 0,
      'isApproved': false,
      'isPending': true,
      'ghanaCardNumber': ghanaCardNumber ?? '',
      'photoUrl': photoUrl,
      'ghanaCardPhotoUrl': ghanaCardPhotoUrl,
      'createdAt': DateTime.now().toIso8601String(),
    });
    return docRef.id;
  }


  // ---------------------------------------------------------------------
  // Tailor registration
  // ---------------------------------------------------------------------

  /// Self-registration path -- called from BioDataScreen when
  /// role == provider and category == 'Tailor'. Keyed by the signed-in
  /// user's uid, same shape/lifecycle as registerAsCarpenter /
  /// registerAsPlumber: starts isPending: true / isApproved: false and
  /// only shows up in the public TailorsScreen list once an admin approves.
  ///
  /// TailorsScreen orders the 'tailors' collection by 'createdAt'
  /// descending, so this must always set that field (as a Timestamp, via
  /// FieldValue.serverTimestamp(), so ordering works correctly).
  Future<void> registerAsTailor({
    required String fullName,
    required String phoneNumber,
    required String businessName,
    required String stationArea,
    required int yearsOfExperience,
    required List<String> garmentTypesServiced,
    required List<String> fabricSpecialties,
    required List<String> servicesOffered,
    required bool offersRushService,
    required String ghanaCardNumber,
    String? ghanaCardPhotoUrl,
    File? tailorPhoto,
  }) async {
    final uid = currentUser?.uid;
    if (uid == null) throw Exception('No signed-in user');

    String? photoUrl;
    if (tailorPhoto != null) {
      photoUrl = await PhotoUploadService.uploadRiderPhoto(uid: uid, photo: tailorPhoto);
    }

    await _db.collection('tailors').doc(uid).set({
      'name': fullName,
      'phoneNumber': phoneNumber,
      'businessName': businessName,
      'stationArea': stationArea,
      'yearsOfExperience': yearsOfExperience,
      'garmentTypesServiced': garmentTypesServiced,
      'fabricSpecialties': fabricSpecialties,
      'servicesOffered': servicesOffered,
      'offersRushService': offersRushService,
      'rating': 0.0,
      'reviewCount': 0,
      'isApproved': false,
      'isPending': true,
      'ghanaCardNumber': ghanaCardNumber,
      'photoUrl': photoUrl,
      'ghanaCardPhotoUrl': ghanaCardPhotoUrl,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Admin-only: makes a self-registered tailor visible in the public
  /// TailorsScreen list. Mirrors approveMechanic / approveCarpenter.
  Future<void> approveTailor(String id) async {
    await _db.collection('tailors').doc(id).update({
      'isApproved': true,
      'isPending': false,
    });
  }

  Future<void> registerAsPlumber({
    required String fullName,
    required String phoneNumber,
    required String businessName,
    required String stationArea,
    required int yearsOfExperience,
    required List<String> propertyTypesServiced,
    required List<String> fixtureBrands,
    required List<String> servicesOffered,
    required bool offersEmergencyService,
    required String ghanaCardNumber,
    String? ghanaCardPhotoUrl,
    File? plumberPhoto,
  }) async {
    final uid = currentUser?.uid;
    if (uid == null) throw Exception('No signed-in user');

    String? photoUrl;
    if (plumberPhoto != null) {
      photoUrl = await PhotoUploadService.uploadRiderPhoto(uid: uid, photo: plumberPhoto);
    }

    await _db.collection('plumbers').doc(uid).set({
      'name': fullName,
      'phoneNumber': phoneNumber,
      'businessName': businessName,
      'stationArea': stationArea,
      'yearsOfExperience': yearsOfExperience,
      'propertyTypesServiced': propertyTypesServiced,
      'fixtureBrands': fixtureBrands,
      'servicesOffered': servicesOffered,
      'offersEmergencyService': offersEmergencyService,
      'rating': 0.0,
      'reviewCount': 0,
      'isApproved': false,
      'isPending': true,
      'ghanaCardNumber': ghanaCardNumber,
      'photoUrl': photoUrl,
      'ghanaCardPhotoUrl': ghanaCardPhotoUrl,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  /// Admin-only: makes a self-registered plumber visible in the public
  /// PlumbersScreen list. Mirrors approveMechanic / approveSteelBender.
  Future<void> approvePlumber(String id) async {
    await _db.collection('plumbers').doc(id).update({
      'isApproved': true,
      'isPending': false,
    });
  }


  // ---------------------------------------------------------------------
  // Tiler registration
  // ---------------------------------------------------------------------

  /// Self-registration path -- called from BioDataScreen when
  /// role == provider and category == 'Tiler'. Same lifecycle as
  /// registerAsTailor/registerAsPlumber: starts isPending: true /
  /// isApproved: false and only shows up publicly once an admin approves.
  Future<void> registerAsTiler({
    required String fullName,
    required String phoneNumber,
    required String businessName,
    required String stationArea,
    required int yearsOfExperience,
    required List<String> specialtiesServiced,
    required List<String> materialsWorkedWith,
    required List<String> servicesOffered,
    required bool offersOnSiteConsultation,
    required String ghanaCardNumber,
    String? ghanaCardPhotoUrl,
    File? tilerPhoto,
  }) async {
    final uid = currentUser?.uid;
    if (uid == null) throw Exception('No signed-in user');

    String? photoUrl;
    if (tilerPhoto != null) {
      photoUrl = await PhotoUploadService.uploadRiderPhoto(uid: uid, photo: tilerPhoto);
    }

    await _db.collection('tilers').doc(uid).set({
      'name': fullName,
      'phoneNumber': phoneNumber,
      'businessName': businessName,
      'stationArea': stationArea,
      'yearsOfExperience': yearsOfExperience,
      'specialtiesServiced': specialtiesServiced,
      'materialsWorkedWith': materialsWorkedWith,
      'servicesOffered': servicesOffered,
      'offersOnSiteConsultation': offersOnSiteConsultation,
      'rating': 0.0,
      'reviewCount': 0,
      'isApproved': false,
      'isPending': true,
      'ghanaCardNumber': ghanaCardNumber,
      'photoUrl': photoUrl,
      'ghanaCardPhotoUrl': ghanaCardPhotoUrl,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Admin-only: makes a self-registered tiler visible in the public
  /// TilersScreen list (create one if it doesn't exist yet, same pattern
  /// as TailorsScreen/PlumbersScreen). Mirrors approveTailor/approvePlumber.
  Future<void> approveTiler(String id) async {
    await _db.collection('tilers').doc(id).update({
      'isApproved': true,
      'isPending': false,
    });
  }

  /// Admin-adds-directly path -- mirrors addCarpenterByAdmin. Field names
  /// match Tiler.fromMap() (name/businessName/specialtiesServiced/
  /// materialsWorkedWith/offersOnSiteConsultation), same as registerAsTiler
  /// above, so docs written here read back correctly everywhere else.
  Future<String> addTilerByAdmin({
    required String fullName,
    required String phoneNumber,
    required String businessName,
    required String stationArea,
    required int yearsOfExperience,
    required List<String> specialtiesServiced,
    required List<String> materialsWorkedWith,
    required List<String> servicesOffered,
    required bool offersOnSiteConsultation,
    String? ghanaCardNumber,
    String? ghanaCardPhotoUrl,
    String? photoUrl,
  }) async {
    final docRef = _db.collection('tilers').doc();
    await docRef.set({
      'name': fullName,
      'phoneNumber': phoneNumber,
      'businessName': businessName,
      'stationArea': stationArea,
      'yearsOfExperience': yearsOfExperience,
      'specialtiesServiced': specialtiesServiced,
      'materialsWorkedWith': materialsWorkedWith,
      'servicesOffered': servicesOffered,
      'offersOnSiteConsultation': offersOnSiteConsultation,
      'rating': 0.0,
      'reviewCount': 0,
      'isApproved': true,
      'isPending': false,
      'ghanaCardNumber': ghanaCardNumber ?? '',
      'photoUrl': photoUrl,
      'ghanaCardPhotoUrl': ghanaCardPhotoUrl,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  // ---------------------------------------------------------------------
  // Home Cook registration
  // ---------------------------------------------------------------------

  /// Self-registration path -- called from BioDataScreen when
  /// role == provider and category == 'Home Food'. Keyed by the signed-in
  /// user's uid, same shape/lifecycle as registerAsTiler / registerAsTailor:
  /// starts isPending: true / isApproved: false and only shows up in the
  /// public HomeCooksScreen list once an admin approves.
  ///
  /// [menu] is a list of MenuItem so BioDataScreen can build the dish list
  /// the same way AddHomeCookScreen does; it's serialized via
  /// MenuItem.toMap() to match HomeCook.fromMap()'s expectations.
  Future<void> registerAsHomeCook({
    required String fullName,
    required String phoneNumber,
    required String businessName,
    required String stationArea,
    required List<String> cuisineTypes,
    required List<String> deliveryAreas,
    required bool offersDelivery,
    required List<MenuItem> menu,
    required String ghanaCardNumber,
    String? ghanaCardPhotoUrl,
    File? cookPhoto,
  }) async {
    final uid = currentUser?.uid;
    if (uid == null) throw Exception('No signed-in user');

    String? photoUrl;
    if (cookPhoto != null) {
      photoUrl = await PhotoUploadService.uploadRiderPhoto(uid: uid, photo: cookPhoto);
    }

    await _db.collection('home_cooks').doc(uid).set({
      'name': fullName,
      'phoneNumber': phoneNumber,
      'businessName': businessName,
      'stationArea': stationArea,
      'cuisineTypes': cuisineTypes,
      'deliveryAreas': deliveryAreas,
      'offersDelivery': offersDelivery,
      'menu': menu.map((m) => m.toMap()).toList(),
      'rating': 0.0,
      'reviewCount': 0,
      'isApproved': false,
      'isPending': true,
      'ghanaCardNumber': ghanaCardNumber,
      'photoUrl': photoUrl,
      'ghanaCardPhotoUrl': ghanaCardPhotoUrl,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Admin-only: makes a home cook visible in the public HomeCooksScreen
  /// list. Mirrors approveTailor / approveTiler.
  Future<void> approveHomeCook(String id) async {
    await _db.collection('home_cooks').doc(id).update({
      'isApproved': true,
      'isPending': false,
    });
  }

  /// Admin-adds-directly path -- mirrors addTilerByAdmin. Field names
  /// match HomeCook.fromMap() exactly (name/businessName/cuisineTypes/
  /// deliveryAreas/offersDelivery/menu), same as registerAsHomeCook above.
  Future<String> addHomeCookByAdmin({
    required String fullName,
    required String phoneNumber,
    required String businessName,
    required String stationArea,
    required List<String> cuisineTypes,
    required List<String> deliveryAreas,
    required bool offersDelivery,
    required List<MenuItem> menu,
    String? ghanaCardNumber,
    String? ghanaCardPhotoUrl,
    String? photoUrl,
  }) async {
    final docRef = _db.collection('home_cooks').doc();
    await docRef.set({
      'name': fullName,
      'phoneNumber': phoneNumber,
      'businessName': businessName,
      'stationArea': stationArea,
      'cuisineTypes': cuisineTypes,
      'deliveryAreas': deliveryAreas,
      'offersDelivery': offersDelivery,
      'menu': menu.map((m) => m.toMap()).toList(),
      'rating': 0.0,
      'reviewCount': 0,
      'isApproved': true,
      'isPending': false,
      'ghanaCardNumber': ghanaCardNumber ?? '',
      'photoUrl': photoUrl,
      'ghanaCardPhotoUrl': ghanaCardPhotoUrl,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  // ---------------------------------------------------------------------
  // Hotel registration
  // ---------------------------------------------------------------------

  /// Uploads each photo under its own path (uid + index) so multiple
  /// photos for the same hotel don't overwrite one another -- uid here is
  /// just a folder/prefix, not a Firestore document key. Order of [photos]
  /// is preserved in the returned list, and the first URL doubles as the
  /// cover photo (see Hotel.coverPhotoUrl).
  ///
  /// Uses uploadListingPhoto (type: 'listing_photos') rather than
  /// uploadRiderPhoto -- these are property photos, not a single provider's
  /// profile photo, so they belong in their own upload folder.
  Future<List<String>> _uploadHotelPhotos(String uidPrefix, List<File> photos) async {
    final urls = <String>[];
    for (var i = 0; i < photos.length; i++) {
      final url = await PhotoUploadService.uploadListingPhoto(
        uid: '${uidPrefix}_photo$i',
        photo: photos[i],
      );
      urls.add(url);
    }
    return urls;
  }

  /// Self-registration path -- called from BioDataScreen when
  /// role == provider and category == 'Hotel'. Keyed by the signed-in
  /// user's uid, same shape/lifecycle as registerAsHomeCook: starts
  /// isPending: true / isApproved: false and only shows up in the public
  /// HotelsScreen list once an admin approves.
  Future<void> registerAsHotel({
    required String fullName,
    required String phoneNumber,
    required String businessName,
    required String stationArea,
    required List<String> roomTypes,
    required List<String> amenities,
    required double priceRangeMin,
    required double priceRangeMax,
    required int numberOfRooms,
    required String checkInTime,
    required String checkOutTime,
    required bool offersFreeBreakfast,
    required bool offersAirportPickup,
    required bool acceptsWalkIns,
    required String ghanaCardNumber,
    String? ghanaCardPhotoUrl,
    List<File> photos = const [],
  }) async {
    final uid = currentUser?.uid;
    if (uid == null) throw Exception('No signed-in user');

    final photoUrls = photos.isEmpty ? <String>[] : await _uploadHotelPhotos(uid, photos);

    await _db.collection('hotels').doc(uid).set({
      'name': fullName,
      'phoneNumber': phoneNumber,
      'businessName': businessName,
      'stationArea': stationArea,
      'roomTypes': roomTypes,
      'amenities': amenities,
      'priceRangeMin': priceRangeMin,
      'priceRangeMax': priceRangeMax,
      'numberOfRooms': numberOfRooms,
      'checkInTime': checkInTime,
      'checkOutTime': checkOutTime,
      'offersFreeBreakfast': offersFreeBreakfast,
      'offersAirportPickup': offersAirportPickup,
      'acceptsWalkIns': acceptsWalkIns,
      'photoUrls': photoUrls,
      'rating': 0.0,
      'reviewCount': 0,
      'isApproved': false,
      'isPending': true,
      'ghanaCardNumber': ghanaCardNumber,
      if (ghanaCardPhotoUrl != null) 'ghanaCardPhotoUrl': ghanaCardPhotoUrl,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Admin-only: makes a hotel visible in the public HotelsScreen list.
  /// Mirrors approveHomeCook / approveTiler.
  Future<void> approveHotel(String id) async {
    await _db.collection('hotels').doc(id).update({
      'isApproved': true,
      'isPending': false,
    });
  }

  /// Admin-adds-directly path -- mirrors addTilerByAdmin / addElectricianByAdmin.
  /// Deliberately still starts isPending: true / isApproved: false (unlike
  /// addHomeCookByAdmin, which auto-approves) so every new hotel gets one
  /// review tap on HotelsScreen before it's public -- same as every other
  /// admin-add screen in the app.
  Future<String> addHotelByAdmin({
    required String fullName,
    required String phoneNumber,
    required String businessName,
    required String stationArea,
    required List<String> roomTypes,
    required List<String> amenities,
    required double priceRangeMin,
    required double priceRangeMax,
    required int numberOfRooms,
    required String checkInTime,
    required String checkOutTime,
    required bool offersFreeBreakfast,
    required bool offersAirportPickup,
    required bool acceptsWalkIns,
    List<File> photos = const [],
    String? ghanaCardNumber,
    File? ghanaCardImage,
  }) async {
    final docRef = _db.collection('hotels').doc();
    // Admin-added entries don't have a signed-in uid to key uploads by, so
    // use the new doc's own id as the upload-path prefix instead.
    final uploadKey = 'admin_${docRef.id}';

    final photoUrls = photos.isEmpty ? <String>[] : await _uploadHotelPhotos(uploadKey, photos);

    String? ghanaCardPhotoUrl;
    if (ghanaCardImage != null) {
      ghanaCardPhotoUrl = await PhotoUploadService.uploadGhanaCardPhoto(uid: uploadKey, photo: ghanaCardImage);
    }

    await docRef.set({
      'name': fullName,
      'phoneNumber': phoneNumber,
      'businessName': businessName,
      'stationArea': stationArea,
      'roomTypes': roomTypes,
      'amenities': amenities,
      'priceRangeMin': priceRangeMin,
      'priceRangeMax': priceRangeMax,
      'numberOfRooms': numberOfRooms,
      'checkInTime': checkInTime,
      'checkOutTime': checkOutTime,
      'offersFreeBreakfast': offersFreeBreakfast,
      'offersAirportPickup': offersAirportPickup,
      'acceptsWalkIns': acceptsWalkIns,
      'photoUrls': photoUrls,
      'rating': 0.0,
      'reviewCount': 0,
      'isApproved': false,
      'isPending': true,
      'ghanaCardNumber': ghanaCardNumber ?? '',
      'ghanaCardPhotoUrl': ghanaCardPhotoUrl,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  // ---------------------------------------------------------------------
  // Teacher registration
  // ---------------------------------------------------------------------

  /// Self-registration path -- called from BioDataScreen when
  /// role == provider and category == 'Teacher'. Same lifecycle as
  /// registerAsTailor/registerAsPlumber: starts isPending: true /
  /// isApproved: false and only shows up publicly once an admin approves.
  Future<void> registerAsTeacher({
    required String fullName,
    required String phoneNumber,
    required String schoolOrInstitution,
    required String stationArea,
    required int yearsOfExperience,
    required String qualification,
    required List<String> subjectsTaught,
    required List<String> classLevelsTaught,
    required bool offersHomeTutoring,
    required bool offersOnlineTutoring,
    required String ghanaCardNumber,
    String? ghanaCardPhotoUrl,
    File? teacherPhoto,
  }) async {
    final uid = currentUser?.uid;
    if (uid == null) throw Exception('No signed-in user');

    String? photoUrl;
    if (teacherPhoto != null) {
      photoUrl = await PhotoUploadService.uploadRiderPhoto(uid: uid, photo: teacherPhoto);
    }

    await _db.collection('teachers').doc(uid).set({
      'fullName': fullName,
      'phoneNumber': phoneNumber,
      'schoolOrInstitution': schoolOrInstitution,
      'stationArea': stationArea,
      'yearsOfExperience': yearsOfExperience,
      'qualification': qualification,
      'subjectsTaught': subjectsTaught,
      'classLevelsTaught': classLevelsTaught,
      'offersHomeTutoring': offersHomeTutoring,
      'offersOnlineTutoring': offersOnlineTutoring,
      'rating': 0.0,
      'reviewCount': 0,
      'isApproved': false,
      'isPending': true,
      'ghanaCardNumber': ghanaCardNumber,
      'photoUrl': photoUrl,
      'ghanaCardPhotoUrl': ghanaCardPhotoUrl,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  /// Admin-adds-directly path -- mirrors addElectricianByAdmin/
  /// addCarpenterByAdmin. Auto-generated doc ID since the admin is
  /// entering someone else's details.
  Future<String> addTeacherByAdmin({
    required String fullName,
    required String phoneNumber,
    required String schoolOrInstitution,
    required String stationArea,
    required int yearsOfExperience,
    required String qualification,
    required List<String> subjectsTaught,
    required List<String> classLevelsTaught,
    required bool offersHomeTutoring,
    required bool offersOnlineTutoring,
    String? ghanaCardNumber,
    String? ghanaCardPhotoUrl,
    String? photoUrl,
  }) async {
    final docRef = _db.collection('teachers').doc();
    await docRef.set({
      'fullName': fullName,
      'phoneNumber': phoneNumber,
      'schoolOrInstitution': schoolOrInstitution,
      'stationArea': stationArea,
      'yearsOfExperience': yearsOfExperience,
      'qualification': qualification,
      'subjectsTaught': subjectsTaught,
      'classLevelsTaught': classLevelsTaught,
      'offersHomeTutoring': offersHomeTutoring,
      'offersOnlineTutoring': offersOnlineTutoring,
      'rating': 0.0,
      'reviewCount': 0,
      'isApproved': false,
      'isPending': true,
      'ghanaCardNumber': ghanaCardNumber ?? '',
      'photoUrl': photoUrl,
      'ghanaCardPhotoUrl': ghanaCardPhotoUrl,
      'createdAt': DateTime.now().toIso8601String(),
    });
    return docRef.id;
  }

  /// Admin-only: makes a teacher visible in the public TeachersScreen list.
  Future<void> approveTeacher(String id) async {
    await _db.collection('teachers').doc(id).update({
      'isApproved': true,
      'isPending': false,
    });
  }

  // ---------------------------------------------------------------------
  // Welder registration
  // ---------------------------------------------------------------------

  /// Self-registration path -- called from BioDataScreen when
  /// role == provider and category == 'Welder'. Keyed by the signed-in
  /// user's uid, same shape/lifecycle as registerAsCarpenter /
  /// registerAsTiler: starts isPending: true / isApproved: false and only
  /// shows up in the public WeldersScreen list once an admin approves.
  Future<void> registerAsWelder({
    required String fullName,
    required String phoneNumber,
    required String businessName,
    required String stationArea,
    required int yearsOfExperience,
    required List<String> specialtiesServiced,
    required List<String> materialsWorkedWith,
    required List<String> servicesOffered,
    required bool offersOnSiteService,
    required String ghanaCardNumber,
    String? ghanaCardPhotoUrl,
    File? welderPhoto,
  }) async {
    final uid = currentUser?.uid;
    if (uid == null) throw Exception('No signed-in user');

    String? photoUrl;
    if (welderPhoto != null) {
      photoUrl = await PhotoUploadService.uploadRiderPhoto(uid: uid, photo: welderPhoto);
    }

    await _db.collection('welders').doc(uid).set({
      'name': fullName,
      'phoneNumber': phoneNumber,
      'businessName': businessName,
      'stationArea': stationArea,
      'yearsOfExperience': yearsOfExperience,
      'specialtiesServiced': specialtiesServiced,
      'materialsWorkedWith': materialsWorkedWith,
      'servicesOffered': servicesOffered,
      'offersOnSiteService': offersOnSiteService,
      'rating': 0.0,
      'reviewCount': 0,
      'isApproved': false,
      'isPending': true,
      'ghanaCardNumber': ghanaCardNumber,
      'photoUrl': photoUrl,
      'ghanaCardPhotoUrl': ghanaCardPhotoUrl,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Admin-only: makes a self-registered welder visible in the public
  /// WeldersScreen list. Mirrors approveTailor / approveTiler.
  Future<void> approveWelder(String id) async {
    await _db.collection('welders').doc(id).update({
      'isApproved': true,
      'isPending': false,
    });
  }

  /// Admin-adds-directly path -- mirrors addTilerByAdmin. Field names
  /// match Welder.fromMap() exactly (name/businessName/specialtiesServiced/
  /// materialsWorkedWith/offersOnSiteService), same as registerAsWelder
  /// above.
  Future<String> addWelderByAdmin({
    required String fullName,
    required String phoneNumber,
    required String businessName,
    required String stationArea,
    required int yearsOfExperience,
    required List<String> specialtiesServiced,
    required List<String> materialsWorkedWith,
    required List<String> servicesOffered,
    required bool offersOnSiteService,
    String? ghanaCardNumber,
    String? ghanaCardPhotoUrl,
    String? photoUrl,
  }) async {
    final docRef = _db.collection('welders').doc();
    await docRef.set({
      'name': fullName,
      'phoneNumber': phoneNumber,
      'businessName': businessName,
      'stationArea': stationArea,
      'yearsOfExperience': yearsOfExperience,
      'specialtiesServiced': specialtiesServiced,
      'materialsWorkedWith': materialsWorkedWith,
      'servicesOffered': servicesOffered,
      'offersOnSiteService': offersOnSiteService,
      'rating': 0.0,
      'reviewCount': 0,
      'isApproved': true,
      'isPending': false,
      'ghanaCardNumber': ghanaCardNumber ?? '',
      'photoUrl': photoUrl,
      'ghanaCardPhotoUrl': ghanaCardPhotoUrl,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  // ---------------------------------------------------------------------
  // Electrician registration
  // ---------------------------------------------------------------------

  /// Self-registration path -- called from BioDataScreen when
  /// role == provider and category == 'Electrician'. Keyed by the signed-in
  /// user's uid, same shape/lifecycle as registerAsMechanic /
  /// registerAsPlumber: starts isPending: true / isApproved: false and only
  /// shows up in the public ElectriciansScreen list once an admin approves.
  Future<void> registerAsElectrician({
    required String fullName,
    required String phoneNumber,
    required String businessName,
    required String stationArea,
    required int yearsOfExperience,
    required List<String> propertyTypesServiced,
    required List<String> servicesOffered,
    required bool offersEmergencyService,
    required String ghanaCardNumber,
    String? ghanaCardPhotoUrl,
    File? electricianPhoto,
  }) async {
    final uid = currentUser?.uid;
    if (uid == null) throw Exception('No signed-in user');

    String? photoUrl;
    if (electricianPhoto != null) {
      photoUrl = await PhotoUploadService.uploadRiderPhoto(uid: uid, photo: electricianPhoto);
    }

    await _db.collection('electricians').doc(uid).set({
      'name': fullName,
      'phoneNumber': phoneNumber,
      'businessName': businessName,
      'stationArea': stationArea,
      'yearsOfExperience': yearsOfExperience,
      'propertyTypesServiced': propertyTypesServiced,
      'servicesOffered': servicesOffered,
      'offersEmergencyService': offersEmergencyService,
      'rating': 0.0,
      'reviewCount': 0,
      'isApproved': false,
      'isPending': true,
      'ghanaCardNumber': ghanaCardNumber,
      'photoUrl': photoUrl,
      'ghanaCardPhotoUrl': ghanaCardPhotoUrl,
      'createdAt': DateTime.now().toIso8601String(),
    });

    // Same cheap-flag pattern as isAdmin/isRider, in case other screens
    // ever need "is this signed-in user a registered electrician" without
    // a second query against the electricians collection.
    await _userDoc(uid).set({
      'isElectrician': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Admin-adds-directly path -- called from AddElectricianScreen. Unlike
  /// self-registration this isn't keyed to any particular uid (the admin
  /// is entering someone else's details), so it gets an auto-generated doc
  /// ID. Still starts isPending: true / isApproved: false so it goes
  /// through the exact same one-tap "Approve" flow in ElectriciansScreen --
  /// there's deliberately no separate "admin-added = auto approved" path,
  /// so every entry gets the same final human check before going public.
  Future<String> addElectricianByAdmin({
    required String fullName,
    required String phoneNumber,
    required String businessName,
    required String stationArea,
    required int yearsOfExperience,
    required List<String> propertyTypesServiced,
    required List<String> servicesOffered,
    required bool offersEmergencyService,
    String? ghanaCardNumber,
    String? ghanaCardPhotoUrl,
    String? photoUrl,
  }) async {
    final docRef = _db.collection('electricians').doc();
    await docRef.set({
      'name': fullName,
      'phoneNumber': phoneNumber,
      'businessName': businessName,
      'stationArea': stationArea,
      'yearsOfExperience': yearsOfExperience,
      'propertyTypesServiced': propertyTypesServiced,
      'servicesOffered': servicesOffered,
      'offersEmergencyService': offersEmergencyService,
      'rating': 0.0,
      'reviewCount': 0,
      'isApproved': false,
      'isPending': true,
      'ghanaCardNumber': ghanaCardNumber ?? '',
      'photoUrl': photoUrl,
      'ghanaCardPhotoUrl': ghanaCardPhotoUrl,
      'createdAt': DateTime.now().toIso8601String(),
    });
    return docRef.id;
  }

  /// Admin-only: makes an electrician visible in the public
  /// ElectriciansScreen list. Mirrors approveMechanic / approvePlumber.
  Future<void> approveElectrician(String id) async {
    await _db.collection('electricians').doc(id).update({
      'isApproved': true,
      'isPending': false,
    });
  }

  /// Live stream of an electrician's reviews, newest first. Used by
  /// ElectricianDetailScreen to render the review list.
  Stream<QuerySnapshot<Map<String, dynamic>>> electricianReviewsStream(String electricianId) {
    return _db
        .collection('electricians')
        .doc(electricianId)
        .collection('reviews')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Adds a review for an electrician and atomically recalculates the
  /// electrician's running `rating` average + `reviewCount`, so every
  /// list/detail screen showing that electrician stays correct without
  /// ever needing to read the whole reviews subcollection.
  ///
  /// Uses a Firestore transaction so two reviews submitted at nearly the
  /// same time can't clobber each other's rating update.
  Future<void> submitElectricianReview({
    required String electricianId,
    required String reviewerName,
    required double rating,
    String comment = '',
  }) async {
    final docRef = _db.collection('electricians').doc(electricianId);
    final reviewRef = docRef.collection('reviews').doc();

    await _db.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      final data = snap.data() ?? <String, dynamic>{};
      final currentCount = (data['reviewCount'] ?? 0) as int;
      final currentRating = (data['rating'] ?? 0.0).toDouble();

      final newCount = currentCount + 1;
      final newRating = ((currentRating * currentCount) + rating) / newCount;

      tx.set(reviewRef, Review(
        id: reviewRef.id,
        reviewerName: reviewerName.trim().isEmpty ? 'Anonymous' : reviewerName.trim(),
        rating: rating,
        comment: comment.trim(),
      ).toMap());

      tx.update(docRef, {
        // Round to 2dp so the average doesn't grow long floating-point tails.
        'rating': double.parse(newRating.toStringAsFixed(2)),
        'reviewCount': newCount,
      });
    });
  }

  // ---------------------------------------------------------------------
  // Admin: unified provider management (all categories)
  // ---------------------------------------------------------------------

  /// Collection name for every provider category, keyed by the same
  /// category label used in HomeScreen's categories list.
  static const Map<String, String> providerCollections = {
    'Okada': 'okada_riders',
    'Mechanic': 'mechanics',
    'Steel Bender': 'steel_benders',
    'Carpenter': 'carpenters',
    'Tailor': 'tailors',
    'Plumber': 'plumbers',
    'Electrician': 'electricians',
    'Mason': 'masons',
    'Tiler': 'tilers',
    'Welder': 'welders',
    'Hotel': 'hotels',
  };

  /// Fetches every provider doc across all categories in one call,
  /// tagged with its category + source collection so ManageProvidersScreen
  /// can show a single unified list and know where to write edits/deletes
  /// back to. This is a one-shot fetch rather than a live stream --
  /// Firestore doesn't merge multiple collection streams into one without
  /// an extra package -- so ManageProvidersScreen just re-calls this on
  /// pull-to-refresh and after any edit/delete.
  Future<List<AdminProviderRecord>> fetchAllProviders() async {
    final results = await Future.wait(
      providerCollections.entries.map((entry) async {
        final snap = await _db.collection(entry.value).get();
        return snap.docs.map(
              (doc) => AdminProviderRecord(
            id: doc.id,
            category: entry.key,
            collection: entry.value,
            data: doc.data(),
          ),
        );
      }),
    );
    final all = results.expand((r) => r).toList();
    all.sort((a, b) =>
        a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
    return all;
  }

  /// Generic field update for any provider doc -- merges [data] onto the
  /// doc so fields not included are left untouched. Works across every
  /// category since it only needs the collection name (from
  /// AdminProviderRecord.collection), not category-specific logic.
  Future<void> updateProviderRecord(
      String collection, String id, Map<String, dynamic> data) async {
    await _db.collection(collection).doc(id).set(data, SetOptions(merge: true));
  }

  /// Generic approve/unapprove -- normalizes the two different status
  /// shapes used across collections (okada_riders' 'verificationStatus'
  /// string vs every other category's isApproved/isPending booleans)
  /// behind one call, so ManageProvidersScreen doesn't need a switch.
  Future<void> setProviderApproved(
      String collection, String id, bool approved) async {
    if (collection == 'okada_riders') {
      await _db.collection(collection).doc(id).set({
        'verificationStatus': approved ? 'approved' : 'pending',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } else {
      await _db.collection(collection).doc(id).update({
        'isApproved': approved,
        'isPending': !approved,
      });
    }
  }

  /// Deletes only the provider's listing doc (e.g. mechanics/{id}).
  /// Leaves users/{uid} and the Firebase Auth account untouched -- pair
  /// with deleteUserAccountData for a full removal.
  Future<void> deleteProviderRecord(String collection, String id) async {
    await _db.collection(collection).doc(id).delete();
  }

  /// Deletes the provider's users/{uid} Firestore profile doc.
  ///
  /// IMPORTANT: this does NOT delete their Firebase Auth account. The
  /// client SDK can only delete the *currently signed-in* user's own auth
  /// account (FirebaseAuth.instance.currentUser.delete()) -- it has no way
  /// to delete an arbitrary other user's account by uid. Fully revoking
  /// their login requires a Cloud Function using the Admin SDK
  /// (admin.auth().deleteUser(uid)), or manual removal in the Firebase
  /// Console under Authentication > Users. Deleting this Firestore doc
  /// does remove them from every in-app admin/role check though, since
  /// isAdmin/isRider/role all read from this same doc.
  Future<void> deleteUserAccountData(String uid) async {
    await _userDoc(uid).delete();
  }

  /// Convenience: deletes both the provider listing and the linked
  /// users/{uid} profile doc in one call. See deleteUserAccountData's
  /// note -- the underlying Auth login is not removed by this.
  /// Safe to call even when there's no matching users doc (e.g. the
  /// provider was added directly by an admin, not self-registered):
  /// deleting a non-existent doc is a no-op in Firestore.
  Future<void> deleteProviderAndUserData({
    required String collection,
    required String providerId,
    required String possibleUid,
  }) async {
    await deleteProviderRecord(collection, providerId);
    await deleteUserAccountData(possibleUid);
  }

  /// Fully rolls back a registration that was abandoned before the user
  /// finished BioDataScreen.
  ///
  /// registerWithEmail / the Google new-user path both write a *stub*
  /// users/{uid} doc (role only, no fullName/phone/area yet) before
  /// BioDataScreen ever opens. If the person backs out of that screen
  /// instead of submitting it, that stub -- and the Firebase Auth account
  /// created to hold it -- would otherwise sit in the database forever
  /// with no real profile behind it. This deletes both, so an abandoned
  /// sign-up leaves nothing behind and the same email can be used to
  /// register again cleanly.
  ///
  /// Safe to call even if a real profile WAS already saved: it only
  /// deletes the users/{uid} doc when fullName is still missing, so a
  /// returning user with a completed profile is never touched by this.
  Future<void> deleteIncompleteRegistration() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final uid = user.uid;

    try {
      final snap = await _userDoc(uid).get();
      final hasProfile = snap.exists && (snap.data()?['fullName'] as String?)?.trim().isNotEmpty == true;

      if (!hasProfile) {
        await _userDoc(uid).delete();
        // Client SDK can only delete the *currently signed-in* user's own
        // account, which is exactly the case here (they never left this
        // session), so this is safe -- unlike deleteUserAccountData above,
        // which can't touch Auth for an arbitrary other uid.
        await user.delete();
      }
    } catch (e) {
      // Best-effort cleanup -- e.g. delete() can throw requires-recent-login
      // in rare cases. Don't let that surface as an error to someone who's
      // just trying to close a sheet; fall through to sign them out so they
      // aren't left in a half-registered session either way.
      // ignore: avoid_print
      print('[AuthService] Could not fully delete incomplete registration: $e');
    } finally {
      await signOut();
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}