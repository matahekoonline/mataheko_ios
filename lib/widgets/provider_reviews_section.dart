import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/review.dart';
import '../services/auth_service.dart';

/// Reusable review/rating section for every provider detail page.
/// Reads reviews from {collection}/{providerId}/reviews and writes the
/// aggregate rating/reviewCount back through AuthService.
class ProviderReviewsSection extends StatefulWidget {
  final String collection;
  final String providerId;
  final double initialRating;
  final int initialReviewCount;
  final Color accentColor;

  const ProviderReviewsSection({
    super.key,
    required this.collection,
    required this.providerId,
    this.initialRating = 0,
    this.initialReviewCount = 0,
    this.accentColor = Colors.green,
  });

  @override
  State<ProviderReviewsSection> createState() => _ProviderReviewsSectionState();
}

class _ProviderReviewsSectionState extends State<ProviderReviewsSection> {
  Future<String> _defaultReviewerName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return '';
    final snap = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final data = snap.data();
    return (data?['displayName'] ?? data?['fullName'] ?? user.displayName ?? '').toString().trim();
  }

  Future<void> _leaveReview() async {
    if (FirebaseAuth.instance.currentUser == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in before leaving a review.')),
      );
      return;
    }

    final nameController = TextEditingController(text: await _defaultReviewerName());
    final commentController = TextEditingController();
    double rating = 5;
    bool saving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Rate this provider', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                const Text('Share your experience to help other users.'),
                const SizedBox(height: 14),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(5, (index) {
                      final selected = index + 1 <= rating;
                      return IconButton(
                        onPressed: saving ? null : () => setSheetState(() => rating = index + 1.0),
                        icon: Icon(selected ? Icons.star_rounded : Icons.star_border_rounded, color: Colors.amber[700], size: 34),
                      );
                    }),
                  ),
                ),
                TextField(
                  controller: nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Your name', prefixIcon: Icon(Icons.person_outline)),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: commentController,
                  maxLines: 4,
                  maxLength: 500,
                  decoration: const InputDecoration(labelText: 'Comment', hintText: 'What was your experience?', prefixIcon: Icon(Icons.rate_review_outlined), border: OutlineInputBorder()),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: saving
                        ? null
                        : () async {
                            setSheetState(() => saving = true);
                            try {
                              await AuthService.instance.submitProviderReview(
                                collection: widget.collection,
                                providerId: widget.providerId,
                                reviewerName: nameController.text.trim(),
                                rating: rating,
                                comment: commentController.text.trim(),
                              );
                              if (sheetContext.mounted) Navigator.pop(sheetContext);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Thanks! Your review was posted.')));
                              }
                            } catch (e) {
                              setSheetState(() => saving = false);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not post review: $e')));
                              }
                            }
                          },
                    icon: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send_rounded),
                    label: Text(saving ? 'Posting...' : 'Post review'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    nameController.dispose();
    commentController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: AuthService.instance.providerReviewsStream(widget.collection, widget.providerId),
      builder: (context, snapshot) {
        final reviews = (snapshot.data?.docs ?? []).map((doc) => Review.fromMap(doc.id, doc.data())).toList();
        final average = reviews.isEmpty ? widget.initialRating : reviews.map((r) => r.rating).reduce((a, b) => a + b) / reviews.length;
        final count = reviews.isEmpty ? widget.initialReviewCount : reviews.length;

        return Card(
          margin: const EdgeInsets.only(top: 18),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: Colors.grey.shade200)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(child: Text('Reviews & ratings', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
                    FilledButton.tonalIcon(onPressed: _leaveReview, icon: const Icon(Icons.rate_review_outlined, size: 18), label: const Text('Review')),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(average.toStringAsFixed(1), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
                    const SizedBox(width: 8),
                    Icon(Icons.star_rounded, color: Colors.amber[700], size: 28),
                    const SizedBox(width: 8),
                    Text('$count review${count == 1 ? '' : 's'}', style: TextStyle(color: Colors.grey[700])),
                  ],
                ),
                const SizedBox(height: 12),
                if (snapshot.connectionState == ConnectionState.waiting && reviews.isEmpty)
                  const LinearProgressIndicator()
                else if (reviews.isEmpty)
                  Text('No reviews yet. Be the first to share your experience.', style: TextStyle(color: Colors.grey[600]))
                else
                  ...reviews.take(5).map((review) => Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(14)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(radius: 16, child: Text(review.reviewerName.isEmpty ? 'A' : review.reviewerName[0].toUpperCase())),
                                  const SizedBox(width: 9),
                                  Expanded(child: Text(review.reviewerName, style: const TextStyle(fontWeight: FontWeight.w700))),
                                  Row(children: List.generate(5, (i) => Icon(i < review.rating.round() ? Icons.star_rounded : Icons.star_border_rounded, size: 16, color: Colors.amber[700]))),
                                ],
                              ),
                              if (review.comment.trim().isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(review.comment, style: const TextStyle(height: 1.35)),
                              ],
                            ],
                          ),
                        ),
                      )),
                if (reviews.length > 5) ...[
                  const SizedBox(height: 10),
                  Text('Showing the latest 5 reviews', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
