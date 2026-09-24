import 'package:flutter/material.dart';

import '../models/media_item.dart';
import '../services/media_thumbnail_service.dart';
import 'network_images.dart';

/// Video thumbnail with a play button and a small YouTube / TikTok badge.
/// Falls back to a coloured placeholder while loading or if the image
/// can't be fetched, so a card is never blank.
class MediaThumbnail extends StatelessWidget {
  final MediaItem item;
  final double? height;
  final double? width;
  final BorderRadius borderRadius;
  final double playIconSize;

  const MediaThumbnail({
    super.key,
    required this.item,
    this.height,
    this.width,
    this.borderRadius = BorderRadius.zero,
    this.playIconSize = 44,
  });

  @override
  Widget build(BuildContext context) {
    final isTikTok = item.source == MediaSource.tiktok;
    final placeholder = Container(
      color: isTikTok ? Colors.grey[900] : Colors.green[100],
    );

    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(
        height: height,
        width: width ?? double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            FutureBuilder<String?>(
              future: MediaThumbnailService.instance.thumbnailFor(item),
              builder: (context, snapshot) {
                final url = snapshot.data;
                if (url == null || url.isEmpty) return placeholder;
                return Image.network(
                  secureUrl(url),
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) =>
                      progress == null ? child : placeholder,
                  errorBuilder: (_, __, ___) => placeholder,
                );
              },
            ),
            Center(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.play_arrow_rounded,
                    color: Colors.white, size: playIconSize * 0.75),
              ),
            ),
            Positioned(
              left: 6,
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isTikTok ? Colors.black : Colors.red[700],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isTikTok ? 'TikTok' : 'YouTube',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
