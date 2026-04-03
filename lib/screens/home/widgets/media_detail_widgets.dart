import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:shimmer/shimmer.dart';

import '../../../services/rivestream_service.dart';
import '../../../theme/app_theme.dart';

class MediaQuickActionButton extends StatelessWidget {
  final VoidCallback onTap;
  final String tooltip;
  final bool isSelected;
  final IconData? materialIcon;
  final dynamic hugeIcon;

  const MediaQuickActionButton({
    super.key,
    required this.onTap,
    required this.tooltip,
    this.isSelected = false,
    this.materialIcon,
    this.hugeIcon,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 54,
      width: 54,
      decoration: BoxDecoration(
        color: isSelected ? AppTheme.primaryColor : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              isSelected ? Colors.transparent : Colors.white.withValues(alpha: 0.08),
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
          message: tooltip,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Center(
              child: materialIcon != null
                  ? Icon(
                      materialIcon,
                      color: isSelected
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.9),
                      size: 22,
                    )
                  : HugeIcon(
                      icon: hugeIcon,
                      color: isSelected
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.9),
                      size: 22.0,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class ExpandableOverviewText extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final isLong = description.length > 200;

    return GestureDetector(
      onTap: isLong ? onToggle : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 300),
            crossFadeState:
                expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: Text(
              isLong ? '${description.substring(0, 200)}...' : description,
              style: GoogleFonts.outfit(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 13.5,
                height: 1.7,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.05,
              ),
            ),
            secondChild: Text(
              description,
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
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Text(
                    expanded ? 'Show Less' : 'Read More',
                    style: GoogleFonts.outfit(
                      color: AppTheme.primaryColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: Icon(
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

class MediaInfoStatCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: const EdgeInsets.all(16),
      width: width,
      height: height,
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
              Icon(icon, size: 18, color: color ?? AppTheme.primaryColor),
              const SizedBox(width: 8),
              Text(
                label,
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
            value,
            style: GoogleFonts.outfit(
              color: color ?? Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
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
                    itemBuilder: (_, __) => Column(
                      children: [
                        Shimmer.fromColors(
                          baseColor: Colors.white.withValues(alpha: 0.05),
                          highlightColor: Colors.white.withValues(alpha: 0.1),
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
                          highlightColor: Colors.white.withValues(alpha: 0.1),
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
                  )
                : ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    scrollDirection: Axis.horizontal,
                    itemCount: cast.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 16),
                    itemBuilder: (context, index) {
                      final member = cast[index];
                      final delay = (index * 50).clamp(0, 500);
                      return Animate(
                        effects: [
                          FadeEffect(duration: 400.ms, delay: delay.ms),
                          SlideEffect(
                            begin: const Offset(0.2, 0),
                            duration: 400.ms,
                            delay: delay.ms,
                            curve: Curves.easeOutQuad,
                          ),
                        ],
                        child: GestureDetector(
                          onTap: () => onTapMember(member),
                          child: SizedBox(
                            width: 90,
                            child: Column(
                              children: [
                                Container(
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
                                    child: member.fullProfileUrl.isNotEmpty
                                        ? CachedNetworkImage(
                                            imageUrl: member.fullProfileUrl,
                                            fit: BoxFit.cover,
                                            placeholder: (_, __) => Container(
                                              color: Colors.white
                                                  .withValues(alpha: 0.05),
                                            ),
                                            errorWidget: (_, __, ___) => Container(
                                              color: Colors.white
                                                  .withValues(alpha: 0.05),
                                              child: Icon(
                                                Icons.person,
                                                color: Colors.white
                                                    .withValues(alpha: 0.3),
                                                size: 40,
                                              ),
                                            ),
                                          )
                                        : Container(
                                            color: Colors.white
                                                .withValues(alpha: 0.05),
                                            child: Icon(
                                              Icons.person,
                                              color: Colors.white
                                                  .withValues(alpha: 0.3),
                                              size: 40,
                                            ),
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  member.name,
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
                                if (member.character != null) ...[
                                  const SizedBox(height: 1),
                                  Text(
                                    member.character!,
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
                    },
                  ),
          ),
        ],
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
                    itemBuilder: (_, __) => Shimmer.fromColors(
                      baseColor: Colors.white.withValues(alpha: 0.05),
                      highlightColor: Colors.white.withValues(alpha: 0.1),
                      child: Container(
                        width: 120,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    scrollDirection: Axis.horizontal,
                    itemCount: recommendations.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final media = recommendations[index];
                      return InkWell(
                        onTap: () => onTapRecommendation(media),
                        borderRadius: BorderRadius.circular(8),
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
                                  imageUrl: media.fullPosterUrl,
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
                                          media.displayTitle,
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
                                        media.displayDate.isNotEmpty
                                            ? media.displayDate.split('-').first
                                            : 'N/A',
                                        style: GoogleFonts.outfit(
                                          color: Colors.white
                                              .withValues(alpha: 0.5),
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
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
