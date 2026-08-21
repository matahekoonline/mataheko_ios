import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/marketplace_item.dart';
import 'photo_upload_service.dart';

class MarketplaceService {
  MarketplaceService._();

  static final MarketplaceService instance = MarketplaceService._();

  /// Maximum number of photos allowed for one marketplace item.
  static const int maxPhotosPerItem = 4;

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _items =>
      _db.collection('marketplace_items');

  // ============================================================
  // HELPERS
  // ============================================================

  String _clean(String? value) {
    return value?.trim() ?? '';
  }

  List<String> _cleanPhotoUrls(List<String>? urls) {
    if (urls == null || urls.isEmpty) {
      return <String>[];
    }

    final cleaned = <String>[];
    final seen = <String>{};

    for (final url in urls) {
      final value = url.trim();

      if (value.isEmpty) {
        continue;
      }

      if (seen.contains(value)) {
        continue;
      }

      seen.add(value);
      cleaned.add(value);

      if (cleaned.length >= maxPhotosPerItem) {
        break;
      }
    }

    return cleaned;
  }

  void _validatePhotoCount(List<String> photoUrls) {
    if (photoUrls.length > maxPhotosPerItem) {
      throw Exception(
        'A marketplace item can have a maximum of '
            '$maxPhotosPerItem photos.',
      );
    }
  }

  void _validateRequiredText({
    required String title,
    required String description,
    required String price,
    required String locationText,
    required String sellerPhone,
  }) {
    if (_clean(title).isEmpty) {
      throw Exception('Please enter the item title.');
    }

    if (_clean(description).isEmpty) {
      throw Exception('Please enter a description.');
    }

    if (_clean(price).isEmpty) {
      throw Exception('Please enter the item price.');
    }

    if (_clean(locationText).isEmpty) {
      throw Exception('Please enter the item location.');
    }

    if (_clean(sellerPhone).isEmpty) {
      throw Exception('Please enter the seller phone number.');
    }
  }

  // ============================================================
  // PUBLIC MARKETPLACE ITEMS
  // ============================================================

