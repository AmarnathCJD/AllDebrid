import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Animation utilities for enhanced media info screen experience
class MediaInfoAnimations {
  /// Parallax scroll effect - moves slower than scroll velocity
  static Widget buildParallaxPoster({
    required Widget child,
    required ScrollController scrollController,
    double parallaxStrength = 0.5,
  }) {
    return ListenableBuilder(
      listenable: scrollController,
      builder: (context, _) {
        final offset = scrollController.hasClients
            ? scrollController.offset * parallaxStrength
            : 0.0;
        return Transform.translate(
          offset: Offset(0, -offset),
          child: child,
        );
      },
    );
  }

  /// Header animation that scales and fades based on scroll position
  static Widget buildScrollableHeaderAnimation({
    required Widget child,
    required ScrollController scrollController,
    required double expandedHeight,
    double collapseThreshold = 0.7,
  }) {
    return ListenableBuilder(
      listenable: scrollController,
      builder: (context, _) {
        final scrolled = scrollController.hasClients
            ? scrollController.offset / expandedHeight
            : 0.0;

        final collapseProgress = (scrolled / collapseThreshold).clamp(0.0, 1.0);

        return Opacity(
          opacity: 1.0 - (collapseProgress * 0.3),
          child: Transform.scale(
            scale: 1.0 - (collapseProgress * 0.05),
            alignment: Alignment.topCenter,
            child: child,
          ),
        );
      },
    );
  }

  /// Staggered animations for list items
  static List<Effect<dynamic>> staggeredFadeSlideEffects({
    required int index,
    int itemCount = 1,
    int maxDelay = 400,
    Duration duration = const Duration(milliseconds: 500),
  }) {
    final delay = ((index / (itemCount > 1 ? itemCount : 1)) * maxDelay).toInt();

    return [
      FadeEffect(
        duration: duration,
        delay: Duration(milliseconds: delay),
        begin: 0.0,
        end: 1.0,
      ),
      SlideEffect(
        duration: duration,
        delay: Duration(milliseconds: delay),
        begin: const Offset(0, 0.3),
        end: Offset.zero,
        curve: Curves.easeOutCubic,
      ),
    ];
  }

  /// Scale + fade effect for content reveal
  static List<Effect<dynamic>> contentRevealEffects({
    required int index,
    int maxDelay = 300,
    Duration duration = const Duration(milliseconds: 450),
  }) {
    final delay = ((index * 50).clamp(0, maxDelay)).toInt();

    return [
      FadeEffect(
        duration: duration,
        delay: Duration(milliseconds: delay),
        begin: 0.0,
        end: 1.0,
      ),
      ScaleEffect(
        duration: duration,
        delay: Duration(milliseconds: delay),
        begin: const Offset(0.85, 0.85),
        end: const Offset(1.0, 1.0),
        curve: Curves.easeOutBack,
      ),
    ];
  }

  /// Shimmer skeleton loading animation
  static Widget buildShimmerSkeleton({
    required double width,
    required double height,
    BorderRadius? borderRadius,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: borderRadius ?? BorderRadius.circular(8),
      ),
    ).animate(onPlay: (controller) {
      controller.repeat(reverse: true);
    }).shimmer(
      duration: const Duration(milliseconds: 1800),
      color: Colors.white.withValues(alpha: 0.1),
    );
  }

  /// Build staggered section header animation
  static List<Effect<dynamic>> sectionHeaderEffects({
    Duration duration = const Duration(milliseconds: 600),
    int delayMs = 0,
  }) {
    return [
      FadeEffect(
        duration: duration,
        delay: Duration(milliseconds: delayMs),
      ),
      SlideEffect(
        duration: duration,
        delay: Duration(milliseconds: delayMs),
        begin: const Offset(-0.3, 0),
        end: Offset.zero,
        curve: Curves.easeOutCubic,
      ),
    ];
  }

  /// Bounce scroll physics for smooth responsive scrolling
  static const ScrollPhysics bounceScrollPhysics = BouncingScrollPhysics(
    parent: AlwaysScrollableScrollPhysics(),
  );
}

/// Extension for easier Duration creation from integers
extension DurationExtension on int {
  Duration get ms => Duration(milliseconds: this);
}

