import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mataheko/screens/tilers_screen.dart';
import 'package:mataheko/screens/welders_screen.dart';
import '../data/sample_listings.dart';
import '../models/listing.dart';
import '../models/hero_banner.dart';
import '../models/hero_banner_settings.dart';
import '../widgets/hero_section.dart';
import '../services/auth_service.dart';
import '../services/hero_banner_service.dart';
import '../services/listing_service.dart';
import 'directory_list_screen.dart';
import 'listing_detail_screen.dart';
import 'okada_riders_screen.dart';
import 'mechanics_screen.dart';
import 'steel_benders_screen.dart';
import 'electricians_screen.dart';
import 'tailors_screen.dart';
import 'plumbers_screen.dart';
import 'carpenters_screen.dart';
import 'masons_screen.dart';
import 'teachers_screen.dart';
import 'home_cooks_screen.dart';
import 'hotels_screen.dart';
import 'aboboyaa_screen.dart';
import 'admin_dashboard_screen.dart';
import '../models/category.dart';
import '../services/category_service.dart';
import '../widgets/login_sheet.dart';
import 'ride_along_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  // ---------------------------------------------------------------------
  // Design tokens — kept local to this screen for now. If you like this
  // palette, pull these into a shared theme/constants file so every screen
  // uses the same values instead of copy-pasting hex codes.
  // ---------------------------------------------------------------------
  static const _palmGreen = Color(0xFF1F6F4A);
  static const _palmGreenDark = Color(0xFF155336);
  static const _adinkraGold = Color(0xFFE3A857);

