import 'package:flutter/material.dart';
import 'okada_riders_screen.dart';
import 'verify_providers_screen.dart';
import 'mechanics_screen.dart';
import 'plumbers_screen.dart';
import 'tailors_screen.dart';
import 'tilers_screen.dart';
import 'home_cooks_screen.dart';
import 'welders_screen.dart';
import 'steel_benders_screen.dart';
import 'electricians_screen.dart';
import 'carpenters_screen.dart';
import 'teachers_screen.dart';
import 'verify_marketplace_screen.dart';
import 'manage_hero_banners_screen.dart';
import 'manage_providers_screen.dart';
import 'manage_media_screen.dart';
import 'manage_sports_screen.dart';
import 'admin/manage_categories_screen.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Dashboard'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _AdminTile(
            icon: Icons.manage_accounts_outlined,
            title: 'All Providers',
            subtitle: 'View, edit, or delete any provider across every category',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ManageProvidersScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _AdminTile(
            icon: Icons.two_wheeler,
            title: 'Okada Riders',
            subtitle: 'Add or view registered riders',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const OkadaRidersScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _AdminTile(
            icon: Icons.build,
            title: 'Mechanics',
            subtitle: 'Add or view registered mechanics',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MechanicsScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _AdminTile(
            icon: Icons.electrical_services,
            title: 'Electricians',
            subtitle: 'Add or view registered electricians',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ElectriciansScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _AdminTile(
            icon: Icons.carpenter,
            title: 'Carpenters',
            subtitle: 'Add or view registered carpenters',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CarpentersScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _AdminTile(
            icon: Icons.construction,
            title: 'Steel Benders',
            subtitle: 'Add or view registered steel benders',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SteelBendersScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _AdminTile(
            icon: Icons.plumbing,
            title: 'Plumbers',
            subtitle: 'Approve pending plumbers, view registered ones',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PlumbersScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _AdminTile(
            icon: Icons.checkroom,
            title: 'Tailors',
            subtitle: 'Approve pending tailors, view registered ones',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TailorsScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _AdminTile(
            icon: Icons.grid_on,
            title: 'Tilers',
            subtitle: 'Approve pending tilers, view registered ones',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TilersScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _AdminTile(
            icon: Icons.restaurant_outlined,
            title: 'Home Food Delivery',
            subtitle: 'Approve pending home cooks, view registered ones',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HomeCooksScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _AdminTile(
            icon: Icons.local_fire_department_outlined,
            title: 'Welders',
            subtitle: 'Approve pending welders, view registered ones',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const WeldersScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _AdminTile(
            icon: Icons.school,
            title: 'Teachers',
            subtitle: 'Approve pending teachers, view registered ones',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TeachersScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _AdminTile(
            icon: Icons.verified_user_outlined,
            title: 'Verify Providers',
            subtitle: 'Review pending Ghana Card submissions',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const VerifyProvidersScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _AdminTile(
            icon: Icons.storefront_outlined,
            title: 'Verify Marketplace Items',
            subtitle: 'Approve or reject pending listings',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const VerifyMarketplaceScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _AdminTile(
            icon: Icons.view_carousel_outlined,
            title: 'Hero Banners',
            subtitle: 'Upload photos or design text banners for the home screen',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ManageHeroBannersScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _AdminTile(
            icon: Icons.category_outlined,
            title: 'Categories',
            subtitle: 'Add, reorder, or hide home screen categories',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ManageCategoriesScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _AdminTile(
            icon: Icons.perm_media_outlined,
            title: 'Local Talent',
            subtitle: 'Add YouTube videos or Spotify/MP3 audio links',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ManageMediaScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _AdminTile(
            icon: Icons.sports_soccer,
            title: 'Sports',
            subtitle: 'League name, teams, players, fixtures & scores',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ManageSportsScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _AdminTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: Colors.green[100],
          child: Icon(icon, color: Colors.green[700]),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}