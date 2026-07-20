import 'package:flutter/material.dart';
import '../models/carpenter.dart';

class CarpenterDetailScreen extends StatelessWidget {
  final Carpenter carpenter;
  const CarpenterDetailScreen({super.key, required this.carpenter});

  @override
  Widget build(BuildContext context) {
    final hasImage = carpenter.photoUrl != null && carpenter.photoUrl!.isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: Text(carpenter.fullName), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: CircleAvatar(
              radius: 50,
              backgroundColor: Colors.green[100],
              backgroundImage: hasImage ? NetworkImage(carpenter.photoUrl!) : null,
              child: hasImage ? null : Icon(Icons.carpenter, size: 40, color: Colors.green[800]),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              carpenter.fullName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ),
          Center(
            child: Text(
              carpenter.workshopName,
              style: TextStyle(color: Colors.grey[700]),
            ),
          ),
          const SizedBox(height: 24),
          _InfoRow(icon: Icons.location_on, label: 'Area', value: carpenter.stationArea),
          _InfoRow(icon: Icons.phone, label: 'Phone', value: carpenter.phoneNumber),
          _InfoRow(
            icon: Icons.work_history,
            label: 'Experience',
            value: '${carpenter.yearsOfExperience} years',
          ),
          if (carpenter.offersOnSiteService)
            _InfoRow(icon: Icons.home_repair_service, label: 'On-site', value: 'Available for on-site work'),
          const SizedBox(height: 16),
          if (carpenter.specialties.isNotEmpty) _TagSection('Specialties', carpenter.specialties),
          if (carpenter.materialsWorkedWith.isNotEmpty)
            _TagSection('Materials Worked With', carpenter.materialsWorkedWith),
          if (carpenter.servicesOffered.isNotEmpty)
            _TagSection('Services Offered', carpenter.servicesOffered),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.green[700]),
          const SizedBox(width: 10),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _TagSection extends StatelessWidget {
  final String title;
  final List<String> tags;
  const _TagSection(this.title, this.tags);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tags
                .map((t) => Chip(
                      label: Text(t, style: const TextStyle(fontSize: 12)),
                      backgroundColor: Colors.green[50],
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}
