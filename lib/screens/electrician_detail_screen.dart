import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/electrician.dart';
import '../models/review.dart';
import '../services/auth_service.dart';
import '../widgets/rating_display.dart';

class ElectricianDetailScreen extends StatefulWidget {
  final Electrician electrician;
  const ElectricianDetailScreen({super.key, required this.electrician});

  @override
  State<ElectricianDetailScreen> createState() => _ElectricianDetailScreenState();
}

class _ElectricianDetailScreenState extends State<ElectricianDetailScreen> {
  // Local copy so the header's rating/review count can bump instantly the
  // moment a review is submitted, without waiting on a full doc re-fetch
  // (the electricians list screen still gets the authoritative value from
  // its own StreamBuilder next time it rebuilds).
  late double _rating;
  late int _reviewCount;

  @override
  void initState() {
    super.initState();
    _rating = widget.electrician.rating;
    _reviewCount = widget.electrician.reviewCount;
  }

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

  Future<void> _openReviewSheet() async {
    final nameController = TextEditingController();
    final commentController = TextEditingController();
    double selectedRating = 5;
    bool submitting = false;
    String? error;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Leave a Review', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (i) {
                        final starValue = i + 1;
                        return IconButton(
                          onPressed: () => setSheetState(() => selectedRating = starValue.toDouble()),
                          icon: Icon(
                            starValue <= selectedRating ? Icons.star : Icons.star_border,
                            color: Colors.amber[700],
                            size: 30,
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Your Name (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: commentController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Comment (optional)',
                      hintText: 'How was the work?',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: submitting
                          ? null
                          : () async {
                              setSheetState(() {
                                submitting = true;
                                error = null;
                              });
                              try {
                                await AuthService.instance.submitElectricianReview(
                                  electricianId: widget.electrician.id,
                                  reviewerName: nameController.text.trim(),
                                  rating: selectedRating,
                                  comment: commentController.text.trim(),
                                );
                                if (sheetContext.mounted) Navigator.pop(sheetContext);
                                if (mounted) {
                                  // Optimistically bump the header rating so
                                  // it doesn't look stale until the next
                                  // full doc read.
                                  setState(() {
                                    final newCount = _reviewCount + 1;
                                    _rating = ((_rating * _reviewCount) + selectedRating) / newCount;
                                    _reviewCount = newCount;
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Thanks for your review!')),
                                  );
                                }
                              } catch (e) {
                                setSheetState(() {
                                  submitting = false;
                                  error = 'Could not submit review: $e';
                                });
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: submitting
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Submit Review'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final electrician = widget.electrician;
    return Scaffold(
      appBar: AppBar(title: Text(electrician.businessName.isNotEmpty ? electrician.businessName : electrician.name)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.green[100],
                  backgroundImage: (electrician.photoUrl != null && electrician.photoUrl!.isNotEmpty)
                      ? NetworkImage(electrician.photoUrl!)
                      : null,
                  child: (electrician.photoUrl == null || electrician.photoUrl!.isEmpty)
                      ? Icon(Icons.electrical_services, color: Colors.green[800], size: 32)
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        electrician.businessName.isNotEmpty ? electrician.businessName : electrician.name,
                        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                      ),
                      Text(electrician.name, style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                      const SizedBox(height: 6),
                      RatingDisplay(rating: _rating, reviewCount: _reviewCount),
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
                Text(electrician.stationArea, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),

            const SizedBox(height: 24),
            _SectionCard(
              title: 'Experience',
              child: Row(
                children: [
                  Icon(Icons.work_history_outlined, color: Colors.green[700], size: 22),
                  const SizedBox(width: 10),
                  Text(
                    '${electrician.yearsOfExperience} years in the trade',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  if (electrician.offersEmergencyService)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.bolt, size: 14, color: Colors.blue[800]),
                          const SizedBox(width: 4),
                          Text('Emergency Service', style: TextStyle(fontSize: 11, color: Colors.blue[800], fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            _SectionCard(
              title: 'Properties Serviced',
              child: electrician.propertyTypesServiced.isEmpty
                  ? const Text('Not specified', style: TextStyle(color: Colors.grey))
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: electrician.propertyTypesServiced
                          .map((p) => Chip(
                                label: Text(p, style: const TextStyle(fontSize: 12)),
                                backgroundColor: Colors.green[50],
                                side: BorderSide(color: Colors.green[200]!),
                              ))
                          .toList(),
                    ),
            ),

            const SizedBox(height: 16),
            _SectionCard(
              title: 'Services Offered',
              child: electrician.servicesOffered.isEmpty
                  ? const Text('Not specified', style: TextStyle(color: Colors.grey))
                  : Column(
                      children: electrician.servicesOffered
                          .map((s) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 3),
                                child: Row(
                                  children: [
                                    Icon(Icons.check_circle, size: 16, color: Colors.green[700]),
                                    const SizedBox(width: 8),
                                    Text(s, style: const TextStyle(fontSize: 13)),
                                  ],
                                ),
                              ))
                          .toList(),
                    ),
            ),

            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _callNumber(electrician.phoneNumber),
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
                    onPressed: () => _whatsApp(electrician.phoneNumber),
                    icon: const Icon(Icons.chat),
                    label: const Text('WhatsApp'),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Reviews', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                TextButton.icon(
                  onPressed: _openReviewSheet,
                  icon: const Icon(Icons.rate_review_outlined, size: 18),
                  label: const Text('Leave a Review'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: AuthService.instance.electricianReviewsStream(electrician.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  );
                }
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Could not load reviews: ${snapshot.error}',
                      style: TextStyle(color: Colors.red[400], fontSize: 12),
                    ),
                  );
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'No reviews yet. Be the first to leave one!',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  );
                }

                final reviews = docs.map((d) => Review.fromMap(d.id, d.data())).toList();

                return Column(
                  children: reviews.map((r) => _ReviewTile(review: r)).toList(),
                );
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  final Review review;
  const _ReviewTile({required this.review});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(review.reviewerName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              Row(
                children: List.generate(5, (i) {
                  return Icon(
                    i < review.rating.round() ? Icons.star : Icons.star_border,
                    size: 14,
                    color: Colors.amber[700],
                  );
                }),
              ),
            ],
          ),
          if (review.comment.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(review.comment, style: const TextStyle(fontSize: 13)),
          ],
        ],
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
