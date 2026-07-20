import 'package:flutter/material.dart';

/// Displays a row of stars for [rating] (0.0–5.0) followed by the numeric
/// rating and review count, e.g. "★★★★☆ 4.2 (18 reviews)".
class RatingDisplay extends StatelessWidget {
  final double rating;
  final int reviewCount;
  final double starSize;

  const RatingDisplay({
    super.key,
    required this.rating,
    required this.reviewCount,
    this.starSize = 16,
  });

  @override
  Widget build(BuildContext context) {
    if (reviewCount == 0) {
      return Text(
        'No reviews yet',
        style: TextStyle(fontSize: starSize * 0.7, color: Colors.grey[500]),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(5, (i) {
          final filled = rating >= i + 1;
          final half = !filled && rating > i && rating < i + 1;
          return Icon(
            half ? Icons.star_half : (filled ? Icons.star : Icons.star_border),
            size: starSize,
            color: Colors.amber[700],
          );
        }),
        const SizedBox(width: 6),
        Text(
          rating.toStringAsFixed(1),
          style: TextStyle(fontSize: starSize * 0.8, fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 4),
        Text(
          '($reviewCount review${reviewCount == 1 ? '' : 's'})',
          style: TextStyle(fontSize: starSize * 0.7, color: Colors.grey[600]),
        ),
      ],
    );
  }
}
