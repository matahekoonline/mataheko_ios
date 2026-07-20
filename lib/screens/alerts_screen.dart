import 'package:flutter/material.dart';
import '../data/sample_alerts.dart';

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Community Alerts'),
        centerTitle: true,
      ),
      body: sampleAlerts.isEmpty
          ? const Center(child: Text('No alerts right now.'))
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: sampleAlerts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final alert = sampleAlerts[index];
                return Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    leading: CircleAvatar(
                      backgroundColor: alert.color.withOpacity(0.15),
                      child: Icon(alert.icon, color: alert.color),
                    ),
                    title: Text(
                      alert.title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(alert.description),
                    ),
                    trailing: Text(
                      alert.timeAgo,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
