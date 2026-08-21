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
  Future saveUserProfile({
    required String fullName,
    required String phoneNumber,
    required String area,
    String? category,
    String? ghanaCardNumber,
    String? ghanaCardPhotoUrl,
    String? photoUrl,
  }) async {
    final user = currentUser;
    if (user == null) throw Exception('No signed-in user');

    final uid = user.uid;

    if (category != null && category
        .trim()
        .isNotEmpty) {
      await assertProviderCategoryAllowed(category);
    }

    // Check whether this is a new profile
    final doc = await _userDoc(uid).get();
    final isNewUser = !doc.exists;

    await _userDoc(uid).set({
      // Firebase Authentication details
      'uid': uid,
      'email': user.email ?? '',

      // User profile
      'fullName': fullName,
      'phoneNumber': phoneNumber,
      'area': area,

      if (category != null) 'providerCategory': category,

      if (ghanaCardNumber != null) 'ghanaCardNumber': ghanaCardNumber,
      if (ghanaCardPhotoUrl != null)
        'ghanaCardPhotoUrl': ghanaCardPhotoUrl,

      if (photoUrl != null) 'photoUrl': photoUrl,

      if (ghanaCardNumber != null)
        'verificationStatus': 'pending',

      // Only set these the first time
      if (isNewUser) 'providerRegistered': false,
      if (isNewUser) 'providerType': '',
      if (isNewUser) 'providerDocId': '',
      if (isNewUser) 'createdAt': FieldValue.serverTimestamp(),

      // Always update
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // ===========================
    // Notify Admin ONLY for new users
    // ===========================
    if (isNewUser) {
      try {
        await NotificationService.notifyAdmin(
          title: 'New User Registration',
          body: '$fullName has completed profile registration.',
          category: 'new_user',
        );
      } catch (e) {
        print('Failed to notify admin: $e');
      }
    }
  }

  /// Uploads a Ghana Card photo to the PHP host and returns its public URL.
  Future uploadGhanaCardPhoto(String uid, File file) {
    return PhotoUploadService.uploadGhanaCardPhoto(
      uid: uid,
      photo: file,
    );
  }

  // =======================================================================
  // Provider account / onboarding guard
  // =======================================================================

  /// Returns the category already reserved by this user, if any.
  ///
  /// A user may register as a provider for ONE category only. This check is
  /// intentionally kept in AuthService so every provider registration path
  /// (BioDataScreen, dashboard, future screens, etc.) uses the same rule.
  Future<String?> getRegisteredProviderCategory() async {
    final uid = currentUser?.uid;
    if (uid == null) return null;

    final snap = await _userDoc(uid).get();
    final data = snap.data();
    if (data == null) return null;

    final category = data['providerCategory']?.toString().trim();
    if (category != null && category.isNotEmpty) return category;

    final categoryName = data['providerCategoryName']?.toString().trim();
    if (categoryName != null && categoryName.isNotEmpty) return categoryName;

    final providerType = data['providerType']?.toString().trim();
    if (providerType != null && providerType.isNotEmpty) return providerType;

    return null;
  }

  /// Checks whether [category] is compatible with the user's existing
  /// provider registration.
  Future<bool> canRegisterProviderCategory(String category) async {
    final requested = category.trim();
    if (requested.isEmpty) return false;

    final existing = await getRegisteredProviderCategory();
    if (existing == null || existing.isEmpty) return true;

    return _sameProviderCategory(existing, requested);
  }

  bool _sameProviderCategory(String a, String b) {
    String normalize(String value) {
      return value
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
          .trim();
    }

    final left = normalize(a);
    final right = normalize(b);

    if (left == right) return true;

    // Existing verified-provider records use short providerType values.
    const aliases = <String, String>{
      'okada': 'okada',
      'okada rider': 'okada',
      'aboboyaa': 'aboboyaa',
      'aboboyaa rider': 'aboboyaa',
      'mechanic': 'mechanic',
      'motor mechanic': 'motor mechanic',
      'steel bender': 'steel bender',
      'carpenter': 'carpenter',
      'tailor': 'tailor',
      'plumber': 'plumber',
      'electrician': 'electrician',
      'mason': 'mason',
      'tiler': 'tiler',
      'welder': 'welder',
      'teacher': 'teacher',
      'home food': 'home food',
      'home cook': 'home food',
      'hotel': 'hotel',
      'room for rent': 'room for rent',
      'ride along': 'ride along',
      'ride along driver': 'ride along',
    };

    return (aliases[left] ?? left) == (aliases[right] ?? right);
  }

  /// Throws if the current user is already registered for another provider
  /// category. Calling code should not swallow this exception: it is the
  /// business rule that prevents accidental second-category registration.
  Future<void> assertProviderCategoryAllowed(String category) async {
    final uid = currentUser?.uid;
    if (uid == null) throw Exception('No signed-in user');

    final requested = category.trim();
    if (requested.isEmpty) {
      throw Exception('Provider category is required');
    }

    final snap = await _userDoc(uid).get();
    final data = snap.data() ?? <String, dynamic>{};

    String? existing;

    final candidates = <dynamic>[
      data['providerCategory'],
      data['providerCategoryName'],
      data['providerType'],
    ];

    for (final candidate in candidates) {
      final value = candidate?.toString().trim();
      if (value != null && value.isNotEmpty) {
        existing = value;
        break;
      }
    }

    if (existing != null && !_sameProviderCategory(existing!, requested)) {
      throw StateError(
        'This account is already registered as a service provider '
            'under "$existing". A user can register as a service provider '
            'for only one category.',
      );
    }
  }

  /// Creates/updates the dashboard-level provider application.
  ///
  /// This DOES NOT create a category-specific provider record. The existing
  /// category-specific registration methods remain responsible for collecting
  /// the detailed information required by each category and creating the
  /// actual provider record. This keeps the dashboard generic while
  /// preserving the existing provider data models.
  Future<void> submitProviderApplication({
    required String category,
    String? displayName,
    String? bio,
    String? location,
  }) async {
    final uid = currentUser?.uid;
    if (uid == null) throw Exception('No signed-in user');

    await assertProviderCategoryAllowed(category);

    final userSnap = await _userDoc(uid).get();
    final userData = userSnap.data() ?? <String, dynamic>{};

    final existingStatus = userData['providerStatus']?.toString();
    if (existingStatus == 'approved' || existingStatus == 'suspended') {
      throw StateError(
        'This account already has a provider registration with status '
            '"$existingStatus".',
      );
    }

    final categoryName = category.trim();

    await _db.collection('provider_applications').doc(uid).set({
      'uid': uid,
      'email': currentUser?.email ?? '',
      'category': categoryName,
      'categoryId': categoryName,
      'displayName': displayName ?? userData['displayName'] ?? userData['fullName'] ?? '',
      'bio': bio ?? userData['bio'] ?? '',
      'location': location ?? userData['location'] ?? userData['area'] ?? '',
      'status': 'pending',
      'submittedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _userDoc(uid).set({
      'accountType': 'provider',
      'providerCategory': categoryName,
      'providerCategoryName': categoryName,
      'providerStatus': 'pending',
      'providerApplicationId': uid,
      'providerAvailable': false,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Marks the dashboard application as having completed the detailed
  /// category-specific registration. This is called by the category
  /// registration plumbing below after a provider record is created.
  Future<void> _markProviderApplicationRegistered({
    required String category,
    required String providerCollection,
    required String providerDocId,
  }) async {
    final uid = currentUser?.uid;
    if (uid == null) return;

    await assertProviderCategoryAllowed(category);

    await _db.collection('provider_applications').doc(uid).set({
      'category': category,
      'categoryId': category,
      'providerCollection': providerCollection,
      'providerDocId': providerDocId,
      'status': 'pending',
      'profileSubmitted': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _userDoc(uid).set({
      'accountType': 'provider',
      'providerCategory': category,
      'providerCategoryName': category,
      'providerStatus': 'pending',
      'providerRegistered': true,
      'providerType': category,
      'providerDocId': providerDocId,
      'providerAvailable': false,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Called by admin approval code when a category-specific provider has
  /// been approved. It keeps the dashboard's provider status synchronized
  /// with the existing provider collection.
  Future<void> syncProviderApprovalToUser({
    required String uid,
    required String category,
    required bool approved,
    bool suspended = false,
  }) async {
    final status = suspended
        ? 'suspended'
        : approved
        ? 'approved'
        : 'pending';

    await _userDoc(uid).set({
      'accountType': 'provider',
      'providerCategory': category,
      'providerCategoryName': category,
      'providerStatus': status,
      'providerAvailable': approved && !suspended,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _db.collection('provider_applications').doc(uid).set({
      'category': category,
      'status': status,
      'reviewedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ============================================================
  // GENERIC PROVIDER REVIEWS
  // ============================================================

  /// Submit a review for any provider category.
  ///
  /// Examples:
  ///   collection: 'mechanics'
  ///   collection: 'teachers'
  ///   collection: 'hotels'
  ///   collection: 'home_cooks'
  ///   collection: 'aboboyaa_riders'
  Future<void> submitProviderReview({
    required String collection,
    required String providerId,
    required String reviewerName,
    required double rating,
    String comment = '',
  }) async {
    final cleanCollection = collection.trim();
    final cleanProviderId = providerId.trim();
    final cleanReviewerName = reviewerName.trim();
    final cleanComment = comment.trim();

    if (cleanCollection.isEmpty) {
      throw Exception('Provider collection is missing.');
    }

    if (cleanProviderId.isEmpty) {
      throw Exception('Provider ID is missing.');
    }

    if (cleanReviewerName.isEmpty) {
      throw Exception('Please enter your name.');
    }

    if (rating < 1 || rating > 5) {
      throw Exception('Rating must be between 1 and 5 stars.');
    }

    if (cleanComment.length > 500) {
      throw Exception(
        'Review comment cannot be longer than 500 characters.',
      );
    }

    await _submitReview(
      cleanCollection,
      cleanProviderId,
      cleanReviewerName,
      rating,
      cleanComment,
    );
  }

  /// Live review stream for any provider category.
  Stream<QuerySnapshot<Map<String, dynamic>>> providerReviewsStream(
      String collection,
      String providerId,
      ) {
    final cleanCollection = collection.trim();
    final cleanProviderId = providerId.trim();

    if (cleanCollection.isEmpty || cleanProviderId.isEmpty) {
      return const Stream.empty();
    }

    return _reviewsStream(
      cleanCollection,
      cleanProviderId,
    );
  }

  // Additional category-specific compatibility methods.

  Stream<QuerySnapshot<Map<String, dynamic>>>
  aboboyaaRiderReviewsStream(String id) =>
      _reviewsStream('aboboyaa_riders', id);

  Future<void> submitAboboyaaRiderReview({
    required String riderId,
    required String reviewerName,
    required double rating,
    String comment = '',
  }) =>
      _submitReview(
        'aboboyaa_riders',
        riderId,
        reviewerName,
        rating,
        comment,
      );

  Stream<QuerySnapshot<Map<String, dynamic>>> hotelReviewsStream(String id) =>
      _reviewsStream('hotels', id);

  Future<void> submitHotelReview({
    required String hotelId,
    required String reviewerName,
    required double rating,
    String comment = '',
  }) =>
      _submitReview(
        'hotels',
        hotelId,
        reviewerName,
        rating,
        comment,
      );

  Stream<QuerySnapshot<Map<String, dynamic>>> homeCookReviewsStream(
      String id,
      ) =>
      _reviewsStream('home_cooks', id);

  Future<void> submitHomeCookReview({
    required String homeCookId,
    required String reviewerName,
    required double rating,
    String comment = '',
  }) =>
      _submitReview(
        'home_cooks',
        homeCookId,
        reviewerName,
        rating,
        comment,
      );

  Stream<QuerySnapshot<Map<String, dynamic>>> roomForRentReviewsStream(
      String id,
      ) =>
      _reviewsStream('rooms_for_rent', id);

  Future<void> submitRoomForRentReview({
    required String roomId,
    required String reviewerName,
    required double rating,
    String comment = '',
  }) =>
      _submitReview(
        'rooms_for_rent',
        roomId,
        reviewerName,
        rating,
        comment,
      );

  Stream<QuerySnapshot<Map<String, dynamic>>> tilerReviewsStream(String id) =>
      _reviewsStream('tilers', id);

  Future<void> submitTilerReview({
    required String tilerId,
    required String reviewerName,
    required double rating,
    String comment = '',
  }) =>
      _submitReview(
        'tilers',
        tilerId,
        reviewerName,
        rating,
        comment,
      );

  Stream<QuerySnapshot<Map<String, dynamic>>> masonReviewsStream(String id) =>
      _reviewsStream('masons', id);

  Future<void> submitMasonReview({
    required String masonId,
    required String reviewerName,
    required double rating,
    String comment = '',
  }) =>
      _submitReview(
        'masons',
        masonId,
        reviewerName,
        rating,
        comment,
      );

  Stream<QuerySnapshot<Map<String, dynamic>>> steelBenderReviewsStream(
      String id,
      ) =>
      _reviewsStream('steel_benders', id);

  Future<void> submitSteelBenderReview({
    required String steelBenderId,
    required String reviewerName,
    required double rating,
    String comment = '',
  }) =>
      _submitReview(
        'steel_benders',
        steelBenderId,
        reviewerName,
        rating,
        comment,
      );

  Stream<QuerySnapshot<Map<String, dynamic>>> eventPlannerReviewsStream(
      String id,
      ) =>
      _reviewsStream('event_planners', id);

  Future<void> submitEventPlannerReview({
    required String eventPlannerId,
    required String reviewerName,
    required double rating,
    String comment = '',
  }) =>
      _submitReview(
        'event_planners',
        eventPlannerId,
        reviewerName,
        rating,
        comment,
      );

  // =======================================================================
  // Shared provider-registration plumbing
  // =======================================================================
  //
  // Every provider category in this file falls into one of two shapes:
  //
  //  1. "Approval" scheme (mechanics, carpenters, tailors, plumbers, tilers,
  //     welders, electricians, teachers, steel benders, home cooks, hotels,
  //     rooms for rent, ride-along). Status lives in isApproved/isPending
  //     booleans, no admin notification is sent, and the doc is either
  //     keyed by uid (self-registration) or an auto-generated id (admin-add,
  //     or listing-style categories where one person can have many docs).
  //
  //  2. "Verified" scheme (okada riders, aboboyaa riders). Status lives in
  //     a single verificationStatus string, the linked users/{uid} doc gets
  //     providerRegistered/providerType/providerDocId, and an admin
  //     notification is sent.
  //
  // _writeApprovalProviderDoc and _registerVerifiedProvider capture those
  // two shapes once each; every registerAsX / addXByAdmin method below is
  // now just "gather this category's fields, hand them to the right
  // helper."

  /// Writes a provider doc for the "approval" scheme described above.
  /// Pass [docRef] when the caller already created the doc reference
  /// (e.g. because it needed the id for photo-upload paths before writing);
  /// otherwise a fresh auto-id doc is created in [collection].
  ///
  /// [includeRatingFields] is false for rooms_for_rent, which tracks
  /// isAvailable instead of a rating/reviewCount pair.
  Future<void> _maybeSyncSelfRegisteredProvider({
    required String collection,
    required String providerDocId,
    required Map<String, dynamic> fields,
  }) async {
    final uid = currentUser?.uid;
    if (uid == null) return;

    final linkedUidCandidates = <String?>[
      fields['uid']?.toString(),
      fields['driverUid']?.toString(),
      fields['ownerUid']?.toString(),
      fields['landlordUid']?.toString(),
      fields['userUid']?.toString(),
    ];

    // Self-registered uid-keyed records are also recognized by their doc id.
    final looksLikeSelfRegistration =
        linkedUidCandidates.any((value) => value == uid) ||
            providerDocId == uid;

    if (!looksLikeSelfRegistration) return;

    final category = _categoryForProviderCollection(collection);
    if (category == null) return;

    await _markProviderApplicationRegistered(
      category: category,
      providerCollection: collection,
      providerDocId: providerDocId,
    );
  }

  String? _categoryForProviderCollection(String collection) {
    const categories = <String, String>{
      'okada_riders': 'Okada',
      'aboboyaa_riders': 'Aboboyaa',
      'mechanics': 'Mechanic',
      'motor_mechanics': 'Motor Mechanic',
      'steel_benders': 'Steel Bender',
      'carpenters': 'Carpenter',
      'tailors': 'Tailor',
      'plumbers': 'Plumber',
      'electricians': 'Electrician',
      'masons': 'Mason',
      'tilers': 'Tiler',
      'welders': 'Welder',
      'teachers': 'Teacher',
      'home_cooks': 'Home Food',
      'hotels': 'Hotel',
      'rooms_for_rent': 'Room for Rent',
      'ride_along': 'Ride Along',
      'event_planners': 'Event Planner',
    };

    return categories[collection];
  }

  Future<String> _writeApprovalProviderDoc({
    required String collection,
    required Map<String, dynamic> fields,
    bool autoApprove = false,
    bool includeRatingFields = true,
    DocumentReference<Map<String, dynamic>>? docRef,
  }) async {
    final ref = docRef ?? _db.collection(collection).doc();
    await ref.set({
      ...fields,
      if (includeRatingFields) 'rating': 0.0,
      if (includeRatingFields) 'reviewCount': 0,
      'isApproved': autoApprove,
      'isPending': !autoApprove,
      // Standardized on FieldValue.serverTimestamp() for every category.
      // Several categories previously used DateTime.now().toIso8601String()
      // here instead, which sorts as a string rather than a real Firestore
      // Timestamp -- any orderBy('createdAt') query against those
      // collections (e.g. TailorsScreen/TilersScreen) would silently order
      // incorrectly, or fail to interleave properly with server-timestamped
      // docs.
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _maybeSyncSelfRegisteredProvider(
      collection: collection,
      providerDocId: ref.id,
      fields: fields,
    );

    return ref.id;
  }

  /// Registers a provider for the "verified" scheme described above:
  /// verificationStatus (not isApproved/isPending), a providerRegistered
  /// flag on the linked users/{uid} doc, and an admin notification.
  /// [userDocExtra] lets a specific category add its own flag alongside
  /// the standard providerRegistered/providerType/providerDocId fields --
  /// e.g. Okada riders also set isRider: true, since isOkadaRider() reads
  /// that flag directly.
  Future<void> _registerVerifiedProvider({
    required String collection,
    required String uid,
    required Map<String, dynamic> fields,
    required String providerType,
    required String notifyTitle,
    required String notifyBody,
    Map<String, dynamic> userDocExtra = const {},
  }) async {
    await _db.collection(collection).doc(uid).set({
      'uid': uid,
      'email': currentUser?.email ?? '',
      ...fields,
      'verificationStatus': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _userDoc(uid).set({
      'providerRegistered': true,
      'providerType': providerType,
      'providerDocId': uid,
      ...userDocExtra,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final category = _categoryForProviderCollection(collection);
    if (category != null) {
      await _markProviderApplicationRegistered(
        category: category,
        providerCollection: collection,
        providerDocId: uid,
      );
    }

    try {
      await NotificationService.notifyAdmin(
        title: notifyTitle,
        body: notifyBody,
        category: providerType,
        itemId: uid,
      );
    } catch (e) {
      print('Failed to notify admin: $e');
    }
  }

  /// Uploads each photo in [photos] under its own indexed path so multiple
  /// photos for the same listing don't overwrite one another. [uidPrefix]
  /// is just a folder/filename prefix (a real uid for self-registration, or
  /// a placeholder like 'admin_{docId}' for admin-added listings) -- not
  /// necessarily a Firestore document key. Order is preserved, so the first
  /// URL can double as a cover photo where a category needs one.
  Future<List<String>> _uploadPhotos(String uidPrefix, List<File> photos) async {
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
  /// approves them. This now also sends an admin notification (previously
  /// missing here, unlike registerAsAboboyaa) so Okada sign-ups don't go
  /// unnoticed the way Aboboyaa ones didn't.
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

    await assertProviderCategoryAllowed('Okada');

    String? photoUrl;
    if (riderPhoto != null) {
      photoUrl = await PhotoUploadService.uploadRiderPhoto(uid: uid, photo: riderPhoto);
    }

    await _registerVerifiedProvider(
      collection: 'okada_riders',
      uid: uid,
      fields: {
        'riderName': fullName,
        'phoneNumber': phoneNumber,
        'numberPlate': plateNumber,
        'stationName': station,
        'ghanaCardNumber': ghanaCardNumber,
        if (ghanaCardPhotoUrl != null) 'ghanaCardPhotoUrl': ghanaCardPhotoUrl,
        if (photoUrl != null) 'riderPhotoUrl': photoUrl,
        'isOnline': false,
      },
      providerType: 'okada',
      notifyTitle: 'New Okada Rider Registration',
      notifyBody: '$fullName has registered as an Okada rider.',
      // isOkadaRider() reads isRider directly off the user doc, so keep
      // setting it explicitly alongside the standard providerRegistered
      // fields.
      userDocExtra: {'isRider': true},
    );
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

  // ---------------------------------------------------------------------
// Aboboyaa helpers
// ---------------------------------------------------------------------

  DocumentReference<Map<String, dynamic>> _aboboyaaDoc(String uid) =>
      _db.collection('aboboyaa_riders').doc(uid);

  /// Returns true if the currently signed-in user is registered as
  /// an Aboboyaa rider.
  Future<bool> isAboboyaaRider() async {
    final uid = currentUser?.uid;
    if (uid == null) return false;

    final snap = await _userDoc(uid).get();
    return snap.data()?['isAboboyaa'] == true;
  }

  /// Returns true if the currently signed-in user already has an
  /// Aboboyaa rider document.
  Future<bool> isRegisteredAboboyaaRider() async {
    final uid = currentUser?.uid;
    if (uid == null) return false;

    final snap = await _aboboyaaDoc(uid).get();
    return snap.exists;
  }

  /// Fetches the current user's Aboboyaa document.
  Future<Map<String, dynamic>?> getAboboyaaDoc() async {
    final uid = currentUser?.uid;
    if (uid == null) return null;

    final snap = await _aboboyaaDoc(uid).get();
    return snap.data();
  }

  /// Changes the Aboboyaa rider's available/unavailable status.
  ///
  /// NOTE: this writes `isAvailable`, not `isOnline`. AboboyaaRider.fromMap
  /// and the "Available"/"Unavailable" badge in aboboyaa_screen.dart both
  /// read `isAvailable` — a previous version of this method wrote
  /// `isOnline` instead, which that badge never reads, so a rider could
  /// toggle status here and still show as permanently "Unavailable".
  Future<void> setAboboyaaAvailability(bool isAvailable) async {
    final uid = currentUser?.uid;
    if (uid == null) {
      throw Exception('No signed-in user');
    }

    await _aboboyaaDoc(uid).set({
      'isAvailable': isAvailable,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Admin-only: approves an Aboboyaa rider.
  ///
  /// Keep both the dedicated verificationStatus field and the legacy
  /// boolean fields in sync. Also update the linked user/application so
  /// the rider follows the same provider lifecycle as every other category.
  Future<void> approveAboboyaaRider(String riderId) async {
    final ref = _aboboyaaDoc(riderId);

    await ref.set({
      'verificationStatus': 'approved',
      'isApproved': true,
      'isPending': false,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await syncProviderApprovalToUser(
      uid: riderId,
      category: 'Aboboyaa',
      approved: true,
    );
  }

// ---------------------------------------------------------------------
// Aboboyaa registration
// ---------------------------------------------------------------------

  /// Self-registration for an Aboboyaa rider.
  ///
  /// New registrations start as pending and must be approved by an admin
  /// before appearing publicly.
  Future<void> registerAsAboboyaa({
    required String fullName,
    required String phoneNumber,
    required String numberPlate,
    required String station,
    required String ghanaCardNumber,
    String? ghanaCardPhotoUrl,
    File? riderPhoto,
  }) async {
    final uid = currentUser?.uid;

    if (uid == null) {
      throw Exception('No signed-in user');
    }

    await assertProviderCategoryAllowed('Aboboyaa');

    String? photoUrl;

    if (riderPhoto != null) {
      photoUrl = await PhotoUploadService.uploadRiderPhoto(
        uid: uid,
        photo: riderPhoto,
      );
    }

    // Use the same verified-provider registration pipeline as Okada.
    // This creates the provider application link, stores the provider
    // collection/doc id, updates the user's provider state and notifies admin.
    await _registerVerifiedProvider(
      collection: 'aboboyaa_riders',
      uid: uid,
      fields: {
        'riderName': fullName,
        'phoneNumber': phoneNumber,
        'numberPlate': numberPlate,
        'stationName': station,
        'ghanaCardNumber': ghanaCardNumber,
        if (ghanaCardPhotoUrl != null)
          'ghanaCardPhotoUrl': ghanaCardPhotoUrl,
        if (photoUrl != null)
          'riderPhotoUrl': photoUrl,
        // isAvailable (not isOnline) — see setAboboyaaAvailability for why.
        'isAvailable': false,
      },
      providerType: 'aboboyaa',
      notifyTitle: 'New Aboboyaa Registration',
      notifyBody:
          '$fullName has registered as an Aboboyaa rider and is waiting for approval.',
      userDocExtra: {
        'isAboboyaa': true,
      },
    );
  }

  // ---------------------------------------------------------------------
  // Mechanic registration
  // ---------------------------------------------------------------------

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

    await assertProviderCategoryAllowed('Mechanic');

    String? photoUrl;
    if (mechanicPhoto != null) {
      photoUrl = await PhotoUploadService.uploadRiderPhoto(uid: uid, photo: mechanicPhoto);
    }

    await _writeApprovalProviderDoc(
      collection: 'mechanics',
      docRef: _db.collection('mechanics').doc(uid),
      fields: {
        'name': fullName,
        'phoneNumber': phoneNumber,
        'workshopName': workshopName,
        'stationArea': stationArea,
        'yearsOfExperience': yearsOfExperience,
        'vehicleTypes': vehicleTypes,
        'brandSpecialties': brandSpecialties,
        'servicesOffered': servicesOffered,
        'offersRoadsideService': offersRoadsideService,
        'ghanaCardNumber': ghanaCardNumber,
        'photoUrl': photoUrl,
        'ghanaCardPhotoUrl': ghanaCardPhotoUrl,
      },
    );
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

  // ---------------------------------------------------------------------
  // Steel bender registration
  // ---------------------------------------------------------------------

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

    await assertProviderCategoryAllowed('Steel Bender');

    String? photoUrl;
    if (steelBenderPhoto != null) {
      photoUrl = await PhotoUploadService.uploadRiderPhoto(uid: uid, photo: steelBenderPhoto);
    }

    await _writeApprovalProviderDoc(
      collection: 'steel_benders',
      docRef: _db.collection('steel_benders').doc(uid),
      fields: {
        'fullName': fullName,
        'phoneNumber': phoneNumber,
        'workshopName': workshopName,
        'stationArea': stationArea,
        'yearsOfExperience': yearsOfExperience,
        'specialties': specialties,
        'rebarSizesHandled': rebarSizesHandled,
        'offersOnSiteService': offersOnSiteService,
        'ghanaCardNumber': ghanaCardNumber,
        'photoUrl': photoUrl,
        'ghanaCardPhotoUrl': ghanaCardPhotoUrl,
      },
    );
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

    await assertProviderCategoryAllowed('Carpenter');

    String? photoUrl;
    if (carpenterPhoto != null) {
      photoUrl = await PhotoUploadService.uploadRiderPhoto(uid: uid, photo: carpenterPhoto);
    }

    await _writeApprovalProviderDoc(
      collection: 'carpenters',
      docRef: _db.collection('carpenters').doc(uid),
      fields: {
        'fullName': fullName,
        'phoneNumber': phoneNumber,
        'workshopName': workshopName,
        'stationArea': stationArea,
        'yearsOfExperience': yearsOfExperience,
        'specialties': specialties,
        'materialsWorkedWith': materialsWorkedWith,
        'servicesOffered': servicesOffered,
        'offersOnSiteService': offersOnSiteService,
        'ghanaCardNumber': ghanaCardNumber,
        'photoUrl': photoUrl,
        'ghanaCardPhotoUrl': ghanaCardPhotoUrl,
      },
    );
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
  }) {
    return _writeApprovalProviderDoc(
      collection: 'carpenters',
      fields: {
        'fullName': fullName,
        'phoneNumber': phoneNumber,
        'workshopName': workshopName,
        'stationArea': stationArea,
        'yearsOfExperience': yearsOfExperience,
        'specialties': specialties,
        'materialsWorkedWith': materialsWorkedWith,
        'servicesOffered': servicesOffered,
        'offersOnSiteService': offersOnSiteService,
        'ghanaCardNumber': ghanaCardNumber ?? '',
        'photoUrl': photoUrl,
        'ghanaCardPhotoUrl': ghanaCardPhotoUrl,
      },
    );
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
  /// descending, so this must always set that field as a real Firestore
  /// Timestamp -- which _writeApprovalProviderDoc now guarantees for every
  /// category, not just this one.
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

    await assertProviderCategoryAllowed('Tailor');

    String? photoUrl;
    if (tailorPhoto != null) {
      photoUrl = await PhotoUploadService.uploadRiderPhoto(uid: uid, photo: tailorPhoto);
    }

    await _writeApprovalProviderDoc(
      collection: 'tailors',
      docRef: _db.collection('tailors').doc(uid),
      fields: {
        'name': fullName,
        'phoneNumber': phoneNumber,
        'businessName': businessName,
        'stationArea': stationArea,
        'yearsOfExperience': yearsOfExperience,
        'garmentTypesServiced': garmentTypesServiced,
        'fabricSpecialties': fabricSpecialties,
        'servicesOffered': servicesOffered,
        'offersRushService': offersRushService,
        'ghanaCardNumber': ghanaCardNumber,
        'photoUrl': photoUrl,
        'ghanaCardPhotoUrl': ghanaCardPhotoUrl,
      },
    );
  }

  /// Admin-only: makes a self-registered tailor visible in the public
  /// TailorsScreen list. Mirrors approveMechanic / approveCarpenter.
  Future<void> approveTailor(String id) async {
    await _db.collection('tailors').doc(id).update({
      'isApproved': true,
      'isPending': false,
    });
  }

  // ---------------------------------------------------------------------
  // Plumber registration
  // ---------------------------------------------------------------------

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

    await assertProviderCategoryAllowed('Plumber');

    String? photoUrl;
    if (plumberPhoto != null) {
      photoUrl = await PhotoUploadService.uploadRiderPhoto(uid: uid, photo: plumberPhoto);
    }

    await _writeApprovalProviderDoc(
      collection: 'plumbers',
      docRef: _db.collection('plumbers').doc(uid),
      fields: {
        'name': fullName,
        'phoneNumber': phoneNumber,
        'businessName': businessName,
        'stationArea': stationArea,
        'yearsOfExperience': yearsOfExperience,
        'propertyTypesServiced': propertyTypesServiced,
        'fixtureBrands': fixtureBrands,
        'servicesOffered': servicesOffered,
        'offersEmergencyService': offersEmergencyService,
        'ghanaCardNumber': ghanaCardNumber,
        'photoUrl': photoUrl,
        'ghanaCardPhotoUrl': ghanaCardPhotoUrl,
      },
    );
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

    await assertProviderCategoryAllowed('Tiler');

    String? photoUrl;
    if (tilerPhoto != null) {
      photoUrl = await PhotoUploadService.uploadRiderPhoto(uid: uid, photo: tilerPhoto);
    }

    await _writeApprovalProviderDoc(
      collection: 'tilers',
      docRef: _db.collection('tilers').doc(uid),
      fields: {
        'name': fullName,
        'phoneNumber': phoneNumber,
        'businessName': businessName,
        'stationArea': stationArea,
        'yearsOfExperience': yearsOfExperience,
        'specialtiesServiced': specialtiesServiced,
        'materialsWorkedWith': materialsWorkedWith,
        'servicesOffered': servicesOffered,
        'offersOnSiteConsultation': offersOnSiteConsultation,
        'ghanaCardNumber': ghanaCardNumber,
        'photoUrl': photoUrl,
        'ghanaCardPhotoUrl': ghanaCardPhotoUrl,
      },
    );
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
  }) {
    return _writeApprovalProviderDoc(
      collection: 'tilers',
      autoApprove: true,
      fields: {
        'name': fullName,
        'phoneNumber': phoneNumber,
        'businessName': businessName,
        'stationArea': stationArea,
        'yearsOfExperience': yearsOfExperience,
        'specialtiesServiced': specialtiesServiced,
        'materialsWorkedWith': materialsWorkedWith,
        'servicesOffered': servicesOffered,
        'offersOnSiteConsultation': offersOnSiteConsultation,
        'ghanaCardNumber': ghanaCardNumber ?? '',
        'photoUrl': photoUrl,
        'ghanaCardPhotoUrl': ghanaCardPhotoUrl,
      },
    );
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

    await assertProviderCategoryAllowed('Welder');

    String? photoUrl;
    if (welderPhoto != null) {
      photoUrl = await PhotoUploadService.uploadRiderPhoto(uid: uid, photo: welderPhoto);
    }

    await _writeApprovalProviderDoc(
      collection: 'welders',
      docRef: _db.collection('welders').doc(uid),
      fields: {
        'name': fullName,
        'phoneNumber': phoneNumber,
        'businessName': businessName,
        'stationArea': stationArea,
        'yearsOfExperience': yearsOfExperience,
        'specialtiesServiced': specialtiesServiced,
        'materialsWorkedWith': materialsWorkedWith,
        'servicesOffered': servicesOffered,
        'offersOnSiteService': offersOnSiteService,
        'ghanaCardNumber': ghanaCardNumber,
        'photoUrl': photoUrl,
        'ghanaCardPhotoUrl': ghanaCardPhotoUrl,
      },
    );
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
  }) {
    return _writeApprovalProviderDoc(
      collection: 'welders',
      autoApprove: true,
      fields: {
        'name': fullName,
        'phoneNumber': phoneNumber,
        'businessName': businessName,
        'stationArea': stationArea,
        'yearsOfExperience': yearsOfExperience,
        'specialtiesServiced': specialtiesServiced,
        'materialsWorkedWith': materialsWorkedWith,
        'servicesOffered': servicesOffered,
        'offersOnSiteService': offersOnSiteService,
        'ghanaCardNumber': ghanaCardNumber ?? '',
        'photoUrl': photoUrl,
        'ghanaCardPhotoUrl': ghanaCardPhotoUrl,
      },
    );
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

    await assertProviderCategoryAllowed('Electrician');

    String? photoUrl;
    if (electricianPhoto != null) {
      photoUrl = await PhotoUploadService.uploadRiderPhoto(uid: uid, photo: electricianPhoto);
    }

    await _writeApprovalProviderDoc(
      collection: 'electricians',
      docRef: _db.collection('electricians').doc(uid),
      fields: {
        'name': fullName,
        'phoneNumber': phoneNumber,
        'businessName': businessName,
        'stationArea': stationArea,
        'yearsOfExperience': yearsOfExperience,
        'propertyTypesServiced': propertyTypesServiced,
        'servicesOffered': servicesOffered,
        'offersEmergencyService': offersEmergencyService,
        'ghanaCardNumber': ghanaCardNumber,
        'photoUrl': photoUrl,
        'ghanaCardPhotoUrl': ghanaCardPhotoUrl,
      },
    );

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
  }) {
    return _writeApprovalProviderDoc(
      collection: 'electricians',
      fields: {
        'name': fullName,
        'phoneNumber': phoneNumber,
        'businessName': businessName,
        'stationArea': stationArea,
        'yearsOfExperience': yearsOfExperience,
        'propertyTypesServiced': propertyTypesServiced,
        'servicesOffered': servicesOffered,
        'offersEmergencyService': offersEmergencyService,
        'ghanaCardNumber': ghanaCardNumber ?? '',
        'photoUrl': photoUrl,
        'ghanaCardPhotoUrl': ghanaCardPhotoUrl,
      },
    );
  }

  /// Admin-only: makes an electrician visible in the public
  /// ElectriciansScreen list. Mirrors approveMechanic / approvePlumber.
  Future<void> approveElectrician(String id) async {
    await _db.collection('electricians').doc(id).update({
      'isApproved': true,
      'isPending': false,
    });
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

    await assertProviderCategoryAllowed('Teacher');

    String? photoUrl;
    if (teacherPhoto != null) {
      photoUrl = await PhotoUploadService.uploadRiderPhoto(uid: uid, photo: teacherPhoto);
    }

    await _writeApprovalProviderDoc(
      collection: 'teachers',
      docRef: _db.collection('teachers').doc(uid),
      fields: {
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
        'ghanaCardNumber': ghanaCardNumber,
        'photoUrl': photoUrl,
        'ghanaCardPhotoUrl': ghanaCardPhotoUrl,
      },
    );
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
  }) {
    return _writeApprovalProviderDoc(
      collection: 'teachers',
      fields: {
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
        'ghanaCardNumber': ghanaCardNumber ?? '',
        'photoUrl': photoUrl,
        'ghanaCardPhotoUrl': ghanaCardPhotoUrl,
      },
    );
  }

  /// Admin-only: makes a teacher visible in the public TeachersScreen list.
  Future<void> approveTeacher(String id) async {
    await _db.collection('teachers').doc(id).update({
      'isApproved': true,
      'isPending': false,
    });
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
    List<File> photos = const [],
  }) async {
    final uid = currentUser?.uid;
    if (uid == null) throw Exception('No signed-in user');

    await assertProviderCategoryAllowed('Home Food');

    final photoUrls = photos.isEmpty ? <String>[] : await _uploadPhotos(uid, photos);

    await _writeApprovalProviderDoc(
      collection: 'home_cooks',
      docRef: _db.collection('home_cooks').doc(uid),
      fields: {
        'name': fullName,
        'phoneNumber': phoneNumber,
        'businessName': businessName,
        'stationArea': stationArea,
        'cuisineTypes': cuisineTypes,
        'deliveryAreas': deliveryAreas,
        'offersDelivery': offersDelivery,
        'menu': menu.map((m) => m.toMap()).toList(),
        'ghanaCardNumber': ghanaCardNumber,
        'photoUrls': photoUrls,
        'ghanaCardPhotoUrl': ghanaCardPhotoUrl,
      },
    );
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
    List<File> photos = const [],
  }) async {
    final docRef = _db.collection('home_cooks').doc();
    final photoUrls =
    photos.isEmpty ? <String>[] : await _uploadPhotos('admin_${docRef.id}', photos);

    return _writeApprovalProviderDoc(
      collection: 'home_cooks',
      docRef: docRef,
      autoApprove: true,
      fields: {
        'name': fullName,
        'phoneNumber': phoneNumber,
        'businessName': businessName,
        'stationArea': stationArea,
        'cuisineTypes': cuisineTypes,
        'deliveryAreas': deliveryAreas,
        'offersDelivery': offersDelivery,
        'menu': menu.map((m) => m.toMap()).toList(),
        'ghanaCardNumber': ghanaCardNumber ?? '',
        'photoUrls': photoUrls,
        'ghanaCardPhotoUrl': ghanaCardPhotoUrl,
      },
    );
  }

  // ---------------------------------------------------------------------
  // Hotel registration
  // ---------------------------------------------------------------------

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

    await assertProviderCategoryAllowed('Hotel');

    final photoUrls = photos.isEmpty ? <String>[] : await _uploadPhotos(uid, photos);

    await _writeApprovalProviderDoc(
      collection: 'hotels',
      docRef: _db.collection('hotels').doc(uid),
      fields: {
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
        'ghanaCardNumber': ghanaCardNumber,
        if (ghanaCardPhotoUrl != null) 'ghanaCardPhotoUrl': ghanaCardPhotoUrl,
      },
    );
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

    final photoUrls = photos.isEmpty ? <String>[] : await _uploadPhotos(uploadKey, photos);

    String? ghanaCardPhotoUrl;
    if (ghanaCardImage != null) {
      ghanaCardPhotoUrl = await PhotoUploadService.uploadGhanaCardPhoto(uid: uploadKey, photo: ghanaCardImage);
    }

    return _writeApprovalProviderDoc(
      collection: 'hotels',
      docRef: docRef,
      fields: {
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
        'ghanaCardNumber': ghanaCardNumber ?? '',
        'ghanaCardPhotoUrl': ghanaCardPhotoUrl,
      },
    );
  }

  // ---------------------------------------------------------------------
  // Room for Rent
  // ---------------------------------------------------------------------

  /// Self-registration path -- called from BioDataScreen when
  /// role == provider and category == 'Room for Rent'. Unlike other
  /// provider categories this is NOT keyed by uid, since one landlord may
  /// list multiple rooms over time -- each call creates a new auto-ID doc,
  /// same reasoning as why Listing docs use auto-IDs rather than being
  /// keyed to their creator.
  Future<String> registerAsRoomForRent({
    required String landlordName,
    required String phoneNumber,
    required String propertyTitle,
    required String stationArea,
    required String roomType,
    required double price,
    required String rentPeriod,
    required List<String> amenities,
    required String description,
    required String ghanaCardNumber,
    String? ghanaCardPhotoUrl,
    List<File> photos = const [],
  }) async {
    final uid = currentUser?.uid;
    if (uid == null) throw Exception('No signed-in user');

    await assertProviderCategoryAllowed('Room for Rent');

    final docRef = _db.collection('rooms_for_rent').doc();
    final photoUrls = photos.isEmpty
        ? <String>[]
        : await _uploadPhotos('${uid}_${docRef.id}', photos);

    return _writeApprovalProviderDoc(
      collection: 'rooms_for_rent',
      docRef: docRef,
      includeRatingFields: false,
      fields: {
        'landlordName': landlordName,
        'phoneNumber': phoneNumber,
        'propertyTitle': propertyTitle,
        'stationArea': stationArea,
        'roomType': roomType,
        'price': price,
        'rentPeriod': rentPeriod,
        'amenities': amenities,
        'description': description,
        'photoUrls': photoUrls,
        'isAvailable': true,
        'ghanaCardNumber': ghanaCardNumber,
        if (ghanaCardPhotoUrl != null) 'ghanaCardPhotoUrl': ghanaCardPhotoUrl,
      },
    );
  }

  /// Admin-adds-directly path -- mirrors addHotelByAdmin exactly: no
  /// signed-in uid to key uploads by, so the new doc's own id is used as
  /// the upload-path prefix, and the Ghana Card photo is uploaded inline
  /// here (not pre-uploaded by the screen) same as addHotelByAdmin does
  /// with ghanaCardImage.
  Future<String> addRoomForRentByAdmin({
    required String landlordName,
    required String phoneNumber,
    required String propertyTitle,
    required String stationArea,
    required String roomType,
    required double price,
    required String rentPeriod,
    required List<String> amenities,
    required String description,
    List<File> photos = const [],
    String? ghanaCardNumber,
    File? ghanaCardImage,
  }) async {
    final docRef = _db.collection('rooms_for_rent').doc();
    final uploadKey = 'admin_${docRef.id}';

    final photoUrls = photos.isEmpty ? <String>[] : await _uploadPhotos(uploadKey, photos);

    String? ghanaCardPhotoUrl;
    if (ghanaCardImage != null) {
      ghanaCardPhotoUrl = await PhotoUploadService.uploadGhanaCardPhoto(uid: uploadKey, photo: ghanaCardImage);
    }

    return _writeApprovalProviderDoc(
      collection: 'rooms_for_rent',
      docRef: docRef,
      includeRatingFields: false,
      fields: {
        'landlordName': landlordName,
        'phoneNumber': phoneNumber,
        'propertyTitle': propertyTitle,
        'stationArea': stationArea,
        'roomType': roomType,
        'price': price,
        'rentPeriod': rentPeriod,
        'amenities': amenities,
        'description': description,
        'photoUrls': photoUrls,
        'isAvailable': true,
        'ghanaCardNumber': ghanaCardNumber ?? '',
        'ghanaCardPhotoUrl': ghanaCardPhotoUrl,
      },
    );
  }

  /// Admin-only: makes a room listing visible in the public
  /// RoomsForRentScreen list. Mirrors approveHotel / approveTiler.
  Future<void> approveRoomForRent(String id) async {
    await _db.collection('rooms_for_rent').doc(id).update({
      'isApproved': true,
      'isPending': false,
    });
  }

  /// Landlord/admin toggle -- marks a room as taken so it stops showing
  /// in the public list without deleting the record.
  Future<void> setRoomAvailability(String id, bool isAvailable) async {
    await _db.collection('rooms_for_rent').doc(id).update({
      'isAvailable': isAvailable,
    });
  }

  /// Live stream of approved, available rooms for the public
  /// RoomsForRentScreen. Mirrors rideAlongStream()'s shape, but rooms
  /// use isAvailable (not isActive) as their "still open" flag --
  /// see setRoomAvailability above.
  Stream<QuerySnapshot<Map<String, dynamic>>> roomsForRentStream() {
    return _db
        .collection('rooms_for_rent')
        .where('isApproved', isEqualTo: true)
        .where('isAvailable', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }


  // ---------------------------------------------------------------------
  // Dashboard provider registration - all categories
  // ---------------------------------------------------------------------

  /// Finalizes a provider application created from the Account screen.
  ///
  /// This is deliberately category-agnostic so every provider category has
  /// the same onboarding flow: select ONE category, complete the form, create
  /// the real provider record, mark the application pending, and notify admin.
  Future<void> registerProviderFromDashboard({
    required String category,
    required String fullName,
    required String phoneNumber,
    required String stationArea,
    required String ghanaCardNumber,
    String? ghanaCardPhotoUrl,
    String? photoUrl,
    String businessName = '',
    String description = '',
    int yearsOfExperience = 0,
    List<String> servicesOffered = const [],
    List<String> specialties = const [],
    Map<String, dynamic> extra = const {},
  }) async {
    final uid = currentUser?.uid;
    if (uid == null) throw Exception('No signed-in user');

    await assertProviderCategoryAllowed(category);

    final collection = providerCollections[category];
    if (collection == null || collection.trim().isEmpty) {
      throw Exception('Provider category "$category" is not configured.');
    }

    // One provider category per user, enforced before writing anything.
    final userSnap = await _userDoc(uid).get();
    final userData = userSnap.data() ?? {};
    final existing = (userData['providerCategory'] ??
        userData['providerCategoryName'] ??
        userData['providerType'] ??
        '')
        .toString()
        .trim();

    if (existing.isNotEmpty && !_sameProviderCategory(existing, category)) {
      throw Exception(
        'You are already registered as a provider under $existing. '
            'A user can register under only one category.',
      );
    }

    final providerRef = _db.collection(collection).doc(uid);

    final fields = <String, dynamic>{
      'uid': uid,
      'ownerUid': uid,
      'userUid': uid,
      'email': currentUser?.email ?? '',
      'name': fullName,
      'fullName': fullName,
      'phoneNumber': phoneNumber,
      'stationArea': stationArea,
      'businessName': businessName,
      'yearsOfExperience': yearsOfExperience,
      'servicesOffered': servicesOffered,
      'specialties': specialties,
      'description': description,
      'ghanaCardNumber': ghanaCardNumber,
      'photoUrl': photoUrl,
      'ghanaCardPhotoUrl': ghanaCardPhotoUrl,
      'category': category,
      ...extra,
    };

    final isRoom = category == 'Room for Rent';

    await _writeApprovalProviderDoc(
      collection: collection,
      docRef: providerRef,
      includeRatingFields: !isRoom,
      fields: fields,
    );

    await _userDoc(uid).set({
      'accountType': 'provider',
      'providerRegistered': true,
      'providerType': category,
      'providerCategory': category,
      'providerCategoryId': category,
      'providerCategoryName': category,
      'providerDocId': uid,
      'providerApplicationId': uid,
      'providerStatus': 'pending',
      'providerAvailable': false,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _db.collection('provider_applications').doc(uid).set({
      'uid': uid,
      'email': currentUser?.email ?? '',
      'category': category,
      'categoryId': category,
      'categoryName': category,
      'providerCollection': collection,
      'providerDocId': uid,
      'displayName': fullName,
      'phoneNumber': phoneNumber,
      'location': stationArea,
      'status': 'pending',
      'profileSubmitted': true,
      'submittedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    try {
      await NotificationService.notifyAdmin(
        title: 'New $category Provider Registration',
        body: '$fullName has completed the $category provider registration and is waiting for approval.',
        category: category,
        itemId: uid,
      );
    } catch (e) {
      print('[AuthService] Provider notification failed: $e');
    }
  }

  // ---------------------------------------------------------------------
  // Admin: unified provider management (all categories)
  // ---------------------------------------------------------------------

  /// Collection name for every provider category, keyed by the same
  /// category label used in HomeScreen's categories list.
  static const Map<String, String> providerCollections = {
    'Okada': 'okada_riders',
    'Aboboyaa': 'aboboyaa_riders',
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
    'Teacher': 'teachers',
    'Home Food': 'home_cooks',
    'Room for Rent': 'rooms_for_rent',
    'Event Planner': 'event_planners',
    'Motor Mechanic': 'motor_mechanics',
    'Ride Along': 'ride_along',

  };



  // ---------------------------------------------------------------------
  // Event Planner (screens/model not built yet — approve stub only)
  // ---------------------------------------------------------------------
  Future<void> approveEventPlanner(String id) async {
    await _db.collection('event_planners').doc(id).update({
      'isApproved': true,
      'isPending': false,
    });
  }

  // ---------------------------------------------------------------------
  // Ride Along (car-share commute matching)
  // ---------------------------------------------------------------------

  /// Self-registration path -- a driver posts a ride from AddRideAlongScreen.
  /// Not keyed by uid -- like registerAsRoomForRent, one driver may post
  /// several rides over time (e.g. today's one-off trip AND a standing
  /// weekday commute), so each call creates a new auto-ID doc.
  ///
  /// [rideType] is 'oneTime' or 'recurring'. Pass [departureDateTime] for a
  /// one-time trip, or [departureTime] + [recurringDays] for a recurring
  /// commute -- RideAlong.fromMap() reads whichever pair is present.
  /// Starts isPending: true / isApproved: false, same Ghana-Card-gated
  /// admin approval flow as every other provider category.
  Future<String> registerAsRideAlongDriver({
    required String driverName,
    required String phoneNumber,
    required String fromArea,
    required String toArea,
    required String stationArea,
    required String rideType,
    DateTime? departureDateTime,
    String? departureTime,
    List<String> recurringDays = const [],
    required int seatsTotal,
    required double pricePerSeat,
    String? carModel,
    String? carColor,
    String? plateNumber,
    String? notes,
    required String ghanaCardNumber,
    File? ghanaCardImage,
    List<File> photos = const [],
  }) async {
    final uid = currentUser?.uid;
    if (uid == null) throw Exception('No signed-in user');

    await assertProviderCategoryAllowed('Ride Along');

    final docRef = _db.collection('ride_along').doc();
    final uploadKey = '${uid}_${docRef.id}';
    final photoUrls = photos.isEmpty ? <String>[] : await _uploadPhotos(uploadKey, photos);

    String? ghanaCardPhotoUrl;
    if (ghanaCardImage != null) {
      ghanaCardPhotoUrl =
      await PhotoUploadService.uploadGhanaCardPhoto(uid: uploadKey, photo: ghanaCardImage);
    }

    return _writeApprovalProviderDoc(
      collection: 'ride_along',
      docRef: docRef,
      fields: {
        'driverUid': uid,
        'driverName': driverName,
        'phoneNumber': phoneNumber,
        'fromArea': fromArea,
        'toArea': toArea,
        'stationArea': stationArea,
        'rideType': rideType,
        'departureDateTime':
        departureDateTime != null ? Timestamp.fromDate(departureDateTime) : null,
        'departureTime': departureTime,
        'recurringDays': recurringDays,
        'seatsTotal': seatsTotal,
        'seatsAvailable': seatsTotal,
        'pricePerSeat': pricePerSeat,
        'carModel': carModel,
        'carColor': carColor,
        'plateNumber': plateNumber,
        'notes': notes,
        'photoUrls': photoUrls,
        'isActive': true,
        'ghanaCardNumber': ghanaCardNumber,
        if (ghanaCardPhotoUrl != null) 'ghanaCardPhotoUrl': ghanaCardPhotoUrl,
      },
    );
  }


  /// Admin-adds-directly path -- mirrors addRoomForRentByAdmin /
  /// addHotelByAdmin exactly: no signed-in driver uid to key uploads by,
  /// so the new doc's own id is used as the upload-path prefix, and the
  /// Ghana Card photo is uploaded inline here. Still starts isPending:
  /// true / isApproved: false so it goes through the same one-tap
  /// "Approve" flow as every other admin-add screen.
  Future<String> addRideAlongByAdmin({
    required String driverName,
    required String phoneNumber,
    required String fromArea,
    required String toArea,
    required String stationArea,
    required String rideType,
    DateTime? departureDateTime,
    String? departureTime,
    List<String> recurringDays = const [],
    required int seatsTotal,
    required double pricePerSeat,
    String? carModel,
    String? carColor,
    String? plateNumber,
    String? notes,
    List<File> photos = const [],
    String? ghanaCardNumber,
    File? ghanaCardImage,
  }) async {
    final docRef = _db.collection('ride_along').doc();
    final uploadKey = 'admin_${docRef.id}';

    final photoUrls = photos.isEmpty ? <String>[] : await _uploadPhotos(uploadKey, photos);

    String? ghanaCardPhotoUrl;
    if (ghanaCardImage != null) {
      ghanaCardPhotoUrl =
      await PhotoUploadService.uploadGhanaCardPhoto(uid: uploadKey, photo: ghanaCardImage);
    }

    return _writeApprovalProviderDoc(
      collection: 'ride_along',
      docRef: docRef,
      fields: {
        'driverUid': null,
        'driverName': driverName,
        'phoneNumber': phoneNumber,
        'fromArea': fromArea,
        'toArea': toArea,
        'stationArea': stationArea,
        'rideType': rideType,
        'departureDateTime':
        departureDateTime != null ? Timestamp.fromDate(departureDateTime) : null,
        'departureTime': departureTime,
        'recurringDays': recurringDays,
        'seatsTotal': seatsTotal,
        'seatsAvailable': seatsTotal,
        'pricePerSeat': pricePerSeat,
        'carModel': carModel,
        'carColor': carColor,
        'plateNumber': plateNumber,
        'notes': notes,
        'photoUrls': photoUrls,
        'isActive': true,
        'ghanaCardNumber': ghanaCardNumber ?? '',
        'ghanaCardPhotoUrl': ghanaCardPhotoUrl,
      },
    );
  }

  /// Admin-only: makes a ride visible in the public RideAlongScreen list.
  /// Mirrors approveHotel / approveRoomForRent.
  Future<void> approveRideAlong(String id) async {
    await _db.collection('ride_along').doc(id).update({
      'isApproved': true,
      'isPending': false,
    });
  }

  /// Driver toggle -- pauses/resumes a listing (e.g. a recurring commute
  /// the driver is skipping this week, or a one-time trip that already
  /// happened) without deleting the record.
  Future<void> setRideAlongActive(String id, bool isActive) async {
    await _db.collection('ride_along').doc(id).update({'isActive': isActive});
  }

  Future<void> deleteRideAlong(String id) async {
    await _db.collection('ride_along').doc(id).delete();
  }

  /// Live stream of approved, active rides for the public RideAlongScreen.
  Stream<QuerySnapshot<Map<String, dynamic>>> rideAlongStream() {
    return _db
        .collection('ride_along')
        .where('isApproved', isEqualTo: true)
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Rides posted by the currently signed-in driver (approved or not, and
  /// including paused ones), for their "My Rides" management screen.
  Stream<QuerySnapshot<Map<String, dynamic>>> myPostedRidesStream() {
    final uid = currentUser?.uid;
    if (uid == null) return const Stream.empty();
    return _db
        .collection('ride_along')
        .where('driverUid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Returns true if the currently signed-in user has posted at least one
  /// ride_along doc (driverUid == uid). Ride Along has no single per-user
  /// "driver doc" the way Okada/Aboboyaa riders do -- a driver can post
  /// several rides -- so unlike isOkadaRider()/isAboboyaaRider() this
  /// checks the collection directly rather than a flag on the user doc.
  /// Used by AccountScreen to decide whether to show the "My Rides" entry.
  Future<bool> isRideAlongDriver() async {
    final uid = currentUser?.uid;
    if (uid == null) return false;
    final snap = await _db
        .collection('ride_along')
        .where('driverUid', isEqualTo: uid)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  // ---- Join requests: ride_along/{rideId}/requests/{passengerUid} ----

  /// Passenger taps "Request Seat". The request doc is keyed by the
  /// passenger's own uid (one active request per passenger per ride), so
  /// getMyRideRequest() below is a single cheap doc read rather than a
  /// query. Pulls the passenger's name/phone from their users/{uid}
  /// profile so they don't have to retype it.
  Future<void> requestToJoinRide({
    required String rideId,
    required int seatsRequested,
    String? note,
  }) async {
    final uid = currentUser?.uid;
    if (uid == null) throw Exception('No signed-in user');

    final userSnap = await _userDoc(uid).get();
    final passengerName = (userSnap.data()?['fullName'] as String?) ?? 'Passenger';
    final passengerPhone = (userSnap.data()?['phoneNumber'] as String?) ?? '';

    await _db.collection('ride_along').doc(rideId).collection('requests').doc(uid).set({
      'rideId': rideId,
      'passengerUid': uid,
      'passengerName': passengerName,
      'passengerPhone': passengerPhone,
      'seatsRequested': seatsRequested,
      'note': note,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Live stream of join requests for a ride, newest first. Used by the
  /// driver's ManageRideRequestsScreen.
  Stream<QuerySnapshot<Map<String, dynamic>>> rideJoinRequestsStream(String rideId) {
    return _db
        .collection('ride_along')
        .doc(rideId)
        .collection('requests')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// The signed-in passenger's own request doc for a ride, or null if
  /// they haven't asked yet -- lets RideAlongDetailScreen swap the
  /// "Request Seat" button for a status pill once they have.
  Future<Map<String, dynamic>?> getMyRideRequest(String rideId) async {
    final uid = currentUser?.uid;
    if (uid == null) return null;
    final snap =
    await _db.collection('ride_along').doc(rideId).collection('requests').doc(uid).get();
    return snap.data();
  }

  /// Driver approves or declines a join request. On approve, atomically
  /// decrements seatsAvailable by the requested seat count inside a
  /// transaction (same pattern as submitElectricianReview's rating
  /// recompute) so two near-simultaneous approvals can't overbook the
  /// car. Throws if there aren't enough seats left for this request.
  Future<void> respondToRideRequest({
    required String rideId,
    required String requestId,
    required bool approve,
  }) async {
    final rideRef = _db.collection('ride_along').doc(rideId);
    final reqRef = rideRef.collection('requests').doc(requestId);

    await _db.runTransaction((tx) async {
      final reqSnap = await tx.get(reqRef);
      if (!reqSnap.exists) throw Exception('Request no longer exists');

      if (!approve) {
        tx.update(reqRef, {'status': 'declined'});
        return;
      }

      final seatsRequested = (reqSnap.data()?['seatsRequested'] ?? 1) as int;
      final rideSnap = await tx.get(rideRef);
      final seatsAvailable = (rideSnap.data()?['seatsAvailable'] ?? 0) as int;
      if (seatsRequested > seatsAvailable) {
        throw Exception('Not enough seats left for this request');
      }

      tx.update(reqRef, {'status': 'approved'});
      tx.update(rideRef, {'seatsAvailable': seatsAvailable - seatsRequested});
    });
  }

  /// Passenger (or driver) cancels a request. If it had already been
  /// approved, the reserved seats are handed back to seatsAvailable.
  Future<void> cancelRideRequest(String rideId, String requestId) async {
    final rideRef = _db.collection('ride_along').doc(rideId);
    final reqRef = rideRef.collection('requests').doc(requestId);

    await _db.runTransaction((tx) async {
      final reqSnap = await tx.get(reqRef);
      if (!reqSnap.exists) return;
      final wasApproved = reqSnap.data()?['status'] == 'approved';
      final seatsRequested = (reqSnap.data()?['seatsRequested'] ?? 1) as int;

      tx.update(reqRef, {'status': 'cancelled'});

      if (wasApproved) {
        final rideSnap = await tx.get(rideRef);
        final seatsAvailable = (rideSnap.data()?['seatsAvailable'] ?? 0) as int;
        tx.update(rideRef, {'seatsAvailable': seatsAvailable + seatsRequested});
      }
    });
  }


  Future<void> approveMotorMechanic(String id) async {
    await _db.collection('motor_mechanics').doc(id).update({
      'isApproved': true,
      'isPending': false,
    });
  }

  Future<void> rejectMotorMechanic(String id, {String? reason}) async {
    await _db.collection('motor_mechanics').doc(id).update({
      'isApproved': false,
      'isPending': false,
      'rejectionReason': reason ?? '',
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> motorMechanicReviewsStream(String mechanicId) {
    return _db
        .collection('motor_mechanics')
        .doc(mechanicId)
        .collection('reviews')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> submitMotorMechanicReview({
    required String mechanicId,
    required String reviewerName,
    required double rating,
    required String comment,
  }) async {
    final mechanicRef = _db.collection('motor_mechanics').doc(mechanicId);
    final reviewRef = mechanicRef.collection('reviews').doc();

    await _db.runTransaction((txn) async {
      final snap = await txn.get(mechanicRef);
      final data = snap.data() ?? {};
      final currentCount = (data['reviewCount'] ?? 0) as int;
      final currentRating = ((data['rating'] ?? 0) as num).toDouble();
      final newCount = currentCount + 1;
      final newRating = ((currentRating * currentCount) + rating) / newCount;

      txn.set(reviewRef, {
        'reviewerName': reviewerName.trim().isEmpty ? 'Anonymous' : reviewerName.trim(),
        'rating': rating,
        'comment': comment.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      txn.update(mechanicRef, {
        'rating': newRating,
        'reviewCount': newCount,
      });
    });
  }

  Stream<int> pendingMotorMechanicsCountStream() {
    return _db
        .collection('motor_mechanics')
        .where('isPending', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

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
    final ref = _db.collection(collection).doc(id);
    final snap = await ref.get();
    final data = snap.data() ?? <String, dynamic>{};

    if (collection == 'okada_riders' ||
        collection == 'aboboyaa_riders') {
      await ref.set({
        'verificationStatus': approved ? 'approved' : 'pending',
        'isApproved': approved,
        'isPending': !approved,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } else {
      await ref.set({
        'isApproved': approved,
        'isPending': !approved,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    final providerUid = collection == 'okada_riders' ||
        collection == 'aboboyaa_riders'
        ? id
        : (data['uid']?.toString() ??
        data['driverUid']?.toString() ??
        data['ownerUid']?.toString() ??
        data['landlordUid']?.toString() ??
        data['userUid']?.toString());

    final category = _categoryForProviderCollection(collection);

    if (providerUid != null && category != null) {
      await syncProviderApprovalToUser(
        uid: providerUid,
        category: category,
        approved: approved,
      );
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

  // ---------------------------------------------------------------------
  // Reviews (shared across every provider category)
  // ---------------------------------------------------------------------

  Stream<QuerySnapshot<Map<String, dynamic>>> _reviewsStream(String collection, String id) {
    return _db.collection(collection).doc(id).collection('reviews')
        .orderBy('createdAt', descending: true).snapshots();
  }

  Future<void> _submitReview(String collection, String id, String reviewerName, double rating, String comment) async {
    final docRef = _db.collection(collection).doc(id);
    final reviewRef = docRef.collection('reviews').doc();

    await _db.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      final data = snap.data() ?? <String, dynamic>{};
      final currentCount = (data['reviewCount'] ?? 0) as int;
      final currentRating = (data['rating'] ?? 0.0).toDouble();
      final newCount = currentCount + 1;
      final newRating = ((currentRating * currentCount) + rating) / newCount;

      final reviewData = Review(
        id: reviewRef.id,
        reviewerName: reviewerName.trim().isEmpty ? 'Anonymous' : reviewerName.trim(),
        rating: rating,
        comment: comment.trim(),
      ).toMap();

      final reviewerUid = currentUser?.uid;
      if (reviewerUid != null && reviewerUid.isNotEmpty) {
        reviewData['reviewerUid'] = reviewerUid;
      }
      reviewData['providerCollection'] = collection;
      reviewData['providerId'] = id;

      tx.set(reviewRef, reviewData);

      tx.update(docRef, {
        'rating': double.parse(newRating.toStringAsFixed(2)),
        'reviewCount': newCount,
      });
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> electricianReviewsStream(String id) => _reviewsStream('electricians', id);
  Future<void> submitElectricianReview({required String electricianId, required String reviewerName, required double rating, String comment = ''}) =>
      _submitReview('electricians', electricianId, reviewerName, rating, comment);

  Stream<QuerySnapshot<Map<String, dynamic>>> mechanicReviewsStream(String id) => _reviewsStream('mechanics', id);
  Future<void> submitMechanicReview({required String mechanicId, required String reviewerName, required double rating, String comment = ''}) =>
      _submitReview('mechanics', mechanicId, reviewerName, rating, comment);

  Stream<QuerySnapshot<Map<String, dynamic>>> carpenterReviewsStream(String id) => _reviewsStream('carpenters', id);
  Future<void> submitCarpenterReview({required String carpenterId, required String reviewerName, required double rating, String comment = ''}) =>
      _submitReview('carpenters', carpenterId, reviewerName, rating, comment);

  Stream<QuerySnapshot<Map<String, dynamic>>> plumberReviewsStream(String id) => _reviewsStream('plumbers', id);
  Future<void> submitPlumberReview({required String plumberId, required String reviewerName, required double rating, String comment = ''}) =>
      _submitReview('plumbers', plumberId, reviewerName, rating, comment);

  Stream<QuerySnapshot<Map<String, dynamic>>> tailorReviewsStream(String id) => _reviewsStream('tailors', id);
  Future<void> submitTailorReview({required String tailorId, required String reviewerName, required double rating, String comment = ''}) =>
      _submitReview('tailors', tailorId, reviewerName, rating, comment);

  Stream<QuerySnapshot<Map<String, dynamic>>> teacherReviewsStream(String id) => _reviewsStream('teachers', id);
  Future<void> submitTeacherReview({required String teacherId, required String reviewerName, required double rating, String comment = ''}) =>
      _submitReview('teachers', teacherId, reviewerName, rating, comment);

  Stream<QuerySnapshot<Map<String, dynamic>>> welderReviewsStream(String id) => _reviewsStream('welders', id);
  Future<void> submitWelderReview({required String welderId, required String reviewerName, required double rating, String comment = ''}) =>
      _submitReview('welders', welderId, reviewerName, rating, comment);

  Stream<QuerySnapshot<Map<String, dynamic>>> okadaRiderReviewsStream(String id) => _reviewsStream('okada_riders', id);
  Future<void> submitOkadaRiderReview({required String riderId, required String reviewerName, required double rating, String comment = ''}) =>
      _submitReview('okada_riders', riderId, reviewerName, rating, comment);
}