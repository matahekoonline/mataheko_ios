import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/hero_banner.dart';

class HeroSection extends StatefulWidget {
  final List<HeroBanner> banners;
  final Duration autoPlayInterval;

  /// Fixed aspect ratio every banner is displayed at, so admin-uploaded
  /// photos of different raw sizes all end up looking consistent
  /// (cropped to fill via BoxFit.cover). 16:9 is a good default —
  /// recommend admins upload roughly 1200x675 photos.
  final double aspectRatio;

  /// Called when a banner is tapped. The screen holding HeroSection
  /// decides what to do with banner.linkType / banner.linkValue
  /// (navigate to a category, a listing, or launch a URL).
  final ValueChanged<HeroBanner>? onBannerTap;

  const HeroSection({
    super.key,
    required this.banners,
    this.autoPlayInterval = const Duration(seconds: 4),
    this.aspectRatio = 16 / 9,
    this.onBannerTap,
  });

  @override
  State<HeroSection> createState() => _HeroSectionState();
}

// Each entry is a builder that wraps the child in a transition.
// We pick one at random every time the banner changes, so it never
// feels repetitive.
typedef _TransitionBuilder = Widget Function(
    Widget child, Animation<double> animation, bool forward);

class _HeroSectionState extends State<HeroSection>
    with TickerProviderStateMixin {
  int _index = 0;
  Timer? _timer;
  final Random _random = Random();
  late _TransitionBuilder _currentTransition;

  final List<_TransitionBuilder> _transitions = [
    // Fade + slight scale
    (child, animation, forward) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
            child: child,
          ),
        ),
    // Horizontal slide
    (child, animation, forward) => SlideTransition(
          position: Tween<Offset>(
            begin: Offset(forward ? 1.0 : -1.0, 0),
            end: Offset.zero,
          ).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
          child: child,
        ),
    // Vertical slide + fade
    (child, animation, forward) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.25),
            end: Offset.zero,
          ).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
          child: FadeTransition(opacity: animation, child: child),
        ),
    // Rotation + fade (subtle, not dizzying)
    (child, animation, forward) => RotationTransition(
          turns: Tween<double>(begin: forward ? 0.03 : -0.03, end: 0)
              .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutBack)),
          child: FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.9, end: 1.0).animate(animation),
              child: child,
            ),
          ),
        ),
  ];

  @override
  void initState() {
    super.initState();
    _currentTransition = _transitions[_random.nextInt(_transitions.length)];
    _startAutoPlay();
  }

  @override
  void didUpdateWidget(covariant HeroSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Banner list can now change live (Firestore stream from admin edits).
    // Keep the index in range and restart autoplay against the new list.
    if (widget.banners.length != oldWidget.banners.length) {
      _index = 0;
      _startAutoPlay();
    }
  }

  void _startAutoPlay() {
    _timer?.cancel();
    if (widget.banners.length <= 1) return;
    _timer = Timer.periodic(widget.autoPlayInterval, (_) {
      _goTo((_index + 1) % widget.banners.length, forward: true);
    });
  }

  void _goTo(int newIndex, {required bool forward}) {
    setState(() {
      _currentTransition = _transitions[_random.nextInt(_transitions.length)];
      _index = newIndex;
    });
  }

  void _onSwipe(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity < 0) {
      _goTo((_index + 1) % widget.banners.length, forward: true);
    } else if (velocity > 0) {
      _goTo((_index - 1 + widget.banners.length) % widget.banners.length,
          forward: false);
    }
    _startAutoPlay(); // reset timer after manual swipe
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.banners.isEmpty) return const SizedBox.shrink();
    final index = _index < widget.banners.length ? _index : 0;
    final banner = widget.banners[index];

    return GestureDetector(
      onHorizontalDragEnd: _onSwipe,
      onTap: widget.onBannerTap == null ? null : () => widget.onBannerTap!(banner),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Full device width, sits flush at the top — only the bottom
          // corners are rounded so it still reads as a card from below
          // without leaving gaps at the screen edges.
          ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
            child: AspectRatio(
              aspectRatio: widget.aspectRatio,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 550),
                transitionBuilder: (child, animation) =>
                    _currentTransition(child, animation, true),
                child: _BannerContent(key: ValueKey(banner.id), banner: banner),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Dot indicators
          if (widget.banners.length > 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.banners.length, (i) {
                  final active = i == index;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: active ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: active ? Colors.green[700] : Colors.grey[350],
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}

class _BannerContent extends StatelessWidget {
  final HeroBanner banner;
  const _BannerContent({super.key, required this.banner});

  @override
  Widget build(BuildContext context) {
    final hasImage = banner.imageUrl != null && banner.imageUrl!.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        gradient: hasImage
            ? null
            : LinearGradient(
                colors: banner.gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        color: hasImage ? Colors.black : null,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (hasImage)
            Image.network(
              banner.imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) => Container(
                color: Colors.grey[400],
                child: const Icon(Icons.broken_image, color: Colors.white54, size: 40),
              ),
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return Container(color: Colors.grey[300]);
              },
            ),
          // Scrim so text stays legible over any photo.
          if (hasImage)
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.black.withOpacity(0.45), Colors.black.withOpacity(0.05)],
                  begin: Alignment.bottomLeft,
                  end: Alignment.topRight,
                ),
              ),
            ),
          // Decorative faded icon in the background — only when there's
          // no photo, so it doesn't clutter an admin's image.
          if (!hasImage)
            Positioned(
              right: -10,
              bottom: -10,
              child: Icon(
                banner.icon,
                size: 120,
                color: Colors.white.withOpacity(0.15),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!hasImage) ...[
                  Icon(banner.icon, color: banner.textColor, size: 28),
                  const SizedBox(height: 10),
                ],
                Text(
                  banner.title,
                  style: TextStyle(
                    color: banner.textColor,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  banner.subtitle,
                  style: TextStyle(
                    color: banner.textColor.withOpacity(0.9),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
