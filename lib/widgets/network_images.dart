import 'package:flutter/material.dart';

/// Some image links come back from the upload server as plain http://.
/// iOS blocks cleartext loads (App Transport Security) so those images
/// silently fail to show there while still working on Android. Upgrading
/// to https fixes that without touching the stored data.
String secureUrl(String url) =>
    url.startsWith('http://') ? 'https://${url.substring(7)}' : url;

bool _hasUrl(String? url) => url != null && url.trim().isNotEmpty;

/// A team crest / logo, shown whole (never cropped) inside a square.
/// Falls back to a shield icon if there is no logo or it fails to load.
class TeamCrest extends StatelessWidget {
  final String? logoUrl;
  final double size;

  const TeamCrest({super.key, required this.logoUrl, this.size = 24});

  @override
  Widget build(BuildContext context) {
    final fallback = Icon(Icons.shield_outlined,
        size: size * 0.9, color: Colors.green[700]);
    return SizedBox(
      width: size,
      height: size,
      child: _hasUrl(logoUrl)
          ? Image.network(
              secureUrl(logoUrl!.trim()),
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => fallback,
              loadingBuilder: (context, child, progress) => progress == null
                  ? child
                  : Center(child: fallback),
            )
          : fallback,
    );
  }
}

/// A round player photo. Falls back to the player's initials.
class PlayerPhoto extends StatelessWidget {
  final String? photoUrl;
  final String name;
  final double radius;

  const PlayerPhoto({
    super.key,
    required this.photoUrl,
    required this.name,
    this.radius = 38,
  });

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    final list = parts.toList();
    final first = list.first[0];
    final last = list.length > 1 ? list.last[0] : '';
    return (first + last).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final fallback = Center(
      child: Text(
        _initials,
        style: TextStyle(
          fontSize: radius * 0.7,
          fontWeight: FontWeight.w800,
          color: Colors.green[800],
        ),
      ),
    );
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        color: Colors.green[50],
        shape: BoxShape.circle,
      ),
      clipBehavior: Clip.antiAlias,
      child: _hasUrl(photoUrl)
          ? Image.network(
              secureUrl(photoUrl!.trim()),
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              errorBuilder: (_, __, ___) => fallback,
              loadingBuilder: (context, child, progress) =>
                  progress == null ? child : fallback,
            )
          : fallback,
    );
  }
}