/// Reusable animated card background
class AnimatedCardBackground extends StatelessWidget {
  final Widget child;
  final Duration duration;
  final int delay;

  const AnimatedCardBackground({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 500),
    this.delay = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Animate(
      effects: [
        FadeEffect(duration: duration, delay: delay.ms),
        SlideEffect(
          duration: duration,
          delay: delay.ms,
          begin: const Offset(0, 0.2),
          curve: Curves.easeOutCubic,
        ),
        ScaleEffect(
          duration: duration,
          delay: delay.ms,
          begin: const Offset(0.95, 0.95),
          end: const Offset(1.0, 1.0),
          curve: Curves.easeOutBack,
        ),
      ],
      child: child,
    );
  }
}

/// Hero animation wrapper for smooth page transitions
class HeroAnimatedPoster extends StatelessWidget {
  final String imageUrl;
  final String tag;
  final BoxFit fit;
  final Widget placeholder;
  final Widget errorWidget;
  final double? width;
  final double? height;
  final VoidCallback? onTap;

  const HeroAnimatedPoster({
    super.key,
    required this.imageUrl,
    required this.tag,
    this.fit = BoxFit.cover,
    required this.placeholder,
    required this.errorWidget,
    this.width,
    this.height,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: tag,
      transitionOnUserGestures: true,
      flightShuttleBuilder: _flightShuttleBuilder,
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            imageUrl,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (_, __, ___) => errorWidget,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return placeholder;
            },
          ),
        ),
      ),
    );
  }

  Widget _flightShuttleBuilder(
    BuildContext flightContext,
    Animation<double> animation,
    HeroFlightDirection flightDirection,
    BuildContext fromHeroContext,
    BuildContext toHeroContext,
  ) {
    return Image.network(
      imageUrl,
      width: width,
      height: height,
      fit: fit,
    );
  }
}

/// Loading skeleton with staggered animation
class StaggeredSkeletonLoader extends StatelessWidget {
  final int itemCount;
  final IndexedWidgetBuilder builder;
  final double spacing;
  final int maxDelayMs;

  const StaggeredSkeletonLoader({
    super.key,
    required this.itemCount,
    required this.builder,
    this.spacing = 12,
    this.maxDelayMs = 400,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        itemCount,
        (index) {
          final delay = ((index / itemCount) * maxDelayMs).toInt();
          return Animate(
            effects: [
              FadeEffect(
                duration: const Duration(milliseconds: 600),
                delay: Duration(milliseconds: delay),
              ),
            ],
            child: Padding(
              padding: EdgeInsets.only(bottom: index < itemCount - 1 ? spacing : 0),
              child: builder(context, index),
            ),
          );
        },
      ),
    );
  }
}

/// Smooth expansion panel animation
class SmoothExpandableSection extends StatefulWidget {
  final String title;
  final Widget child;
  final bool initiallyExpanded;
  final Duration animationDuration;
  final Duration delay;

  const SmoothExpandableSection({
    super.key,
    required this.title,
    required this.child,
    this.initiallyExpanded = false,
    this.animationDuration = const Duration(milliseconds: 400),
    this.delay = const Duration(milliseconds: 0),
  });

  @override
  State<SmoothExpandableSection> createState() =>
      _SmoothExpandableSectionState();
}

class _SmoothExpandableSectionState extends State<SmoothExpandableSection>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
      value: widget.initiallyExpanded ? 1.0 : 0.0,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            if (_controller.isCompleted) {
              _controller.reverse();
            } else {
              _controller.forward();
            }
          },
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              RotationTransition(
                turns: Tween<double>(begin: 0, end: 0.5).animate(
                  CurvedAnimation(parent: _controller, curve: Curves.easeOut),
                ),
                child: const Icon(Icons.expand_more),
              ),
            ],
          ),
        ),
        SizeTransition(
          sizeFactor: CurvedAnimation(
            parent: _controller,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          ),
          child: FadeTransition(
            opacity: CurvedAnimation(
              parent: _controller,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            ),
            child: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: widget.child,
            ),
          ),
        ),
      ],
    );
  }
}
