import 'package:flutter/material.dart';
import '../models/community_alert.dart';

// PLACEHOLDER DATA — replace with real ECG/GWCL outage notices and
// community announcements as they come in.
final List<CommunityAlert> sampleAlerts = [
  const CommunityAlert(
    id: 'a1',
    title: 'Power Outage Notice',
    description: 'ECG maintenance work in Mataheko area, 8am - 4pm.',
    timeAgo: '2h ago',
    icon: Icons.bolt,
    color: Colors.orange,
  ),
  const CommunityAlert(
    id: 'a2',
    title: 'Water Supply Interruption',
    description: 'GWCL pipeline repair affecting Afienya, expect low pressure.',
    timeAgo: '5h ago',
    icon: Icons.water_drop,
    color: Colors.blue,
  ),
  const CommunityAlert(
    id: 'a3',
    title: 'Community Town Hall',
    description: 'Assembly meeting this Sunday at the community center, 4pm.',
    timeAgo: '1d ago',
    icon: Icons.groups,
    color: Colors.purple,
  ),
  const CommunityAlert(
    id: 'a4',
    title: 'Lost Item Reported',
    description: 'A brown goat was found near the market. Contact the chief\'s palace.',
    timeAgo: '2d ago',
    icon: Icons.pets,
    color: Colors.brown,
  ),
];
