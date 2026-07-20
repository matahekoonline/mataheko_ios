/// A hotel/guesthouse listing.
///
/// Field set is built around "what does someone need to know before they
/// call to book" rather than a generic business-card set of fields:
/// price range, room types, amenities, check-in/out times, and whether
/// they take walk-ins are all things that save a wasted phone call.
class Hotel {
  final String id;

  /// Contact person's name (admin/owner), not shown as the headline --
  /// [businessName] is what the public list/detail screens lead with.
  final String name;
  final String phoneNumber;
  final String businessName;
  final String stationArea;

  final List<String> roomTypes;
  final List<String> amenities;

  /// Price per night, in GHS. Stored as a min/max range since most hotels
  /// quote a range across room types rather than one fixed price.
  final double priceRangeMin;
  final double priceRangeMax;

  final int numberOfRooms;

  /// Free-form display strings (e.g. "12:00 PM") rather than DateTime --
  /// these are daily recurring times, not a specific date/time value.
  final String checkInTime;
  final String checkOutTime;

  final bool offersFreeBreakfast;
  final bool offersAirportPickup;
  final bool acceptsWalkIns;

  /// Multiple photos of the property (exterior, rooms, etc.). The first
  /// entry doubles as the cover photo in list views -- see [coverPhotoUrl].
  final List<String> photoUrls;

  final double rating;
  final int reviewCount;

  final bool isApproved;
  final bool isPending;

  final String ghanaCardNumber;
  final String? ghanaCardPhotoUrl;

  const Hotel({
    required this.id,
    required this.name,
    required this.phoneNumber,
    required this.businessName,
    required this.stationArea,
    required this.roomTypes,
    required this.amenities,
    required this.priceRangeMin,
    required this.priceRangeMax,
    required this.numberOfRooms,
    required this.checkInTime,
    required this.checkOutTime,
    required this.offersFreeBreakfast,
    required this.offersAirportPickup,
    required this.acceptsWalkIns,
    required this.photoUrls,
    required this.rating,
    required this.reviewCount,
    required this.isApproved,
    required this.isPending,
    required this.ghanaCardNumber,
    this.ghanaCardPhotoUrl,
  });

  String? get coverPhotoUrl => photoUrls.isNotEmpty ? photoUrls.first : null;

  /// e.g. "GHS 150 - 400 / night", or a single figure if min == max.
  String get priceRangeLabel {
    final min = priceRangeMin.toStringAsFixed(0);
    final max = priceRangeMax.toStringAsFixed(0);
    if (priceRangeMin <= 0 && priceRangeMax <= 0) return 'Price on request';
    if (min == max) return 'GHS $min / night';
    return 'GHS $min - $max / night';
  }

  factory Hotel.fromMap(String id, Map<String, dynamic> data) {
    return Hotel(
      id: id,
      name: (data['name'] ?? '') as String,
      phoneNumber: (data['phoneNumber'] ?? '') as String,
      businessName: (data['businessName'] ?? '') as String,
      stationArea: (data['stationArea'] ?? '') as String,
      roomTypes: List<String>.from(data['roomTypes'] ?? const []),
      amenities: List<String>.from(data['amenities'] ?? const []),
      priceRangeMin: ((data['priceRangeMin'] ?? 0) as num).toDouble(),
      priceRangeMax: ((data['priceRangeMax'] ?? 0) as num).toDouble(),
      numberOfRooms: (data['numberOfRooms'] ?? 0) as int,
      checkInTime: (data['checkInTime'] ?? '') as String,
      checkOutTime: (data['checkOutTime'] ?? '') as String,
      offersFreeBreakfast: (data['offersFreeBreakfast'] ?? false) as bool,
      offersAirportPickup: (data['offersAirportPickup'] ?? false) as bool,
      acceptsWalkIns: (data['acceptsWalkIns'] ?? true) as bool,
      photoUrls: List<String>.from(data['photoUrls'] ?? const []),
      rating: ((data['rating'] ?? 0.0) as num).toDouble(),
      reviewCount: (data['reviewCount'] ?? 0) as int,
      isApproved: (data['isApproved'] ?? false) as bool,
      isPending: (data['isPending'] ?? true) as bool,
      ghanaCardNumber: (data['ghanaCardNumber'] ?? '') as String,
      ghanaCardPhotoUrl: data['ghanaCardPhotoUrl'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
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
      'rating': rating,
      'reviewCount': reviewCount,
      'isApproved': isApproved,
      'isPending': isPending,
      'ghanaCardNumber': ghanaCardNumber,
      'ghanaCardPhotoUrl': ghanaCardPhotoUrl,
    };
  }
}

/// Predefined room type chips for the add-hotel form. Kept as a plain
/// constant list (like electricianPropertyTypeOptions) rather than free
/// text, so listings stay filterable/consistent later.
const List<String> hotelRoomTypeOptions = [
  'Single',
  'Double',
  'Twin',
  'Suite',
  'Executive',
  'Family Room',
  'Deluxe',
];

const List<String> hotelAmenityOptions = [
  'WiFi',
  'Air Conditioning',
  'Generator / Backup Power',
  'Parking',
  'Swimming Pool',
  'Restaurant',
  'Bar',
  'CCTV / Security',
  'Laundry Service',
  'Airport Shuttle',
  'Conference / Event Hall',
  'TV',
  'Hot Water',
  'Gym',
];
