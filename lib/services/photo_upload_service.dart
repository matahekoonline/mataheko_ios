import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// All photo uploads for the app go through this single service, which
/// posts to your PHP host instead of Firebase Storage. Keeping every
/// photo type in one place makes it easy to see everything that touches
/// your server.
class PhotoUploadService {
  static const _uploadUrl = 'https://seghansoccertraining.org/mataheko/upload_photo.php';

  // MUST match the $API_KEY value in upload_photo.php exactly.
  static const _apiKey = 'f248b9ecd1705a36';

  /// Generic upload — prefer the named helpers below (uploadGhanaCardPhoto,
  /// uploadRiderPhoto, etc.) so the `type` string can't be mistyped.
  static Future<String> uploadPhoto({
    required String uid,
    required File photo,
    required String type,
  }) async {
    final request = http.MultipartRequest('POST', Uri.parse(_uploadUrl));
    request.fields['uid'] = uid;
    request.fields['api_key'] = _apiKey;
    request.fields['type'] = type;
    request.files.add(await http.MultipartFile.fromPath('photo', photo.path));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw Exception('Upload failed (${response.statusCode})');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['success'] != true) {
      throw Exception(data['error'] as String? ?? 'Upload failed');
    }

    return data['url'] as String;
  }

  static Future<String> uploadGhanaCardPhoto({required String uid, required File photo}) =>
      uploadPhoto(uid: uid, photo: photo, type: 'ghana_cards');

  static Future<String> uploadRiderPhoto({required String uid, required File photo}) =>
      uploadPhoto(uid: uid, photo: photo, type: 'rider_photos');

  static Future<String> uploadListingPhoto({required String uid, required File photo}) =>
      uploadPhoto(uid: uid, photo: photo, type: 'listing_photos');

  static Future<String> uploadMarketplacePhoto({required String uid, required File photo}) =>
      uploadPhoto(uid: uid, photo: photo, type: 'marketplace_photos');

  static Future<String> uploadProfilePhoto({required String uid, required File photo}) =>
      uploadPhoto(uid: uid, photo: photo, type: 'profile_photos');

  /// Hero banner photos (admin-uploaded, shown on the home screen carousel).
  /// `uid` here is actually the banner's id, not a user's — the server
  /// just uses it as a filename prefix, same as every other type.
  static Future<String> uploadHeroBannerPhoto({required String uid, required File photo}) =>
      uploadPhoto(uid: uid, photo: photo, type: 'hero_banners');

  /// Sports team logos. `uid` here is the team's Firestore id, not a
  /// user's — same filename-prefix pattern as hero banner photos.
  ///
  /// NOTE: if upload_photo.php whitelists valid `type` values against a
  /// fixed list of folder names, add 'team_logos' to that list server-side
  /// (and create the matching /uploads/team_logos/ directory) or this call
  /// will fail even though the Dart side is correct.
  static Future<String> uploadTeamLogo({required String uid, required File photo}) =>
      uploadPhoto(uid: uid, photo: photo, type: 'team_logos');

  /// Sports player photos. `uid` here is the player's Firestore id.
  ///
  /// Same server-side note as uploadTeamLogo — needs 'player_photos'
  /// whitelisted in upload_photo.php with a matching uploads subfolder.
  static Future<String> uploadPlayerPhoto({required String uid, required File photo}) =>
      uploadPhoto(uid: uid, photo: photo, type: 'player_photos');

  /// Category icon PNGs (admin-uploaded, shown in the home screen grid).
  /// `uid` here is the category's Firestore id, same filename-prefix
  /// pattern as hero banners and team logos.
  ///
  /// NOTE: requires 'category_icons' added to $allowedTypes in
  /// upload_photo.php.
  static Future<String> uploadCategoryIcon({required String uid, required File photo}) =>
      uploadPhoto(uid: uid, photo: photo, type: 'category_icons');
}