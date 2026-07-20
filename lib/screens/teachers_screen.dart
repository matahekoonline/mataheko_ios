import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/teacher.dart';
import '../services/auth_service.dart';
import '../widgets/rating_display.dart';
import 'admin/add_teacher_screen.dart';
import 'teacher_detail_screen.dart';

class TeachersScreen extends StatefulWidget {
  const TeachersScreen({super.key});

  @override
  State<TeachersScreen> createState() => _TeachersScreenState();
}

class _TeachersScreenState extends State<TeachersScreen> {
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadAdminStatus();
  }

  Future<void> _loadAdminStatus() async {
    final isAdmin = await AuthService.instance.isAdmin();
    if (mounted) setState(() => _isAdmin = isAdmin);
  }

  Future<void> _approve(Teacher teacher) async {
    try {
      await AuthService.instance.approveTeacher(teacher.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${teacher.name} approved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not approve. Try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Teachers')),
      floatingActionButton: _isAdmin
          ? FloatingActionButton.extended(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddTeacherScreen()),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Teacher'),
              backgroundColor: Colors.green[700],
            )
          : null,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('teachers')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            // ignore: avoid_print
            print('[TeachersScreen] Stream error: ${snapshot.error}');
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Error loading teachers:\n${snapshot.error}', textAlign: TextAlign.center),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];
          var teachers = <Teacher>[];
          for (final d in docs) {
            try {
              teachers.add(Teacher.fromMap(d.id, d.data() as Map<String, dynamic>));
            } catch (e) {
              // ignore: avoid_print
              print('[TeachersScreen] Skipping bad doc ${d.id}: $e');
            }
          }

          if (!_isAdmin) {
            teachers = teachers.where((t) => t.isApproved).toList();
          }

          if (teachers.isEmpty) {
            return const Center(child: Text('No teachers added yet.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: teachers.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final t = teachers[index];
              return Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => TeacherDetailScreen(teacher: t)),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.green[100],
                          backgroundImage: (t.photoUrl != null && t.photoUrl!.isNotEmpty)
                              ? NetworkImage(t.photoUrl!)
                              : null,
                          child: (t.photoUrl == null || t.photoUrl!.isEmpty)
                              ? Icon(Icons.school, color: Colors.green[800])
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      t.name,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (t.isPending) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.orange[100],
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text('Pending',
                                          style: TextStyle(fontSize: 11, color: Colors.orange[900])),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${t.stationArea} · ${t.yearsOfExperience} yrs · ${t.qualification}',
                                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              if (t.subjectsTaught.isNotEmpty)
                                Wrap(
                                  spacing: 4,
                                  runSpacing: 4,
                                  children: t.subjectsTaught.take(3).map((s) {
                                    return Chip(
                                      label: Text(s, style: const TextStyle(fontSize: 10)),
                                      padding: EdgeInsets.zero,
                                      labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                                      backgroundColor: Colors.green[50],
                                      visualDensity: VisualDensity.compact,
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    );
                                  }).toList(),
                                ),
                              const SizedBox(height: 6),
                              RatingDisplay(rating: t.rating, reviewCount: t.reviewCount, starSize: 14),
                            ],
                          ),
                        ),
                        if (_isAdmin && t.isPending)
                          TextButton(
                            onPressed: () => _approve(t),
                            child: const Text('Approve'),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
