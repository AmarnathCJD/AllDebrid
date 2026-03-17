import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../theme/app_theme.dart';

class MediaInfoLoadingSkeleton extends StatelessWidget {
  const MediaInfoLoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppTheme.surfaceColor.withValues(alpha: 0.3),
      highlightColor: AppTheme.surfaceColor.withValues(alpha: 0.6),
      child: Column(
        children: [
          // Hero poster area
          Container(
            height: 250,
            color: AppTheme.surfaceColor,
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Container(
                  height: 24,
                  width: 200,
                  color: AppTheme.surfaceColor,
                ),
                const SizedBox(height: 12),
                // Metadata row
                Row(
                  children: [
                    Container(
                      height: 16,
                      width: 80,
                      color: AppTheme.surfaceColor,
                    ),
                    const SizedBox(width: 12),
                    Container(
                      height: 16,
                      width: 60,
                      color: AppTheme.surfaceColor,
                    ),
                    const SizedBox(width: 12),
                    Container(
                      height: 16,
                      width: 100,
                      color: AppTheme.surfaceColor,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Overview text
                Container(
                  height: 16,
                  width: double.infinity,
                  color: AppTheme.surfaceColor,
                ),
                const SizedBox(height: 8),
                Container(
                  height: 16,
                  width: 250,
                  color: AppTheme.surfaceColor,
                ),
                const SizedBox(height: 32),
                // Season selector (for TV shows)
                Container(
                  height: 40,
                  width: 120,
                  color: AppTheme.surfaceColor,
                ),
                const SizedBox(height: 24),
                // Episodes grid
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 4,
                  childAspectRatio: 1.5,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  children: List.generate(8, (index) {
                    return Container(
                      color: AppTheme.surfaceColor,
                    );
                  }),
                ),
                const SizedBox(height: 32),
                // Recommendations
                Container(
                  height: 20,
                  width: 150,
                  color: AppTheme.surfaceColor,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 200,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: 6,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Container(
                          width: 120,
                          color: AppTheme.surfaceColor,
                        ),
                      );
                    },
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

class SeasonSelectorSkeleton extends StatelessWidget {
  const SeasonSelectorSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppTheme.surfaceColor.withValues(alpha: 0.3),
      highlightColor: AppTheme.surfaceColor.withValues(alpha: 0.6),
      child: SizedBox(
        height: 40,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: 5,
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Container(
                width: 60,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class EpisodeListSkeleton extends StatelessWidget {
  final int itemCount;

  const EpisodeListSkeleton({super.key, this.itemCount = 8});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppTheme.surfaceColor.withValues(alpha: 0.3),
      highlightColor: AppTheme.surfaceColor.withValues(alpha: 0.6),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 4,
        childAspectRatio: 1.5,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        children: List.generate(itemCount, (index) {
          return Container(
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(8),
            ),
          );
        }),
      ),
    );
  }
}

class RecommendationsCarouselSkeleton extends StatelessWidget {
  final int itemCount;

  const RecommendationsCarouselSkeleton({super.key, this.itemCount = 6});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppTheme.surfaceColor.withValues(alpha: 0.3),
      highlightColor: AppTheme.surfaceColor.withValues(alpha: 0.6),
      child: SizedBox(
        height: 200,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: itemCount,
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Container(
                width: 120,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class CastListSkeleton extends StatelessWidget {
  final int itemCount;

  const CastListSkeleton({super.key, this.itemCount = 8});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppTheme.surfaceColor.withValues(alpha: 0.3),
      highlightColor: AppTheme.surfaceColor.withValues(alpha: 0.6),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          childAspectRatio: 0.75,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          return Column(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                height: 12,
                color: AppTheme.surfaceColor,
              ),
            ],
          );
        },
      ),
    );
  }
}
