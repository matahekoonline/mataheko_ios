import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/teacher.dart';
import '../widgets/rating_display.dart';

class TeacherDetailScreen extends StatelessWidget {
  final Teacher teacher;
  const TeacherDetailScreen({super.key, required this.teacher});

  Future<void> _callNumber(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _whatsApp(String phone) async {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    final formatted = digits.startsWith('0') ? '233${digits.substring(1)}' : digits;
    final uri = Uri.parse('https://wa.me/$formatted');
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(teacher.name)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.green[100],
                  backgroundImage: (teacher.photoUrl != null && teacher.photoUrl!.isNotEmpty)
                      ? NetworkImage(teacher.photoUrl!)
                      : null,
                  child: (teacher.photoUrl == null || teacher.photoUrl!.isEmpty)
                      ? Icon(Icons.school, color: Colors.green[800], size: 32)
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        teacher.name,
                        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                      ),
                      Text(teacher.qualification, style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                      const SizedBox(height: 6),
                      RatingDisplay(rating: teacher.rating, reviewCount: teacher.reviewCount),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.verified, size: 16, color: Colors.green[700]),
                const SizedBox(width: 4),
                Text('ID Verified', style: TextStyle(fontSize: 12, color: Colors.green[700], fontWeight: FontWeight.w600)),
                const SizedBox(width: 16),
                Icon(Icons.location_on_outlined, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(teacher.stationArea, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),

            const SizedBox(height: 24),
            _SectionCard(
              title: 'Experience',
              child: Row(
                children: [
                  Icon(Icons.work_history_outlined, color: Colors.green[700], size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${teacher.yearsOfExperience} years teaching\n${teacher.schoolOrInstitution}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            _SectionCard(
              title: 'Class Levels Taught',
              child: teacher.classLevelsTaught.isEmpty
                  ? const Text('Not specified', style: TextStyle(color: Colors.grey))
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: teacher.classLevelsTaught
                          .map((c) => Chip(
                                label: Text(c, style: const TextStyle(fontSize: 12)),
                                backgroundColor: Colors.blue[50],
                                side: BorderSide(color: Colors.blue[200]!),
                              ))
                          .toList(),
                    ),
            ),

            const SizedBox(height: 16),
            _SectionCard(
              title: 'Subjects Taught',
              child: teacher.subjectsTaught.isEmpty
                  ? const Text('Not specified', style: TextStyle(color: Colors.grey))
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: teacher.subjectsTaught
                          .map((s) => Chip(
                                label: Text(s, style: const TextStyle(fontSize: 12)),
                                backgroundColor: Colors.green[50],
                                side: BorderSide(color: Colors.green[200]!),
                              ))
                          .toList(),
                    ),
            ),

            if (teacher.offersHomeTutoring || teacher.offersOnlineTutoring) ...[
              const SizedBox(height: 16),
              _SectionCard(
                title: 'Tutoring Options',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (teacher.offersHomeTutoring)
                      Chip(
                        avatar: Icon(Icons.home, size: 14, color: Colors.orange[800]),
                        label: const Text('Home Tutoring', style: TextStyle(fontSize: 12)),
                        backgroundColor: Colors.orange[50],
                      ),
                    if (teacher.offersOnlineTutoring)
                      Chip(
                        avatar: Icon(Icons.laptop, size: 14, color: Colors.purple[800]),
                        label: const Text('Online Tutoring', style: TextStyle(fontSize: 12)),
                        backgroundColor: Colors.purple[50],
                      ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _callNumber(teacher.phoneNumber),
                    icon: const Icon(Icons.call),
                    label: const Text('Call'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: Colors.green[700],
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _whatsApp(teacher.phoneNumber),
                    icon: const Icon(Icons.chat),
                    label: const Text('WhatsApp'),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey[800])),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
