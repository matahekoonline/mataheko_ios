import '../models/listing.dart';

// PLACEHOLDER DATA — replace these with real vendors/artisans you collect
// on the ground in Mataheko-Afienya. Keep the same structure.
// dateAdded drives the "Latest Additions" section on the home screen —
// newest dateAdded shows first.
final List<Listing> sampleListings = [
  Listing(
    id: '1',
    name: 'Kofi Electricals',
    category: 'Electrician',
    description: 'Home wiring, repairs, and installations.',
    phone: '0244000001',
    locationText: 'Near Mataheko main road',
    dateAdded: DateTime(2026, 6, 20),
  ),
  Listing(
    id: '2',
    name: 'Ama\'s Chop Bar',
    category: 'Food',
    description: 'Local dishes, jollof, banku and soup daily.',
    phone: '0244000002',
    locationText: 'Afienya junction',
    dateAdded: DateTime(2026, 6, 22),
  ),
  Listing(
    id: '3',
    name: 'Yaw Plumbing Works',
    category: 'Plumber',
    description: 'Pipe fitting, leak repairs, tank installation.',
    phone: '0244000003',
    locationText: 'Mataheko Zongo area',
    dateAdded: DateTime(2026, 6, 18),
  ),
  Listing(
    id: '4',
    name: 'Efua Fashion House',
    category: 'Tailor',
    description: 'Custom dresses, school uniforms, alterations.',
    phone: '0244000004',
    locationText: 'Near Afienya market',
    dateAdded: DateTime(2026, 6, 25),
  ),
  Listing(
    id: '5',
    name: 'Mensah Auto Repairs',
    category: 'Mechanic',
    description: 'Car and motorbike repairs, all makes.',
    phone: '0244000005',
    locationText: 'Mataheko-Afienya road',
    dateAdded: DateTime(2026, 6, 15),
  ),
  Listing(
    id: '6',
    name: 'Kwame Okada Rides',
    category: 'Okada',
    description: 'Fast and reliable motorbike rides around town.',
    phone: '0244000006',
    locationText: 'Mataheko main stop',
    dateAdded: DateTime(2026, 6, 29),
    isFeatured: true,
  ),
  Listing(
    id: '7',
    name: 'Sunrise Guest House',
    category: 'Guest House',
    description: 'Clean, affordable rooms with fan or AC options.',
    phone: '0244000007',
    locationText: 'Afienya-Mataheko road',
    dateAdded: DateTime(2026, 6, 30),
    isFeatured: true,
  ),
  Listing(
    id: '8',
    name: 'Green Palm Hotel',
    category: 'Hotel',
    description: 'Comfortable rooms, restaurant, and event hall.',
    phone: '0244000008',
    locationText: 'Near Afienya junction',
    dateAdded: DateTime(2026, 6, 27),
  ),
  Listing(
    id: '9',
    name: 'Self-Contained Room, Mataheko',
    category: 'Room for Rent',
    description: 'One bedroom self-contained, water and light included.',
    phone: '0244000009',
    locationText: 'Mataheko Zongo',
    dateAdded: DateTime(2026, 7, 1),
    isFeatured: true,
  ),
  Listing(
    id: '10',
    name: 'Ohemaa Okada Station',
    category: 'Okada',
    description: 'Trusted riders, safe helmets provided.',
    phone: '0244000010',
    locationText: 'Afienya market entrance',
    dateAdded: DateTime(2026, 6, 24),
  ),
  Listing(
    id: '11',
    name: 'Chamber and Hall for Rent',
    category: 'Room for Rent',
    description: 'Newly built, tiled floors, close to the main road.',
    phone: '0244000011',
    locationText: 'Mataheko new site',
    dateAdded: DateTime(2026, 6, 28),
  ),
];

// Category list used for the home screen shortcuts and filtering, and
// (via BioDataScreen's category dropdown) which categories a new provider
// can register under.
//
// 'Teacher' was added here — BioDataScreen already had full registration
// logic for it (subjects, class levels, qualification) but it was missing
// from this list, so it was never actually selectable. 'Tiler' is new.
final List<String> categories = [
  'Aboboyaa',
  'Ride Along',
  'Electrician',
  'Plumber',
  'Food',
  'Tailor',
  'Mechanic',
  'Okada',
  'Steel Bender',
  'Hotel',
  'Guest House',
  'Room for Rent',
  'Carpenter',
  'Mason',
  'Welder',
  'Event Planners',
  'Sound System Rentals',
  'Teacher',
  'Tiler',
];

// Returns the most recently added listings, newest first
List<Listing> getLatestListings({int count = 8}) {
  final sorted = [...sampleListings]..sort((a, b) => b.dateAdded.compareTo(a.dateAdded)     );
                   return sorted.take(count).toList();
}

// ---------------------------------------------------------------------
// Tiler registration option lists (used by BioDataScreen's chip sections
// for the Tiler category, same pattern as garmentCategoryOptions /
// propertyTypeOptions / fixtureBrandOptions above).
// ---------------------------------------------------------------------

const List<String> tilerSpecialtyOptions = [
  'Floor Tiling',
  'Wall Tiling',
  'Bathroom Tiling',
  'Kitchen Tiling',
  'Outdoor / Patio Tiling',
  'Tile Repair',
  'Waterproofing',
];

const List<String> tilerMaterialOptions = [
  'Ceramic',
  'Porcelain',
  'Marble',
  'Granite',
  'Mosaic',
  'Terrazzo',
  'Natural Stone',
];

const List<String> tilerServiceOptions = [
  'Supply & Install',
  'Design Consultation',
  'Grouting',
  'Regrouting',
  'Tile Removal',
  'Waterproofing',
];