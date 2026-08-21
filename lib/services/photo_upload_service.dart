import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// All photo uploads for the app go through this single service.
///
/// Photos are uploaded to the PHP server rather than Firebase Storage.
class PhotoUploadService {
  PhotoUploadService._();

  static const String _uploadUrl =
      'https://seghansoccertraining.org/mataheko/upload_photo.php';

  // MUST match the $API_KEY value in upload_photo.php exactly.
  static const String _apiKey = 'f248b9ecd1705a36';

  /// Generic upload.
  ///
  /// Prefer the named helpers below so the `type` value cannot
  /// accidentally be mistyped.
  static Future<String> uploadPhoto({
    required String uid,
    required File photo,
    required String type,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse(_uploadUrl),
    );

    request.fields['uid'] = uid;
    request.fields['api_key'] = _apiKey;
    request.fields['type'] = type;

    request.files.add(
      await http.MultipartFile.fromPath(
        'photo',
        photo.path,
      ),
    );

    final streamedResponse = await request.send();

    final response = await http.Response.fromStream(
      streamedResponse,
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Upload failed (${response.statusCode}): ${response.body}',
      );
    }

    Map<String, dynamic> data;

    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      throw Exception(
        'Invalid response from upload server: ${response.body}',
      );
    }

    if (data['success'] != true) {
      throw Exception(
        data['error']?.toString() ?? 'Upload failed',
      );
    }

    final url = data['url']?.toString();

    if (url == null || url.isEmpty) {
      throw Exception(
        'Upload succeeded but the server did not return a photo URL.',
      );
    }

    return url;
  }

  // ===========================================================================
  // GHANA CARD
  // ===========================================================================

  static Future<String> uploadGhanaCardPhoto({
    required String uid,
    required File photo,
  }) =>
      uploadPhoto(
        uid: uid,
        photo: photo,
        type: 'ghana_cards',
      );

  // ===========================================================================
  // OKADA / RIDER
  // ===========================================================================

  static Future<String> uploadRiderPhoto({
    required String uid,
    required File photo,
  }) =>
      uploadPhoto(
        uid: uid,
        photo: photo,
        type: 'rider_photos',
      );

  // ===========================================================================
  // WELDER
  // ===========================================================================

  static Future<String> uploadWelderPhoto({
    required String uid,
    required File photo,
  }) =>
      uploadPhoto(
        uid: uid,
        photo: photo,
        type: 'welder_photos',
      );

  // ===========================================================================
  // LISTING
  // ===========================================================================

  static Future<String> uploadListingPhoto({
    required String uid,
    required File photo,
  }) =>
      uploadPhoto(
        uid: uid,
        photo: photo,
        type: 'listing_photos',
      );

  // ===========================================================================
  // MARKETPLACE
  // ===========================================================================

  static Future<String> uploadMarketplacePhoto({
    required String uid,
    required File photo,
  }) =>
      uploadPhoto(
        uid: uid,
        photo: photo,
        type: 'marketplace_photos',
      );

  // ===========================================================================
  // PROFILE
  // ===========================================================================

  static Future<String> uploadProfilePhoto({
    required String uid,
    required File photo,
  }) =>
      uploadPhoto(
        uid: uid,
        photo: photo,
        type: 'profile_photos',
      );

  // ===========================================================================
  // HERO BANNER
  // ===========================================================================

  static Future<String> uploadHeroBannerPhoto({
    required String uid,
    required File photo,
  }) =>
      uploadPhoto(
        uid: uid,
        photo: photo,
        type: 'hero_banners',
      );

  // ===========================================================================
  // SPORTS TEAM LOGO
  // ===========================================================================

  static Future<String> uploadTeamLogo({
    required String uid,
    required File photo,
  }) =>
      uploadPhoto(
        uid: uid,
        photo: photo,
        type: 'team_logos',
      );

  // ===========================================================================
  // SPORTS PLAYER PHOTO
  // ===========================================================================

  static Future<String> uploadPlayerPhoto({
    required String uid,
    required File photo,
  }) =>
      uploadPhoto(
        uid: uid,
        photo: photo,
        type: 'player_photos',
      );

  // ===========================================================================
  // LEAGUE SPONSOR LOGO
  // ===========================================================================
  //
  // IMPORTANT:
  // This MUST match upload_photo.php:
  //
  // 'league_sponsor_logos'
  //
  // Do NOT use 'league_sponsors'.
  //

  static Future<String> uploadLeagueSponsorLogo({
    required String uid,
    required File photo,
  }) =>
      uploadPhoto(
        uid: uid,
        photo: photo,
        type: 'league_sponsor_logos',
      );

  // ===========================================================================
  // CATEGORY ICON
  // ===========================================================================

  static Future<String> uploadCategoryIcon({
    required String uid,
    required File photo,
  }) =>
      uploadPhoto(
        uid: uid,
        photo: photo,
        type: 'category_icons',
      );

  // ===========================================================================
  // HOME COOK
  // ===========================================================================

  static Future<String> uploadHomeCookPhoto({
    required String uid,
    required File photo,
  }) =>
      uploadPhoto(
        uid: uid,
        photo: photo,
        type: 'home_cook_photos',
      );
}