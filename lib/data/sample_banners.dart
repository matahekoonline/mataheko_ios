import 'package:flutter/material.dart';
import '../models/hero_banner.dart';

// PLACEHOLDER BANNERS — replace title/subtitle/colors with your real
// adverts, announcements, or promoted listings. Add or remove as needed.
// These are all text-design banners (no imageUrl); the admin can now also
// create photo banners directly from the Manage Hero Banners screen.
final List<HeroBanner> sampleBanners = [
  const HeroBanner(
    id: 'b1',
    title: 'Welcome to Mataheko-Afienya',
    subtitle: 'Your community, all in one app',
    gradientColors: [Color(0xFF2E7D32), Color(0xFF66BB6A)],
    iconKey: 'celebration',
  ),
  const HeroBanner(
    id: 'b2',
    title: 'Post Your Business Free',
    subtitle: 'Get discovered by your neighbours today',
    gradientColors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
    iconKey: 'storefront',
  ),
  const HeroBanner(
    id: 'b3',
    title: 'Weekend Market Special',
    subtitle: 'Fresh produce at Afienya market this Saturday',
    gradientColors: [Color(0xFFEF6C00), Color(0xFFFFB74D)],
    iconKey: 'shopping_basket',
  ),
  const HeroBanner(
    id: 'b4',
    title: 'Need a Quick Fix?',
    subtitle: 'Browse trusted local artisans near you',
    gradientColors: [Color(0xFF6A1B9A), Color(0xFFAB47BC)],
    iconKey: 'build',
  ),
  const HeroBanner(
    id: 'b5',
    title: 'ELIHAN IT Solution',
    subtitle: 'Apps, websites & computer repairs — call 0597555882, Mataheko',
    gradientColors: [Color(0xFF00695C), Color(0xFF26A69A)],
    iconKey: 'computer',
  ),
];
