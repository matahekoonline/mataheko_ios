import 'package:flutter/material.dart';

class CommunityAlert {
  final String id;
  final String title;
  final String description;
  final String timeAgo;
  final IconData icon;
  final Color color;

  const CommunityAlert({
    required this.id,
    required this.title,
    required this.description,
    required this.timeAgo,
    required this.icon,
    required this.color,
  });
}
