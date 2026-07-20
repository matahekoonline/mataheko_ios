import 'package:cloud_firestore/cloud_firestore.dart';

/// A service category shown in the home screen grid. Collection: `categories`.
class Category {
  final String id;
  final String name;

  /// URL of the admin-uploaded PNG icon (ideally transparent, "3D"-style).
  /// Null/empty falls back to a generic Icons.category glyph in the badge.
  final String? iconUrl;

  final bool active;
  final int order;

  const Category({
    required this.id,
    required this.name,
    this.iconUrl,
    this.active = true,
    this.order = 0,
  });

  bool get hasIcon => iconUrl != null && iconUrl!.isNotEmpty;

  Category copyWith({
    String? id,
    String? name,
    String? iconUrl,
    bool clearIconUrl = false,
    bool? active,
    int? order,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      iconUrl: clearIconUrl ? null : (iconUrl ?? this.iconUrl),
      active: active ?? this.active,
      order: order ?? this.order,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'iconUrl': iconUrl,
      'active': active,
      'order': order,
    };
  }

  factory Category.fromMap(String id, Map<String, dynamic> map) {
    return Category(
      id: id,
      name: map['name'] as String? ?? '',
      iconUrl: map['iconUrl'] as String?,
      active: map['active'] as bool? ?? true,
      order: (map['order'] as int?) ?? 0,
    );
  }
}