  /// Streams approved marketplace items.
  Stream<List<MarketplaceItem>> streamItems() {
    return _items
        .where('isApproved', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) {
        return snapshot.docs
            .map(
              (doc) {
            try {
              return MarketplaceItem.fromMap(
                doc.data(),
                doc.id,
              );
            } catch (e) {
              return null;
            }
          },
        )
            .whereType<MarketplaceItem>()
            .toList();
      },
    );
  }

  // ============================================================
  // PENDING ITEMS
  // ============================================================

  /// Streams marketplace items waiting for admin approval.
  Stream<List<MarketplaceItem>> streamPendingItems() {
    return _items
        .where('isApproved', isEqualTo: false)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map(
          (snapshot) {
        return snapshot.docs
            .map(
              (doc) {
            try {
              return MarketplaceItem.fromMap(
                doc.data(),
                doc.id,
              );
            } catch (e) {
              return null;
            }
          },
        )
            .whereType<MarketplaceItem>()
            .toList();
      },
    );
  }

  // ============================================================
  // ALL ITEMS - ADMIN
  // ============================================================

  /// Streams all marketplace items.
  ///
  /// This is intended for the admin dashboard.
  Stream<List<MarketplaceItem>> streamAllItems() {
    return _items
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) {
        return snapshot.docs
            .map(
              (doc) {
            try {
              return MarketplaceItem.fromMap(
                doc.data(),
                doc.id,
              );
            } catch (e) {
              return null;
            }
          },
        )
            .whereType<MarketplaceItem>()
            .toList();
      },
    );
  }

  // ============================================================
  // MY ITEMS
  // ============================================================

  /// Streams the currently signed-in user's marketplace items.
  Stream<List<MarketplaceItem>> streamMyItems() {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return Stream.value(const <MarketplaceItem>[]);
    }

    return _items
        .where('sellerId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) {
        return snapshot.docs
            .map(
              (doc) {
            try {
              return MarketplaceItem.fromMap(
                doc.data(),
                doc.id,
              );
            } catch (e) {
              return null;
            }
          },
        )
            .whereType<MarketplaceItem>()
            .toList();
      },
    );
  }

  // ============================================================
  // CREATE MARKETPLACE ITEM
  // ============================================================

  /// Creates a new marketplace item.
  ///
  /// Maximum 4 photos are allowed.
  Future<String> postItem({
    required String title,
    required String description,
    required String price,
    required String locationText,
    String? areaDetail,
    required String sellerPhone,
    required List<File> photos,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception('No signed-in user.');
    }

    final cleanTitle = _clean(title);
    final cleanDescription = _clean(description);
    final cleanPrice = _clean(price);
    final cleanLocation = _clean(locationText);
    final cleanPhone = _clean(sellerPhone);
    final cleanArea = _clean(areaDetail);

    if (cleanTitle.isEmpty) {
      throw Exception('Please enter the item title.');
    }

    if (cleanDescription.isEmpty) {
      throw Exception('Please enter a description.');
    }

    if (cleanPrice.isEmpty) {
      throw Exception('Please enter the item price.');
    }

    if (cleanLocation.isEmpty) {
      throw Exception('Please enter the item location.');
    }

    if (cleanPhone.isEmpty) {
      throw Exception('Please enter the seller phone number.');
    }

    // ----------------------------------------------------------
    // PHOTO VALIDATION
    // ----------------------------------------------------------

    if (photos.isEmpty) {
      throw Exception(
        'Please select at least one photo.',
      );
    }

    if (photos.length > maxPhotosPerItem) {
      throw Exception(
        'You can upload a maximum of '
            '$maxPhotosPerItem photos.',
      );
    }

    // ----------------------------------------------------------
    // UPLOAD PHOTOS
    // ----------------------------------------------------------

    final List<String> photoUrls = [];

    for (final photo in photos.take(maxPhotosPerItem)) {
      final url = await PhotoUploadService.uploadMarketplacePhoto(
        uid: user.uid,
        photo: photo,
      );

      final cleanUrl = _clean(url);

      if (cleanUrl.isEmpty) {
        throw Exception(
          'One of the marketplace photos failed to upload.',
        );
      }

      if (!photoUrls.contains(cleanUrl)) {
        photoUrls.add(cleanUrl);
      }
    }

    if (photoUrls.isEmpty) {
      throw Exception(
        'No marketplace photos were uploaded.',
      );
    }

    // ----------------------------------------------------------
    // CREATE FIRESTORE DOCUMENT
    // ----------------------------------------------------------

    final doc = await _items.add({
      'sellerId': user.uid,

      'title': cleanTitle,
      'description': cleanDescription,
      'price': cleanPrice,

      'locationText': cleanLocation,

      'areaDetail': cleanArea.isEmpty ? null : cleanArea,

      'sellerPhone': cleanPhone,

      'photoUrls': photoUrls
          .take(maxPhotosPerItem)
          .toList(),

      // Statistics
      'viewCount': 0,
      'rating': 0.0,
      'reviewCount': 0,

      // Moderation
      'isVerified': false,
      'isApproved': false,

      // Dates
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return doc.id;
  }

  // ============================================================
  // GET ONE ITEM
  // ============================================================

  Future<MarketplaceItem> getItem(
      String itemId,
      ) async {
    final cleanId = _clean(itemId);

    if (cleanId.isEmpty) {
      throw Exception('Invalid marketplace item ID.');
    }

    final doc = await _items.doc(cleanId).get();

    if (!doc.exists || doc.data() == null) {
      throw Exception(
        'Marketplace item not found.',
      );
    }

    return MarketplaceItem.fromMap(
      doc.data()!,
      doc.id,
    );
  }

  // ============================================================
  // INCREMENT VIEWS
  // ============================================================

  Future<void> incrementViewCount(
      String itemId,
      ) async {
    final cleanId = _clean(itemId);

    if (cleanId.isEmpty) {
      return;
    }

    await _items.doc(cleanId).update({
      'viewCount': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ============================================================
  // APPROVE ITEM
  // ============================================================

  /// Approves a marketplace item.
  Future<void> approveItem(
      String itemId,
      ) async {
    final cleanId = _clean(itemId);

    if (cleanId.isEmpty) {
      throw Exception(
        'Invalid marketplace item ID.',
      );
    }

    await _items.doc(cleanId).update({
      'isApproved': true,
      'isVerified': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ============================================================
  // ADMIN APPROVE ITEM
  // ============================================================

  /// Admin version of approveItem().
  ///
  /// Kept separately because the admin dashboard calls
  /// adminApproveItem().
  Future<void> adminApproveItem(
      String itemId,
      ) async {
    await approveItem(itemId);
  }

  // ============================================================
  // REJECT ITEM
  // ============================================================

  /// Rejects/removes an item.
  Future<void> rejectItem(
      String itemId,
      ) async {
    final cleanId = _clean(itemId);

    if (cleanId.isEmpty) {
      throw Exception(
        'Invalid marketplace item ID.',
      );
    }

    await _items.doc(cleanId).delete();
  }

  // ============================================================
  // DELETE ITEM
  // ============================================================

  Future<void> deleteItem(
      String itemId,
      ) async {
    final cleanId = _clean(itemId);

    if (cleanId.isEmpty) {
      throw Exception(
        'Invalid marketplace item ID.',
      );
    }

    await _items.doc(cleanId).delete();
  }

  // ============================================================
  // ADMIN DELETE ITEM
  // ============================================================

  /// Admin dashboard delete method.
  ///
  /// The dashboard can safely call:
  ///
  /// await MarketplaceService.instance.adminDeleteItem(itemId);
  Future<void> adminDeleteItem(
      String itemId,
      ) async {
    await deleteItem(itemId);
  }

  // ============================================================
  // ADMIN UPDATE ITEM
  // ============================================================

  /// Updates an existing marketplace item from the admin dashboard.
  ///
  /// IMPORTANT:
  /// - Maximum 4 photos
  /// - Existing sellerId is NOT overwritten
  /// - Existing statistics are NOT overwritten
  /// - Existing createdAt is NOT overwritten
  Future<void> adminUpdateItem({
    required String itemId,
    required String title,
    required String description,
    required String price,
    required String locationText,
    String? areaDetail,
    required String sellerPhone,
    required List<String> photoUrls,
    required bool isApproved,
  }) async {
    final cleanId = _clean(itemId);

    if (cleanId.isEmpty) {
      throw Exception(
        'Invalid marketplace item ID.',
      );
    }

    // ----------------------------------------------------------
    // CLEAN PHOTOS
    // ----------------------------------------------------------

    final cleanPhotos = _cleanPhotoUrls(
      photoUrls,
    );

    _validatePhotoCount(
      cleanPhotos,
    );

    // ----------------------------------------------------------
    // VALIDATE TEXT
    // ----------------------------------------------------------

    _validateRequiredText(
      title: title,
      description: description,
      price: price,
      locationText: locationText,
      sellerPhone: sellerPhone,
    );

    // ----------------------------------------------------------
    // MAKE SURE ITEM EXISTS
    // ----------------------------------------------------------

    final existingDoc = await _items.doc(cleanId).get();

    if (!existingDoc.exists) {
      throw Exception(
        'Marketplace item not found.',
      );
    }

    // ----------------------------------------------------------
    // UPDATE
    // ----------------------------------------------------------

    await _items.doc(cleanId).update({
      'title': _clean(title),
      'description': _clean(description),
      'price': _clean(price),
      'locationText': _clean(locationText),

      'areaDetail': _clean(areaDetail).isEmpty
          ? null
          : _clean(areaDetail),

      'sellerPhone': _clean(sellerPhone),

      'photoUrls': cleanPhotos,

      'isApproved': isApproved,
      'isVerified': isApproved,

      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ============================================================
  // ADMIN TOGGLE APPROVAL
  // ============================================================

  /// Allows the admin dashboard to explicitly set approval status.
  Future<void> adminSetApproval({
    required String itemId,
    required bool approved,
  }) async {
    final cleanId = _clean(itemId);

    if (cleanId.isEmpty) {
      throw Exception(
        'Invalid marketplace item ID.',
      );
    }

    await _items.doc(cleanId).update({
      'isApproved': approved,
      'isVerified': approved,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ============================================================
  // ADMIN REJECT
  // ============================================================

  Future<void> adminRejectItem(
      String itemId,
      ) async {
    await rejectItem(itemId);
  }

  // ============================================================
  // ADMIN PHOTO UPDATE
  // ============================================================

  /// Updates only the photos of an existing marketplace item.
  ///
  /// Useful when the admin removes photos without changing
  /// the rest of the listing.
  Future<void> adminUpdatePhotos({
    required String itemId,
    required List<String> photoUrls,
  }) async {
    final cleanId = _clean(itemId);

    if (cleanId.isEmpty) {
      throw Exception(
        'Invalid marketplace item ID.',
      );
    }

    final cleanPhotos = _cleanPhotoUrls(
      photoUrls,
    );

    _validatePhotoCount(
      cleanPhotos,
    );

    final doc = await _items.doc(cleanId).get();

    if (!doc.exists) {
      throw Exception(
        'Marketplace item not found.',
      );
    }

    await _items.doc(cleanId).update({
      'photoUrls': cleanPhotos,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ============================================================
  // ADD PHOTO TO EXISTING ITEM
  // ============================================================

  /// Uploads one additional marketplace photo to an existing item.
  ///
  /// The method checks the existing number of photos before
  /// uploading anything.
  Future<void> addMarketplacePhoto({
    required String itemId,
    required File photo,
  }) async {
    final cleanId = _clean(itemId);

    if (cleanId.isEmpty) {
      throw Exception(
        'Invalid marketplace item ID.',
      );
    }

    final doc = await _items.doc(cleanId).get();

    if (!doc.exists || doc.data() == null) {
      throw Exception(
        'Marketplace item not found.',
      );
    }

    final data = doc.data()!;

    final existingPhotos =
    List<String>.from(
      data['photoUrls'] ?? const <String>[],
    );

    final cleanExisting =
    _cleanPhotoUrls(existingPhotos);

    if (cleanExisting.length >= maxPhotosPerItem) {
      throw Exception(
        'This marketplace item already has '
            '$maxPhotosPerItem photos.',
      );
    }

    // Get seller ID so the uploaded photo remains associated
    // with the original marketplace owner.
    final sellerId =
    _clean(data['sellerId'] as String?);

    if (sellerId.isEmpty) {
      throw Exception(
        'Marketplace item has no seller ID.',
      );
    }

    final url =
    await PhotoUploadService.uploadMarketplacePhoto(
      uid: sellerId,
      photo: photo,
    );

    final cleanUrl = _clean(url);

    if (cleanUrl.isEmpty) {
      throw Exception(
        'Photo upload failed.',
      );
    }

    if (cleanExisting.contains(cleanUrl)) {
      return;
    }

    cleanExisting.add(cleanUrl);

    await _items.doc(cleanId).update({
      'photoUrls': cleanExisting
          .take(maxPhotosPerItem)
          .toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ============================================================
  // REMOVE ONE PHOTO
  // ============================================================

  Future<void> removeMarketplacePhoto({
    required String itemId,
    required String photoUrl,
  }) async {
    final cleanId = _clean(itemId);
    final cleanUrl = _clean(photoUrl);

    if (cleanId.isEmpty) {
      throw Exception(
        'Invalid marketplace item ID.',
      );
    }

    if (cleanUrl.isEmpty) {
      throw Exception(
        'Invalid photo URL.',
      );
    }

    final doc = await _items.doc(cleanId).get();

    if (!doc.exists || doc.data() == null) {
      throw Exception(
        'Marketplace item not found.',
      );
    }

    final data = doc.data()!;

    final existingPhotos =
    List<String>.from(
      data['photoUrls'] ?? const <String>[],
    );

    existingPhotos.removeWhere(
          (url) => _clean(url) == cleanUrl,
    );

    await _items.doc(cleanId).update({
      'photoUrls': _cleanPhotoUrls(
        existingPhotos,
      ),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ============================================================
  // ADMIN REPLACE PHOTOS
  // ============================================================

  Future<void> adminReplacePhotos({
    required String itemId,
    required List<File> photos,
  }) async {
    final cleanId = _clean(itemId);

    if (cleanId.isEmpty) {
      throw Exception(
        'Invalid marketplace item ID.',
      );
    }

    if (photos.length > maxPhotosPerItem) {
      throw Exception(
        'You can upload a maximum of '
            '$maxPhotosPerItem photos.',
      );
    }

    final doc = await _items.doc(cleanId).get();

    if (!doc.exists || doc.data() == null) {
      throw Exception(
        'Marketplace item not found.',
      );
    }

    final data = doc.data()!;

    final sellerId =
    _clean(data['sellerId'] as String?);

    if (sellerId.isEmpty) {
      throw Exception(
        'Marketplace item has no seller ID.',
      );
    }

    final uploadedUrls = <String>[];

    for (final photo
    in photos.take(maxPhotosPerItem)) {
      final url =
      await PhotoUploadService.uploadMarketplacePhoto(
        uid: sellerId,
        photo: photo,
      );

      final cleanUrl = _clean(url);

      if (cleanUrl.isEmpty) {
        throw Exception(
          'One of the photos failed to upload.',
        );
      }

      if (!uploadedUrls.contains(cleanUrl)) {
        uploadedUrls.add(cleanUrl);
      }
    }

    await _items.doc(cleanId).update({
      'photoUrls': uploadedUrls
          .take(maxPhotosPerItem)
          .toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ============================================================
  // ADMIN UPDATE PUBLICATION STATUS
  // ============================================================

  Future<void> adminSetPublished({
    required String itemId,
    required bool published,
  }) async {
    final cleanId = _clean(itemId);

    if (cleanId.isEmpty) {
      throw Exception(
        'Invalid marketplace item ID.',
      );
    }

    await _items.doc(cleanId).update({
      'isPublished': published,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}