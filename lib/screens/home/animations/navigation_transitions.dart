import 'package:flutter/material.dart';

/// Custom Page Route Transitions for Enhanced Navigation Experience

class SmoothPageTransition extends PageRouteBuilder {
  @override
  final Widget Function(BuildContext, Animation<double>, Animation<double>)
      pageBuilder;
  final Duration duration;

  SmoothPageTransition({
    required this.pageBuilder,
    this.duration = const Duration(milliseconds: 600),
  }) : super(
          transitionDuration: duration,
          reverseTransitionDuration:
              Duration(milliseconds: (duration.inMilliseconds * 0.7).toInt()),
          pageBuilder: (context, animation, secondaryAnimation) {
            return pageBuilder(context, animation, secondaryAnimation);
          },
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final forwardCurved =
                CurvedAnimation(parent: animation, curve: Curves.easeOutExpo);
            final backwardCurved = CurvedAnimation(
                parent: secondaryAnimation, curve: Curves.easeInCubic);

            return Stack(
              children: [
                // Background fade with scale
                ScaleTransition(
                  scale: Tween<double>(begin: 0.97, end: 1.0)
                      .animate(backwardCurved),
                  child: FadeTransition(
                    opacity: Tween<double>(begin: 0.0, end: 1.0)
                        .animate(forwardCurved),
                    child: Container(color: Colors.black45),
                  ),
                ),
                // Content with diagonal slide + fade + scale
                FadeTransition(
                  opacity: Tween<double>(begin: 0.0, end: 1.0)
                      .animate(forwardCurved),
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.04, 0.06),
                      end: Offset.zero,
                    ).animate(forwardCurved),
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.94, end: 1.0)
                          .animate(forwardCurved),
                      child: child,
                    ),
                  ),
                ),
              ],
            );
          },
        );
}

/// Enhanced Page Transition with Blur Background
class BlurBackgroundTransition extends PageRouteBuilder {
  @override
  final Widget Function(BuildContext, Animation<double>, Animation<double>)
      pageBuilder;
  final Duration duration;
  final double blurAmount;

  BlurBackgroundTransition({
    required this.pageBuilder,
    this.duration = const Duration(milliseconds: 600),
    this.blurAmount = 4.0,
  }) : super(
          transitionDuration: duration,
          reverseTransitionDuration:
              Duration(milliseconds: (duration.inMilliseconds * 0.7).toInt()),
          pageBuilder: (context, animation, secondaryAnimation) {
            return pageBuilder(context, animation, secondaryAnimation);
          },
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final forwardCurved =
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);

            return FadeTransition(
              opacity:
                  Tween<double>(begin: 0.0, end: 1.0).animate(forwardCurved),
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.0, 0.1),
                  end: Offset.zero,
                ).animate(forwardCurved),
                child: child,
              ),
            );
          },
        );
}

/// Staggered Content Reveal
class StaggeredRevealAnimation extends StatefulWidget {
  final List<Widget> children;
  final Duration duration;
  final Duration delay;
  final Curve curve;
  final int staggerIndex;

  const StaggeredRevealAnimation({
    super.key,
    required this.children,
    this.duration = const Duration(milliseconds: 300),
    this.delay = const Duration(milliseconds: 50),
    this.curve = Curves.easeOut,
    this.staggerIndex = 0,
  });

  @override
  State<StaggeredRevealAnimation> createState() =>
      _StaggeredRevealAnimationState();
}

class _StaggeredRevealAnimationState extends State<StaggeredRevealAnimation>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _opacityAnimations;
  late List<Animation<Offset>> _slideAnimations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      widget.children.length,
      (index) => AnimationController(
        duration: widget.duration,
        vsync: this,
      ),
    );

    _opacityAnimations = _controllers.asMap().entries.map((entry) {
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: entry.value,
          curve: widget.curve,
        ),
      );
    }).toList();

    _slideAnimations = _controllers.asMap().entries.map((entry) {
      return Tween<Offset>(
        begin: const Offset(0.0, 0.15),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: entry.value,
          curve: widget.curve,
        ),
      );
    }).toList();

    _startAnimations();
  }

  void _startAnimations() {
    for (int i = 0; i < _controllers.length; i++) {
      Future.delayed(
        widget.delay * (i + widget.staggerIndex),
        () {
          if (mounted) {
            _controllers[i].forward();
          }
        },
      );
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        widget.children.length,
        (index) => FadeTransition(
          opacity: _opacityAnimations[index],
          child: SlideTransition(
            position: _slideAnimations[index],
            child: widget.children[index],
          ),
        ),
      ),
    );
  }
}

/// Hero Poster Transition Wrapper
class HeroPosterImage extends StatelessWidget {
  final String heroTag;
  final String imageUrl;
  final Widget Function(BuildContext, Widget?) placeholderBuilder;
  final BoxFit fit;

  const HeroPosterImage({
    super.key,
    required this.heroTag,
    required this.imageUrl,
    required this.placeholderBuilder,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: heroTag,
      transitionOnUserGestures: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: placeholderBuilder(
          context,
          Image.network(
            imageUrl,
            fit: fit,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Colors.grey[800],
                child: const Center(
                  child: Icon(Icons.image_not_supported, color: Colors.grey),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Animated Bottom Sheet with Smooth Reveal
class AnimatedBottomSheetRoute<T> extends PageRouteBuilder<T> {
  final WidgetBuilder builder;
  final Duration duration;
  final bool isDismissible;

  AnimatedBottomSheetRoute({
    required this.builder,
    this.duration = const Duration(milliseconds: 400),
    this.isDismissible = true,
  }) : super(
          transitionDuration: duration,
          pageBuilder: (context, animation, secondaryAnimation) {
            return builder(context);
          },
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
              child: FadeTransition(
                opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOut),
                ),
                child: child,
              ),
            );
          },
          opaque: false,
        );
}

/// Expand/Collapse Animation
class ExpandCollapseAnimation extends StatefulWidget {
  final bool isExpanded;
  final Widget expandedChild;
  final Widget collapsedChild;
  final Duration duration;
  final VoidCallback? onToggle;

  const ExpandCollapseAnimation({
    super.key,
    required this.isExpanded,
    required this.expandedChild,
    required this.collapsedChild,
    this.duration = const Duration(milliseconds: 300),
    this.onToggle,
  });

  @override
  State<ExpandCollapseAnimation> createState() =>
      _ExpandCollapseAnimationState();
}

class _ExpandCollapseAnimationState extends State<ExpandCollapseAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
      value: widget.isExpanded ? 1.0 : 0.0,
    );
  }

  @override
  void didUpdateWidget(ExpandCollapseAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isExpanded != widget.isExpanded) {
      if (widget.isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return SizeTransition(
          sizeFactor: _controller,
          axisAlignment: -1.0,
          child: FadeTransition(
            opacity: _controller,
            child: widget.isExpanded
                ? widget.expandedChild
                : widget.collapsedChild,
          ),
        );
      },
    );
  }
}
