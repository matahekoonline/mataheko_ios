import 'package:flutter/material.dart';

/// What happens when a banner is tapped on the home screen.
enum BannerLinkType {
  none,
  category,
  listing,
  url;

  String get label {
    switch (this) {
      case BannerLinkType.none:
        return 'No action';
      case BannerLinkType.category:
        return 'Open category';
      case BannerLinkType.listing:
        return 'Open listing';
      case BannerLinkType.url:
        return 'Open link';
    }
  }
}

/// Curated icon set for text-design banners.
///
/// We deliberately store a String key (not IconData.codePoint) in Firestore.
/// Persisting raw codePoints breaks in release builds unless you disable
/// icon tree-shaking (--no-tree-shake-icons), because Flutter strips out
/// icons it can't prove are used. Keeping a fixed map here means every icon
/// is a real, statically-referenced Icons.xxx constant, so tree-shaking
/// leaves them all in — no special build flags needed.
class HeroBannerIcons {
  HeroBannerIcons._();

  static const Map<String, IconData> options = {
    'celebration': Icons.celebration,
    'storefront': Icons.storefront,
    'shopping_basket': Icons.shopping_basket,
    'build': Icons.build,
    'computer': Icons.computer,
    'campaign': Icons.campaign,
    'local_offer': Icons.local_offer,
    'star': Icons.star,
    'favorite': Icons.favorite,
    'restaurant': Icons.restaurant,
    'directions_car': Icons.directions_car,
    'home_work': Icons.home_work,
    'school': Icons.school,
    'spa': Icons.spa,
    'event': Icons.event,
    'volunteer_activism': Icons.volunteer_activism,
  };

  static IconData iconFor(String? key) => options[key] ?? Icons.campaign;

  static String keyFor(IconData icon) {
    for (final entry in options.entries) {
      if (entry.value == icon) return entry.key;
    }
    return 'campaign';
  }
}

class HeroBanner {
  final String id;
  final String title;
  final String subtitle;

  /// Null/empty => text-design banner (gradient + icon shown).
  /// Non-empty  => photo banner (image shown with BoxFit.cover + scrim).
  /// This single field is what HeroSection's `hasImage` check already
  /// branches on, so nothing downstream needed to change.
  final String? imageUrl;

  /// Only rendered when there's no photo.
  final List<Color> gradientColors;
  final String iconKey;
  final Color textColor;

  final bool active;
  final int order;

  final BannerLinkType linkType;
  final String? linkValue;

  const HeroBanner({
    required this.id,
    required this.title,
    required this.subtitle,
    this.imageUrl,
    this.gradientColors = const [Color(0xFF2E7D32), Color(0xFF66BB6A)],
    this.iconKey = 'campaign',
    this.textColor = Colors.white,
    this.active = true,
    this.order = 0,
    this.linkType = BannerLinkType.none,
    this.linkValue,
  });

  IconData get icon => HeroBannerIcons.iconFor(iconKey);
  bool get hasPhoto => imageUrl != null && imageUrl!.isNotEmpty;

  HeroBanner copyWith({
    String? id,
    String? title,
    String? subtitle,
    String? imageUrl,
    bool clearImageUrl = false,
    List<Color>? gradientColors,
    String? iconKey,
    Color? textColor,
    bool? active,
    int? order,
    BannerLinkType? linkType,
    String? linkValue,
    bool clearLinkValue = false,
  }) {
    return HeroBanner(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      imageUrl: clearImageUrl ? null : (imageUrl ?? this.imageUrl),
      gradientColors: gradientColors ?? this.gradientColors,
      iconKey: iconKey ?? this.iconKey,
      textColor: textColor ?? this.textColor,
      active: active ?? this.active,
      order: order ?? this.order,
      linkType: linkType ?? this.linkType,
      linkValue: clearLinkValue ? null : (linkValue ?? this.linkValue),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'subtitle': subtitle,
      'imageUrl': imageUrl,
      'gradientColors': gradientColors.map((c) => c.value).toList(),
      'iconKey': iconKey,
      'textColor': textColor.value,
      'active': active,
      'order': order,
      'linkType': linkType.name,
      'linkValue': linkValue,
    };
  }

  factory HeroBanner.fromMap(String id, Map<String, dynamic> map) {
    final rawGradient = (map['gradientColors'] as List?) ?? [];
    final gradientColors = rawGradient.isEmpty
        ? const [Color(0xFF2E7D32), Color(0xFF66BB6A)]
        : rawGradient.map((v) => Color(v as int)).toList();

    return HeroBanner(
      id: id,
      title: map['title'] as String? ?? '',
      subtitle: map['subtitle'] as String? ?? '',
      imageUrl: map['imageUrl'] as String?,
      gradientColors: gradientColors,
      iconKey: map['iconKey'] as String? ?? 'campaign',
      textColor: Color((map['textColor'] as int?) ?? Colors.white.value),
      active: map['active'] as bool? ?? true,
      order: (map['order'] as int?) ?? 0,
      linkType: BannerLinkType.values.firstWhere(
        (t) => t.name == (map['linkType'] as String? ?? 'none'),
        orElse: () => BannerLinkType.none,
      ),
      linkValue: map['linkValue'] as String?,
    );
  }
}
