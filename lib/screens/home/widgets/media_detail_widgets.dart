import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:shimmer/shimmer.dart';

import '../../../services/rivestream_service.dart';
import '../../../theme/app_theme.dart';

class MediaQuickActionButton extends StatefulWidget {
  final VoidCallback onTap;
  final String tooltip;
  final bool isSelected;
  final bool highlightBackground;
  final Color? iconColor;
  final IconData? materialIcon;
  final dynamic hugeIcon;

  const MediaQuickActionButton({
    super.key,
    required this.onTap,
    required this.tooltip,
    this.isSelected = false,
    this.highlightBackground = true,
    this.iconColor,
    this.materialIcon,
    this.hugeIcon,
  });

  @override
  State<MediaQuickActionButton> createState() => _MediaQuickActionButtonState();
}

class _MediaQuickActionButtonState extends State<MediaQuickActionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _onTapDown() {
    _pressController.forward();
  }

  void _onTapUp() {
    _pressController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 54,
      width: 54,
      decoration: BoxDecoration(
        color: widget.isSelected && widget.highlightBackground
            ? AppTheme.primaryColor
            : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.isSelected && widget.highlightBackground
              ? Colors.transparent
              : Colors.white.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Tooltip(
          message: widget.tooltip,
          child: ScaleTransition(
            scale: Tween<double>(begin: 1.0, end: 0.92).animate(
              CurvedAnimation(parent: _pressController, curve: Curves.easeOut),
            ),
            child: GestureDetector(
              onTapDown: (_) => _onTapDown(),
              onTapUp: (_) {
                _onTapUp();
                widget.onTap();
              },
              onTapCancel: _onTapUp,
              child: Center(
                child: widget.materialIcon != null
                    ? Icon(
                        widget.materialIcon,
                        color: widget.iconColor ??
                            (widget.isSelected
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.9)),
                        size: 22,
                      )
                    : HugeIcon(
                        icon: widget.hugeIcon,
                        color: widget.iconColor ??
                            (widget.isSelected
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.9)),
                        size: 22.0,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ExpandableOverviewText extends StatefulWidget {
  final String description;
  final bool expanded;
  final VoidCallback? onToggle;

  const ExpandableOverviewText({
    super.key,
    required this.description,
    required this.expanded,
    this.onToggle,
  });

  @override
  State<ExpandableOverviewText> createState() => _ExpandableOverviewTextState();
}

class _ExpandableOverviewTextState extends State<ExpandableOverviewText>
    with SingleTickerProviderStateMixin {
  late AnimationController _expandController;

  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    if (widget.expanded) {
      _expandController.forward();
    }
  }

  @override
  void didUpdateWidget(ExpandableOverviewText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.expanded != oldWidget.expanded) {
      if (widget.expanded) {
        _expandController.forward();
      } else {
        _expandController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _expandController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLong = widget.description.length > 200;

    return GestureDetector(
      onTap: isLong
          ? () {
              HapticFeedback.lightImpact();
              widget.onToggle?.call();
            }
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 350),
            crossFadeState: widget.expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: Text(
              isLong ? '${widget.description.substring(0, 200)}...' : widget.description,
              style: GoogleFonts.outfit(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 13.5,
                height: 1.7,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.05,
              ),
            ),
            secondChild: Text(
              widget.description,
              style: GoogleFonts.outfit(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 13.5,
                height: 1.7,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.05,
              ),
            ),
          ),
          if (isLong)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  Text(
                    widget.expanded ? 'Show Less' : 'Read More',
                    style: GoogleFonts.outfit(
                      color: AppTheme.primaryColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: widget.expanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 350),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 14,
                      color: AppTheme.primaryColor,
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

class MediaSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;

  const MediaSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 0, bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle!,
                  style: GoogleFonts.outfit(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class MediaInfoStatCard extends StatefulWidget {
  final String label;
  final IconData icon;
  final String value;
  final Color? color;
  final double width;
  final double height;
  final EdgeInsetsGeometry margin;

  const MediaInfoStatCard({
    super.key,
    required this.label,
    required this.icon,
    required this.value,
    this.color,
    this.width = 140,
    this.height = 100,
    this.margin = const EdgeInsets.only(right: 12),
  });

  @override
  State<MediaInfoStatCard> createState() => _MediaInfoStatCardState();
}

class _MediaInfoStatCardState extends State<MediaInfoStatCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _hoverController;

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _hoverController.forward(),
      onExit: (_) => _hoverController.reverse(),
      child: ScaleTransition(
        scale: Tween<double>(begin: 1.0, end: 1.04).animate(
          CurvedAnimation(parent: _hoverController, curve: Curves.easeOut),
        ),
        child: Container(
          margin: widget.margin,
          padding: const EdgeInsets.all(16),
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(widget.icon,
                      size: 18,
                      color: widget.color ?? AppTheme.primaryColor),
                  const SizedBox(width: 8),
                  Text(
                    widget.label,
                    style: GoogleFonts.outfit(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                widget.value,
                style: GoogleFonts.outfit(
                  color: widget.color ?? Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CastCarouselSection extends StatelessWidget {
  final bool isLoading;
  final List<CastMember> cast;
  final VoidCallback? onSeeAll;
  final void Function(CastMember member) onTapMember;

  const CastCarouselSection({
    super.key,
    required this.isLoading,
    required this.cast,
    required this.onTapMember,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    if (cast.isEmpty && !isLoading) {
      return const SizedBox.shrink();
    }

    return RepaintBoundary(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MediaSectionHeader(title: 'CAST', subtitle: 'Starring'),
          SizedBox(
            height: 140,
            child: isLoading
                ? ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: 5,
                    separatorBuilder: (_, __) => const SizedBox(width: 16),
                    itemBuilder: (_, index) {
                      final delay = (index * 80).ms;
                      return Animate(
                        effects: [
                          FadeEffect(duration: 600.ms, delay: delay),
                          ScaleEffect(
                            begin: const Offset(0.8, 0.8),
                            end: const Offset(1.0, 1.0),
                            duration: 500.ms,
                            delay: delay,
                            curve: Curves.easeOutBack,
                          ),
                        ],
                        child: Column(
                          children: [
                            Shimmer.fromColors(
                              baseColor: Colors.white.withValues(alpha: 0.05),
                              highlightColor: Colors.white.withValues(alpha: 0.12),
                              child: Container(
                                width: 90,
                                height: 90,
                                decoration: const BoxDecoration(
                                  color: Colors.black,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Shimmer.fromColors(
                              baseColor: Colors.white.withValues(alpha: 0.05),
                              highlightColor: Colors.white.withValues(alpha: 0.12),
                              child: Container(
                                width: 90,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  )
                : ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    scrollDirection: Axis.horizontal,
                    itemCount: cast.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 16),
                    itemBuilder: (context, index) {
                      final member = cast[index];
                      final delay = (index * 60).clamp(0, 400).ms;
                      return Animate(
                        effects: [
                          FadeEffect(duration: 500.ms, delay: delay),
                          SlideEffect(
                            begin: const Offset(0.3, 0.2),
                            duration: 450.ms,
                            delay: delay,
                            curve: Curves.easeOutCubic,
                          ),
                          ScaleEffect(
                            begin: const Offset(0.85, 0.85),
                            end: const Offset(1.0, 1.0),
                            duration: 450.ms,
                            delay: delay,
                            curve: Curves.easeOutBack,
                          ),
                        ],
                        child: _CastMemberCard(
                          member: member,
                          onTap: () => onTapMember(member),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _CastMemberCard extends StatefulWidget {
  final CastMember member;
  final VoidCallback onTap;

  const _CastMemberCard({
    required this.member,
    required this.onTap,
  });

  @override
  State<_CastMemberCard> createState() => _CastMemberCardState();
}

class _CastMemberCardState extends State<_CastMemberCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _hoverController;

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      child: MouseRegion(
        onEnter: (_) => _hoverController.forward(),
        onExit: (_) => _hoverController.reverse(),
        child: SizedBox(
          width: 90,
          child: Column(
            children: [
              ScaleTransition(
                scale: Tween<double>(begin: 1.0, end: 1.08).animate(
                  CurvedAnimation(parent: _hoverController, curve: Curves.easeOut),
                ),
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                      width: 1.5,
                    ),
                  ),
                  child: ClipOval(
                    child: widget.member.fullProfileUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: widget.member.fullProfileUrl,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              color: Colors.white.withValues(alpha: 0.05),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              color: Colors.white.withValues(alpha: 0.05),
                              child: Icon(
                                Icons.person,
                                color: Colors.white.withValues(alpha: 0.3),
                                size: 40,
                              ),
                            ),
                          )
                        : Container(
                            color: Colors.white.withValues(alpha: 0.05),
                            child: Icon(
                              Icons.person,
                              color: Colors.white.withValues(alpha: 0.3),
                              size: 40,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.member.name,
                maxLines: 1,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  height: 1.1,
                ),
              ),
              if (widget.member.character != null) ...[
                const SizedBox(height: 1),
                Text(
                  widget.member.character!,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class RecommendationsCarouselSection extends StatelessWidget {
  final bool isLoading;
  final List<RiveStreamMedia> recommendations;
  final void Function(RiveStreamMedia media) onTapRecommendation;

  const RecommendationsCarouselSection({
    super.key,
    required this.isLoading,
    required this.recommendations,
    required this.onTapRecommendation,
  });

  @override
  Widget build(BuildContext context) {
    if (recommendations.isEmpty && !isLoading) {
      return const SizedBox.shrink();
    }

    return RepaintBoundary(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MediaSectionHeader(
            title: 'MORE LIKE THIS',
            subtitle: 'Similar titles',
          ),
          SizedBox(
            height: 230,
            child: isLoading
                ? ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: 4,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (_, index) {
                      final delay = (index * 100).ms;
                      return Animate(
                        effects: [
                          FadeEffect(duration: 600.ms, delay: delay),
                          SlideEffect(
                            begin: const Offset(0, 0.3),
                            duration: 500.ms,
                            delay: delay,
                            curve: Curves.easeOutCubic,
                          ),
                        ],
                        child: Shimmer.fromColors(
                          baseColor: Colors.white.withValues(alpha: 0.05),
                          highlightColor: Colors.white.withValues(alpha: 0.12),
                          child: Container(
                            width: 120,
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      );
                    },
                  )
                : ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    scrollDirection: Axis.horizontal,
                    itemCount: recommendations.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final media = recommendations[index];
                      final delay = (index * 75).clamp(0, 400).ms;
                      return Animate(
                        effects: [
                          FadeEffect(duration: 500.ms, delay: delay),
                          SlideEffect(
                            begin: const Offset(0, 0.4),
                            duration: 450.ms,
                            delay: delay,
                            curve: Curves.easeOutCubic,
                          ),
                          ScaleEffect(
                            begin: const Offset(0.9, 0.9),
                            end: const Offset(1.0, 1.0),
                            duration: 450.ms,
                            delay: delay,
                            curve: Curves.easeOutBack,
                          ),
                        ],
                        child: _RecommendationCard(
                          media: media,
                          onTap: () => onTapRecommendation(media),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _RecommendationCard extends StatefulWidget {
  final RiveStreamMedia media;
  final VoidCallback onTap;

  const _RecommendationCard({
    required this.media,
    required this.onTap,
  });

  @override
  State<_RecommendationCard> createState() => _RecommendationCardState();
}

class _RecommendationCardState extends State<_RecommendationCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _hoverController;

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      child: MouseRegion(
        onEnter: (_) => _hoverController.forward(),
        onExit: (_) => _hoverController.reverse(),
        child: ScaleTransition(
          scale: Tween<double>(begin: 1.0, end: 1.05).animate(
            CurvedAnimation(parent: _hoverController, curve: Curves.easeOut),
          ),
          child: Container(
            width: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.08),
                  Colors.white.withValues(alpha: 0.03),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 2 / 3,
                  child: CachedNetworkImage(
                    imageUrl: widget.media.fullPosterUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    placeholder: (_, __) => Container(
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: Colors.white.withValues(alpha: 0.05),
                      child: Icon(
                        Icons.movie,
                        color: Colors.white.withValues(alpha: 0.3),
                        size: 40,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  height: 49,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            widget.media.displayTitle,
                            maxLines: 1,
                            textAlign: TextAlign.start,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.media.displayDate.isNotEmpty
                              ? widget.media.displayDate.split('-').first
                              : 'N/A',
                          style: GoogleFonts.outfit(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 9,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