// Add this import near the top of home_screen.dart, with the other screen imports:

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        centerTitle: false,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_palmGreenDark, _palmGreen],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: const Text(
          'Mataheko-Afienya',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 19,
            letterSpacing: 0.2,
            color: Colors.white,
          ),
        ),
        actions: [
          // Sign-in / account icon — person-outline to sign in when
          // logged out, filled account icon (tap for a sign-out sheet)
          // once logged in.
          StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, authSnapshot) {
              final user = authSnapshot.data;
              if (user == null) {
                return IconButton(
                  icon: const Icon(Icons.person_outline, color: Colors.white),
                  tooltip: 'Sign in',
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => const LoginSheet(),
                    );
                  },
                );
              }
              return IconButton(
                icon: const Icon(Icons.account_circle, color: Colors.white),
                tooltip: user.email ?? 'Account',
                onPressed: () => showModalBottomSheet(
                  context: context,
                  builder: (_) => SafeArea(
                    child: Wrap(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.logout),
                          title: const Text('Sign out'),
                          onTap: () async {
                            Navigator.pop(context);
                            await AuthService.instance.signOut();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          // Only visible for users with isAdmin: true in Firestore —
          // reacts live to sign-in/sign-out via authStateChanges.
          StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, authSnapshot) {
              if (!authSnapshot.hasData) return const SizedBox.shrink();
              return FutureBuilder<bool>(
                future: AuthService.instance.isAdmin(),
                builder: (context, adminSnapshot) {
                  if (adminSnapshot.data != true) return const SizedBox.shrink();
                  return IconButton(
                    icon: const Icon(Icons.admin_panel_settings_outlined, color: Colors.white),
                    tooltip: 'Admin Dashboard',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
                      );
                    },
                  );
                },
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero section — adverts, announcements, promoted info.
            // Live from Firestore (via HeroBannerService) so anything
            // added/edited in the admin banner screen shows up here
            // immediately — this used to be the static sampleBanners list.
            // Kept OUTSIDE the padded column below so it spans the full
            // device width with no side margins.
            StreamBuilder<List<HeroBanner>>(
              stream: HeroBannerService.instance.activeBannersStream(),
              builder: (context, bannerSnapshot) {
                if (bannerSnapshot.hasError) {
                  // Surface the real Firestore error in debug console
                  // instead of the hero section just silently going blank.
                  debugPrint('Hero banners stream error: ${bannerSnapshot.error}');
                }
                final banners = bannerSnapshot.data ?? const <HeroBanner>[];
                return StreamBuilder<HeroBannerSettings>(
                  stream: HeroBannerService.instance.settingsStream(),
                  builder: (context, settingsSnapshot) {
                    final settings = settingsSnapshot.data ??
                        const HeroBannerSettings();
                    return HeroSection(
                      banners: banners,
                      autoPlayInterval:
                          Duration(seconds: settings.slideIntervalSeconds),
                      transitionDuration: Duration(
                        milliseconds:
                            settings.transitionDurationMilliseconds,
                      ),
                      onBannerTap: (banner) =>
                          _handleBannerTap(context, banner),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 20),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search bar (visual only for now — wire up later)
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Search for a service...',
                      hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
                      prefixIcon: Icon(Icons.search, color: _palmGreen),
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: _palmGreen, width: 1.4),
                      ),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const DirectoryListScreen(category: null),
                        ),
                      );
                    },
                    readOnly: true,
                  ),
                  const SizedBox(height: 22),

                  Text(
                    'Categories',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.1,
                      color: Colors.grey[900],
                    ),
                  ),
                  const SizedBox(height: 12),
                  StreamBuilder<List<Category>>(
                    stream: CategoryService.instance.activeCategoriesStream(),
                    builder: (context, categorySnapshot) {
                      if (categorySnapshot.hasError) {
                        debugPrint('Categories stream error: ${categorySnapshot.error}');

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                            'Category error:\n${categorySnapshot.error}',
                            style: const TextStyle(color: Colors.red),
                          ),
                        );
                      }
                      final liveCategories = categorySnapshot.data ?? const <Category>[];
                      if (categorySnapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      if (liveCategories.isEmpty) {
                        return const Text('No categories yet.');
                      }
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 0.72,
                        ),
                        itemCount: liveCategories.length,
                        itemBuilder: (context, index) {
                          return _CategoryCard(category: liveCategories[index]);
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 28),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Latest Additions',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.1,
                          color: Colors.grey[900],
                        ),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(foregroundColor: _palmGreen),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const DirectoryListScreen(category: null),
                            ),
                          );
                        },
                        child: const Text('See all', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  StreamBuilder<List<Listing>>(
                    stream: ListingService.instance.latestListingsStream(count: 8),
                    builder: (context, latestSnapshot) {
                      if (latestSnapshot.hasError) {
                        debugPrint('Latest listings stream error: ${latestSnapshot.error}');
                      }
                      if (latestSnapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final latest = latestSnapshot.data ?? const <Listing>[];
                      return _LatestAdditionsRow(listings: latest);
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Routes a banner tap based on its linkType/linkValue, same idea as the
/// category grid's onTap. Shared with _CategoryCard via _navigateToCategory
/// so a category-linked banner opens the same screen the grid tile would.
void _handleBannerTap(BuildContext context, HeroBanner banner) {
  switch (banner.linkType) {
    case BannerLinkType.category:
      final category = banner.linkValue;
      if (category != null && category.isNotEmpty) {
        _navigateToCategory(context, category);
      }
      break;
    case BannerLinkType.listing:
      final listingId = banner.linkValue;
      if (listingId == null) return;
      Listing? match;
      try {
        match = sampleListings.firstWhere((l) => l.id == listingId);
      } catch (_) {
        match = null;
      }
      if (match != null) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ListingDetailScreen(listing: match!)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('That listing could not be found.')),
        );
      }
      break;
    case BannerLinkType.url:
    // TODO: wire up url_launcher if/when it's added to pubspec.yaml.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link banners aren\'t supported yet.')),
      );
      break;
    case BannerLinkType.none:
      break;
  }
}


