import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/community_alert_service.dart';

class ManageCommunityAlertsScreen extends StatefulWidget {
  const ManageCommunityAlertsScreen({super.key});

  @override
  State<ManageCommunityAlertsScreen> createState() => _ManageCommunityAlertsScreenState();
}

class _ManageCommunityAlertsScreenState extends State<ManageCommunityAlertsScreen> {
  final _service = CommunityAlertService.instance;

  Future<void> _edit({DocumentSnapshot<Map<String, dynamic>>? doc}) async {
    final d = doc?.data() ?? {};
    final title = TextEditingController(text: d['title']?.toString() ?? '');
    final description = TextEditingController(text: d['description']?.toString() ?? '');
    final location = TextEditingController(text: d['location']?.toString() ?? '');
    final source = TextEditingController(text: d['source']?.toString() ?? '');
    String type = d['type']?.toString() ?? 'General';
    bool active = d['active'] != false;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDialog) => AlertDialog(
        title: Text(doc == null ? 'Create Community Alert' : 'Edit Community Alert'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: title, decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: description, maxLines: 4, decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(value: type, decoration: const InputDecoration(labelText: 'Alert type', border: OutlineInputBorder()), items: const ['General','Power','Water','Traffic','Safety','Weather','Event','Lost Item'].map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(), onChanged: (v) => setDialog(() => type = v ?? 'General')),
          const SizedBox(height: 10),
          TextField(controller: location, decoration: const InputDecoration(labelText: 'Location / area', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: source, decoration: const InputDecoration(labelText: 'Source / agency', border: OutlineInputBorder())),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Visible to community'), value: active, onChanged: (v) => setDialog(() => active = v)),
        ])),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save'))],
      )),
    );
    if (ok != true) return;
    if (title.text.trim().isEmpty || description.text.trim().isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Title and description are required.')));
      return;
    }
    try {
      if (doc == null) {
        await _service.createAlert(title: title.text, description: description.text, type: type, location: location.text, source: source.text);
      } else {
        await _service.updateAlert(id: doc.id, title: title.text, description: description.text, type: type, location: location.text, source: source.text, active: active);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save alert: $e')));
    }
  }

  Future<void> _delete(String id) async {
    final yes = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Delete alert?'), content: const Text('This alert will be removed permanently.'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete'))]));
    if (yes != true) return;
    try { await _service.deleteAlert(id); } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not delete alert: $e'))); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Community Alerts')),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _edit(), icon: const Icon(Icons.add_alert), label: const Text('New Alert')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _service.streamAllAlerts(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Could not load alerts: ${snapshot.error}'));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) return const Center(child: Text('No community alerts created yet.'));
          return ListView.separated(
            padding: const EdgeInsets.all(16), itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final d = docs[i]; final x = d.data(); final active = x['active'] != false;
              return Card(child: ListTile(
                leading: Icon(active ? Icons.notifications_active : Icons.notifications_off, color: active ? Colors.green : Colors.grey),
                title: Text('${x['title'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('${x['type'] ?? 'General'} • ${x['location'] ?? ''}\n${x['description'] ?? ''}', maxLines: 3, overflow: TextOverflow.ellipsis),
                isThreeLine: true,
                trailing: PopupMenuButton<String>(onSelected: (v) { if (v == 'edit') _edit(doc: d); if (v == 'delete') _delete(d.id); if (v == 'toggle') _service.setActive(d.id, !active); }, itemBuilder: (_) => [const PopupMenuItem(value: 'edit', child: Text('Edit')), PopupMenuItem(value: 'toggle', child: Text(active ? 'Hide' : 'Publish')), const PopupMenuItem(value: 'delete', child: Text('Delete'))]),
              ));
            },
          );
        },
      ),
    );
  }
}
