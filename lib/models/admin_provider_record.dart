/// Unified wrapper around a single provider doc from any category
/// collection (okada_riders, mechanics, steel_benders, carpenters,
/// tailors, plumbers, electricians).
///
/// Field *names* differ per collection -- e.g. the display name is
/// 'riderName' in okada_riders, 'fullName' in steel_benders/carpenters,
/// 'name' in mechanics/tailors/plumbers/electricians -- so this class
/// normalizes the handful of fields ManageProvidersScreen needs for the
/// list view, while keeping the full raw [data] map around so
/// ProviderEditScreen can edit every field generically.
class AdminProviderRecord {
  final String id;
  final String category;
  final String collection;
  final Map<String, dynamic> data;

  AdminProviderRecord({
    required this.id,
    required this.category,
    required this.collection,
    required this.data,
  });

  String get displayName => (data['riderName'] ??
          data['fullName'] ??
          data['name'] ??
          data['businessName'] ??
          'Unnamed')
      as String;

  String get phoneNumber => (data['phoneNumber'] ?? '') as String;

  String? get photoUrl =>
      (data['photoUrl'] ?? data['riderPhotoUrl']) as String?;

  /// True for both the okada_riders 'verificationStatus' string shape and
  /// every other category's isApproved/isPending boolean shape.
  bool get isApproved {
    if (collection == 'okada_riders') {
      return data['verificationStatus'] == 'approved';
    }
    return data['isApproved'] == true;
  }

  /// Doc id doubles as the linked users/{uid} doc id whenever this
  /// provider self-registered (all registerAsX methods key the doc by
  /// uid). Admin-added providers get an auto-generated id with no linked
  /// user doc -- deleting a non-existent users/{id} doc is a harmless
  /// no-op, so callers can pass this through unconditionally.
  String get possibleUid => id;
}