/// Matches loosely (case-insensitive, singular/plural tolerant) since
/// category names now come from Firestore and are typed freely by admins
/// when adding a category — e.g. "mechanics", "Mechanic", "MECHANIC" all
/// need to route to the same screen.
void _navigateToCategory(BuildContext context, String category) {
  final normalized = category.trim().toLowerCase();

  bool matches(String key) {
    // Matches exact, plural (+s), or singular (-s) forms.
    return normalized == key ||
        normalized == '${key}s' ||
        (key.endsWith('s') &&
            normalized == key.substring(0, key.length - 1));
  }

  if (matches('okada') || matches('okada rider')) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const OkadaRidersScreen(),
      ),
    );
  } else if (matches('mechanic')) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const MechanicsScreen(),
      ),
    );
  } else if (matches('electrician')) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ElectriciansScreen(),
      ),
    );
  } else if (matches('steel bender')) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const SteelBendersScreen(),
      ),
    );
  } else if (matches('tailor')) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const TailorsScreen(),
      ),
    );
  } else if (matches('plumber')) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const PlumbersScreen(),
      ),
    );
  } else if (matches('carpenter')) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CarpentersScreen(),
      ),
    );
  } else if (matches('mason')) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const MasonsScreen(),
      ),
    );
  } else if (matches('teacher')) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const TeachersScreen(),
      ),
    );
  } else if (matches('home food delivery') ||
      matches('home food') ||
      matches('home cook') ||
      matches('food delivery')) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const HomeCooksScreen(),
      ),
    );
  } else if (matches('welder')) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const WeldersScreen(),
      ),
    );
  } else if (matches('tiler')) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const TilersScreen(),
      ),
    );
  } else if (matches('hotel') ||
      matches('guest house') ||
      matches('guesthouse')) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const HotelsScreen(),
      ),
    );
  } else if (matches('aboboyaa') ||
      matches('aboboyaa operator') ||
      matches('aboboyaa operators') ||
      normalized == 'aboboyaa services' ||
      normalized == 'aboboyaa service') {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AboboyaaScreen(),
      ),
    );
  } else if (matches('ride along') ||
      normalized == 'ride alongs' ||
      normalized == 'rideshare' ||
      normalized == 'ride share' ||
      normalized == 'carpool' ||
      normalized == 'car pool') {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const RideAlongScreen(),
      ),
    );
  } else {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DirectoryListScreen(
          category: category,
        ),
      ),
    );
  }
}

class _StatsStrip extends StatelessWidget {
  final int totalListings;
  final int totalCategories;
  const _StatsStrip({required this.totalListings, required this.totalCategories});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[700]!, Colors.blue[500]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(icon: Icons.storefront, value: '$totalListings+', label: 'Listings'),
          _verticalDivider(),
          _StatItem(icon: Icons.category, value: '$totalCategories', label: 'Categories'),
          _verticalDivider(),
          const _StatItem(icon: Icons.groups, value: '1', label: 'Community'),
        ],
      ),
    );
  }

  Widget _verticalDivider() => Container(
    width: 1,
    height: 34,
    color: Colors.white.withOpacity(0.3),
  );
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _StatItem({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
        ),
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 11),
        ),
      ],
    );
  }
}

/// Full-bleed category tile — the photo itself already has the category
/// name baked in (like the reference slot-game cards), so this just shows
/// the image edge-to-edge with rounded corners. No text overlay.
class _CategoryCard extends StatelessWidget {
  final Category category;
  const _CategoryCard({required this.category});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _navigateToCategory(context, category.name),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (category.hasIcon)
              Image.network(
                category.iconUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: HomeScreen._palmGreen,
                  child: const Icon(Icons.category, color: Colors.white, size: 32),
                ),
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    color: HomeScreen._palmGreen.withOpacity(0.15),
                    child: const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: HomeScreen._palmGreen),
                      ),
                    ),
                  );
                },
              )
            else
              Container(
                color: HomeScreen._palmGreen,
                child: const Icon(Icons.category, color: Colors.white, size: 32),
              ),

            // Thin border so cards separate cleanly on light backgrounds.
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.black.withOpacity(0.06)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LatestAdditionsRow extends StatelessWidget {
  final List<Listing> listings;
  const _LatestAdditionsRow({required this.listings});

  @override
  Widget build(BuildContext context) {
    if (listings.isEmpty) {
      return const Text('No listings yet.');
    }
    return SizedBox(
      height: 160,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: listings.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final listing = listings[index];
          final isNew = DateTime.now().difference(listing.dateAdded).inDays <= 3;
          return InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ListingDetailScreen(listing: listing)),
              );
            },
            child: Container(
              width: 150,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6, offset: const Offset(0, 3)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: HomeScreen._palmGreen.withOpacity(0.12),
                        child: Text(
                          listing.name.isNotEmpty ? listing.name[0] : '?',
                          style: const TextStyle(color: HomeScreen._palmGreenDark, fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (isNew)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: HomeScreen._adinkraGold.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'NEW',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF8A5A17),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    listing.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    listing.category,
                    style: const TextStyle(fontSize: 10, color: HomeScreen._palmGreenDark, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 10, color: Colors.grey),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          listing.locationText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 9, color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}