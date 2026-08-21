/// Normalized provider record used by the admin tools.
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

  String get displayName {
    final value = data['riderName'] ??
        data['fullName'] ??
        data['name'] ??
        data['businessName'] ??
        data['landlordName'];

    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? 'Unnamed provider' : text;
  }

  String get phoneNumber {
    return (data['phoneNumber'] ??
            data['phone'] ??
            data['contactNumber'] ??
            '')
        .toString();
  }

  /// Handles the different photo field names used by provider collections.
  /// Welder uses `photoUrl`, while Okada uses `riderPhotoUrl`.
  String? get photoUrl {
    final candidates = [
      data['photoUrl'],
      data['riderPhotoUrl'],
      data['profilePhotoUrl'],
      data['imageUrl'],
    ];

    for (final value in candidates) {
      final text = value?.toString().trim();
      if (text != null && text.isNotEmpty) return text;
    }

    final rawPhotos = data['photoUrls'];
    if (rawPhotos is List) {
      for (final value in rawPhotos) {
        final text = value?.toString().trim();
        if (text != null && text.isNotEmpty) return text;
      }
    }

    return null;
  }

  bool get isApproved {
    if (data['verificationStatus'] != null) {
      return data['verificationStatus'] == 'approved' ||
          data['verificationStatus'] == 'verified';
    }
    return data['isApproved'] == true;
  }

  bool get isPending {
    if (data['verificationStatus'] != null) {
      return data['verificationStatus'] == 'pending';
    }
    return data['isPending'] == true || !isApproved;
  }

  String get possibleUid => id;
}
