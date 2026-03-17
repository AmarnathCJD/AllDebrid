# HomeScreen UI/UX Improvement Analysis

## Executive Summary
The home_screen.dart has a solid foundation with modern design patterns (glassmorphism, animations, haptic feedback), but there are significant opportunities for refinement in animation smoothness, visual hierarchy, performance, and interaction polish.

---

## 1. ANIMATION PATTERNS

### Current State
- ✅ Staggered animations implemented for list items
- ✅ Fade and slide animations used appropriately
- ❌ Animations lack spring physics (feel stiff)
- ❌ Hardcoded animation durations not optimized
- ❌ No micro-animations for UI state changes

### Specific Improvements

#### 1.1 Replace Linear Animations with Spring Physics
**Location:** [home_screen.dart](home_screen.dart#L519-L530)
**Current Code:**
```dart
AnimationConfiguration.staggeredList(
  position: index,
  duration: const Duration(milliseconds: 400),  // Too rigid
  child: SlideAnimation(
    horizontalOffset: 40.0,  // Fixed offset
```

**Issues:**
- Hardcoded 400ms duration feels slow
- No spring damping/bouncy feel
- All items animate the same regardless of content type

**Recommended Changes:**
```dart
// Use adaptive durations based on list size
final baseDuration = Duration(milliseconds: items.length > 10 ? 350 : 400);
final delayMultiplier = 50; // ms between items

AnimationConfiguration.staggeredList(
  position: index,
  duration: baseDuration,
  delay: Duration(milliseconds: index * delayMultiplier),
  child: SlideAnimation(
    horizontalOffset: 40.0,
    curve: Curves.easeOutBack, // Add spring-like curve
```

**Additional Pattern Files to Create:**
- Create `lib/animations/spring_animations.dart` for reusable spring curves
- Add custom AnimatedPositioned with spring curves for header animations
- Implement enter/exit transitions with curves.elasticOut

---

#### 1.2 Add Staggered Animation Delays Optimization
**Location:** Lines 519-530, 547-558, 610-621, etc. (Multiple occurrences)

**Current Issue:** All slide animations use same `horizontalOffset: 40.0` which creates uniform motion

**Improvement:**
```dart
// Create a function to calculate dynamic offset based on index
double _getStaggerOffset(int index, int totalItems) {
  return 20.0 + (index * 2.0); // Progressive increase
}

// Usage in AnimationConfiguration
SlideAnimation(
  horizontalOffset: _getStaggerOffset(index, items.length),
  curve: Curves.easeOutCirc,
```

---

#### 1.3 Carousel Animation Enhancement
**Location:** [home_screen.dart](home_screen.dart#L1779-L1790)
**Current Code:**
```dart
autoPlayAnimationDuration: const Duration(milliseconds: 700),
autoPlayCurve: Curves.easeInOutQuart,
```

**Issues:**
- 700ms is too slow for carousel transitions
- easeInOutQuart lacks visual polish on entry

**Improvement:**
```dart
autoPlayAnimationDuration: const Duration(milliseconds: 550),
autoPlayCurve: Curves.easeOutCubic, // Smoother deceleration
enlargeFactor: 0.25, // Increase from default for better prominence
```

---

## 2. LIST ITEM INTERACTIONS & GESTURE FEEDBACK

### Current State
- ✅ Double-tap to add/remove from watchlist implemented
- ✅ Single-tap navigation with proper haptic
- ❌ Limited visual feedback beyond scale animation
- ❌ No ripple/splash effects
- ❌ Long-press actions missing
- ❌ Swipe gestures not utilized

### Specific Improvements

#### 2.1 Enhanced Card Press Animation
**Location:** [home_screen.dart](home_screen.dart#L1920-1980) (_PressScaleCard class)

**Current Implementation Issues:**
```dart
onTapDown: (_) => _controller.forward(),
onTapUp: (_) => _controller.reverse(),
```
- Only scales without additional feedback
- No elevation change or color shift
- Disconnect between visual and haptic feedback timing

**Enhancement:**
```dart
class _PressScaleCard extends StatefulWidget {
  // ... existing code ...
  
  @override
  State<_PressScaleCard> createState() => _PressScaleCardState();
}

class _PressScaleCardState extends State<_PressScaleCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _pressController;
  late Animation<double> _scale;
  late Animation<double> _elevation;
  late Animation<Color?> _glowColor;

  @override
  void initState() {
    super.initState();
    
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 150),
    );
    
    _scale = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOutCubic),
    );
    
    // Add elevation animation for depth
    _elevation = Tween<double>(begin: 0, end: -4).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOutCubic),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap?.call();
      },
      onDoubleTap: () {
        HapticFeedback.mediumImpact();
        widget.onDoubleTap?.call();
      },
      onLongPress: () {
        HapticFeedback.heavyImpact(); // New feedback
        _showCardActionMenu();
      },
      onTapDown: (_) {
        _scaleController.forward();
      },
      onTapUp: (_) {
        _scaleController.reverse();
      },
      onTapCancel: () {
        _scaleController.reverse();
      },
      child: AnimatedBuilder(
        animation: Listenable.merge([_scale, _elevation]),
        builder: (context, child) => Transform.scale(
          scale: _scale.value,
          child: Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.2),
                  blurRadius: (_elevation.value.abs() * 2).clamp(0, 12),
                  offset: Offset(0, _elevation.value),
                ),
              ],
            ),
            child: child,
          ),
        ),
        child: widget.child,
      ),
    );
  }
}
```

---

#### 2.2 Add Swipe-to-Action Gestures
**Location:** After [home_screen.dart](home_screen.dart#L1070) (_buildContinueWatchingSection)

**New Feature:** Swipe left to remove from continue watching, swipe right to add to watchlist

```dart
// Add this as a new helper method in _HomeScreenState
Widget _buildSwipeableCard(WatchProgress wp, int index) {
  return Dismissible(
    key: Key('${wp.media.id}_${DateTime.now().millisecondsSinceEpoch}'),
    direction: DismissDirection.horizontal,
    background: Container(
      color: Colors.red.withValues(alpha: 0.2),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.only(left: 16),
      child: Icon(
        Icons.delete_outline,
        color: Colors.red.withValues(alpha: 0.7),
      ),
    ),
    secondaryBackground: Container(
      color: AppTheme.primaryColor.withValues(alpha: 0.1),
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 16),
      child: Icon(
        Icons.bookmark_outline,
        color: AppTheme.primaryColor,
      ),
    ),
    onDismissed: (direction) {
      if (direction == DismissDirection.startToEnd) {
        // Add to watchlist
        final imdbItem = ImdbSearchResult(
          id: wp.media.id,
          title: wp.media.title,
          posterUrl: wp.media.posterUrl,
          year: wp.media.year,
          kind: wp.media.kind,
        );
        context.read<AppProvider>().toggleWatchlist(imdbItem);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added to Watchlist')),
        );
      } else {
        // Remove from continue watching
        ref.invalidate(continueWatchingProvider);
      }
    },
    child: _PressScaleCard(
      onTap: () {
        HapticFeedback.lightImpact();
        _handleMediaTap(wp.media);
      },
      child: // ... existing card content ...
    ),
  );
}
```

---

#### 2.3 Context Menu Long-Press Actions
**Location:** Enhance _PressScaleCard with additional gesture support

```dart
void _showCardActionMenu(BuildContext context, ImdbSearchResult item) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(20),
        topRight: Radius.circular(20),
      ),
      child: Container(
        color: AppTheme.cardColor,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.share, color: AppTheme.primaryColor),
              title: Text('Share'),
              onTap: () {
                Navigator.pop(context);
                _shareMedia(item);
              },
            ),
            ListTile(
              leading: Icon(Icons.info_outline, color: AppTheme.primaryColor),
              title: Text('View Details'),
              onTap: () {
                Navigator.pop(context);
                _handleMediaTap(item);
              },
            ),
            ListTile(
              leading: Icon(Icons.playlist_add, color: AppTheme.primaryColor),
              title: Text('Add to Playlist'),
              onTap: () {
                Navigator.pop(context);
                // Implement playlist logic
              },
            ),
          ],
        ),
      ),
    ),
  );
}
```

---

## 3. LOADING STATES & SKELETON SCREENS

### Current State
- ✅ Shimmer effect implemented
- ❌ Shimmer duration too long (1500ms)
- ❌ All shimmer effects identical (no variation)
- ❌ No progressive content loading
- ❌ Missing skeleton screen for featured carousel

### Specific Improvements

#### 3.1 Optimize Shimmer Timing
**Location:** [home_screen.dart](home_screen.dart#L234-248), [home_screen.dart](home_screen.dart#L531-545)

**Current Code:**
```dart
period: const Duration(milliseconds: 1500), // Too slow
```

**Fix:**
```dart
period: const Duration(milliseconds: 1000), // Faster, more engaging
```

**Additional:** Create variation by media type:
```dart
Duration getShimmerPeriod(String mediaType) {
  switch (mediaType) {
    case 'featured':
      return const Duration(milliseconds: 900);
    case 'list':
      return const Duration(milliseconds: 1000);
    case 'card':
      return const Duration(milliseconds: 1100);
    default:
      return const Duration(milliseconds: 1000);
  }
}
```

---

#### 3.2 Add Skeleton Variation
**Location:** Create [lib/widgets/loading_skeletons.dart](lib/widgets/loading_skeletons.dart)

**New Widget:**
```dart
class MediaCardSkeleton extends StatelessWidget {
  final bool isHorizontal;
  final Duration shimmerDuration;

  const MediaCardSkeleton({
    this.isHorizontal = true,
    this.shimmerDuration = const Duration(milliseconds: 1000),
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      period: shimmerDuration,
      baseColor: Colors.white.withValues(alpha: 0.05),
      highlightColor: Colors.white.withValues(alpha: 0.12),
      child: Container(
        width: isHorizontal ? 120 : double.infinity,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}

// Usage in home_screen.dart replacing repetitive shimmer code:
Shimmer.fromColors(
  period: getShimmerPeriod('list'),
  baseColor: Colors.white.withValues(alpha: 0.05),
  highlightColor: Colors.white.withValues(alpha: 0.08),
  child: ListView.separated(
    itemCount: 6,
    separatorBuilder: (_, __) => const SizedBox(width: 8),
    itemBuilder: (_, __) => const MediaCardSkeleton(),
  ),
)
```

---

#### 3.3 Progressive Content Loading
**Location:** [home_screen.dart](home_screen.dart#L178-297) (Build method - CustomScrollView)

**Current Issue:** Entire page waits for all data before rendering

**Improvement:**
```dart
// Show featured carousel immediately while data loads
SliverToBoxAdapter(
  child: trendingAsync.maybeWhen(
    data: (data) => _FeaturedCarouselWidget(items: data.featured),
    loading: () => _buildFeaturedCarouselSkeleton(),
    orElse: () => const SizedBox.shrink(),
  ),
),
// Other sections render independently, not waiting for above
```

---

## 4. SECTION HEADERS & VISUAL HIERARCHY

### Current State
- ⚠️ Headers exist but lack visual distinction
- ❌ No parallax or interactive elements
- ❌ "VIEW ALL" button not prominent enough
- ❌ Missing visual separation between sections

### Specific Improvements

#### 4.1 Enhanced Section Headers with Interactive Elements
**Location:** [home_screen.dart](home_screen.dart#L336-374) (_buildSectionHeader)

**Current Code:**
```dart
Widget _buildSectionHeader(String title,
    {VoidCallback? onTap, Widget? trailing}) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
    // ... simple layout ...
  );
}
```

**Enhanced Version:**
```dart
Widget _buildSectionHeader(
  String title, {
  VoidCallback? onTap,
  Widget? trailing,
  String? subtitle,
  bool showBorder = false,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 18, // Increased from 17
                        fontWeight: FontWeight.w800, // Stronger
                        letterSpacing: -0.5,
                        height: 1.2,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null)
                trailing
              else if (onTap != null)
                _buildViewAllButton(),
            ],
          ),
          if (showBorder) ...[
            const SizedBox(height: 12),
            Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.1),
                    Colors.white.withValues(alpha: 0.02),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

Widget _buildViewAllButton() {
  return Material(
    color: Colors.transparent,
    child: InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {/* navigate */},
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.primaryColor.withValues(alpha: 0.15),
              AppTheme.primaryColor.withValues(alpha: 0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppTheme.primaryColor.withValues(alpha: 0.3),
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'VIEW ALL',
              style: TextStyle(
                color: AppTheme.primaryColor,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: AppTheme.primaryColor.withValues(alpha: 0.6),
              size: 10,
            ),
          ],
        ),
      ),
    ),
  );
}
```

---

#### 4.2 Add Visual Separators Between Sections
**Location:** [home_screen.dart](home_screen.dart#L178-297) (CustomScrollView slivers)

**Current:** Uses SizedBox spacers (spacing only)
**Enhancement:** Add subtle gradient dividers

```dart
// Replace generic SizedBox(height: 8) with:
SliverToBoxAdapter(
  child: Container(
    height: 8,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          Colors.transparent,
          Colors.white.withValues(alpha: 0.05),
          Colors.transparent,
        ],
      ),
    ),
  ),
),
```

---

#### 4.3 Parallax Header Effect
**Location:** New animated header section

```dart
// Add to build() method, replace static _buildHeader()
SliverToBoxAdapter(
  child: _buildParallaxHeader(),
),

Widget _buildParallaxHeader() {
  return NotificationListener<ScrollNotification>(
    onNotification: (scrollNotification) {
      if (scrollNotification is ScrollUpdateNotification) {
        setState(() {
          // Update parallax offset
        });
      }
      return false;
    },
    child: _buildHeader(), // Existing with transform
  );
}
```

---

## 5. CARD DESIGNS & VISUAL CONSISTENCY

### Current State
- ❌ High code duplication across 5+ card builder methods
- ❌ Inconsistent card specifications
- ❌ Cards lack visual variety despite similar structure
- ❌ Missing hover/focus states for accessibility

### Specific Improvements

#### 5.1 Create Unified Card Component
**Location:** Create [lib/widgets/media_card.dart](lib/widgets/media_card.dart)

**Problem:** `_buildTrendingCard`, `_buildRiveMediaCard`, `_buildWatchlistCard`, etc. are 90% identical

**Solution:**
```dart
enum MediaCardSize {
  small(width: 100),
  medium(width: 120),
  large(width: 140);

  final double width;
  const MediaCardSize({required this.width});
}

enum MediaCardVariant {
  standard,    // Poster only
  withStats,   // Poster + rating + title
  withProgress, // Poster + progress bar
  Featured,    // Large with glass panel info
}

class MediaCard extends StatefulWidget {
  final String imageUrl;
  final String title;
  final double rating;
  final VoidCallback onTap;
  final VoidCallback? onDoubleTap;
  final String heroTag;
  final MediaCardSize size;
  final MediaCardVariant variant;
  final double? progress; // For progress variant (0.0-1.0)
  final String? remainingTime; // e.g., "45m"

  const MediaCard({
    required this.imageUrl,
    required this.title,
    required this.rating,
    required this.onTap,
    this.onDoubleTap,
    required this.heroTag,
    this.size = MediaCardSize.medium,
    this.variant = MediaCardVariant.standard,
    this.progress,
    this.remainingTime,
  });

  @override
  State<MediaCard> createState() => _MediaCardState();
}

class _MediaCardState extends State<MediaCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 150),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onDoubleTap: widget.onDoubleTap != null
          ? () {
              HapticFeedback.mediumImpact();
              widget.onDoubleTap!();
            }
          : null,
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: Tween<double>(begin: 1.0, end: 0.95).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
        ),
        child: Container(
          width: widget.size.width,
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
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: _buildCardContent(),
        ),
      ),
    );
  }

  Widget _buildCardContent() {
    switch (widget.variant) {
      case MediaCardVariant.standard:
        return _buildStandardCard();
      case MediaCardVariant.withStats:
        return _buildStatsCard();
      case MediaCardVariant.withProgress:
        return _buildProgressCard();
      case MediaCardVariant.Featured:
        return _buildFeaturedCard();
    }
  }

  Widget _buildStandardCard() {
    return Hero(
      tag: widget.heroTag,
      child: CachedNetworkImage(
        imageUrl: widget.imageUrl,
        fit: BoxFit.cover,
        fadeInDuration: const Duration(milliseconds: 200),
        placeholder: (_, __) =>
            Container(color: Colors.white.withValues(alpha: 0.05)),
        errorWidget: (_, __, ___) => Container(
          color: Colors.white.withValues(alpha: 0.05),
          child: const Icon(Icons.movie, color: Colors.white24, size: 30),
        ),
      ),
    );
  }

  Widget _buildStatsCard() {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 2 / 3,
            child: _buildStandardCard(),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: Column(
              children: [
                Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.star_rounded,
                        color: Colors.amber, size: 10),
                    const SizedBox(width: 3),
                    Text(
                      widget.rating.toStringAsFixed(1),
                      style: GoogleFonts.outfit(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: 2 / 3,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildStandardCard(),
              // Progress bar overlay
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _buildProgressIndicator(),
              ),
              // Play button overlay
              Center(
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.4),
                      width: 1.2,
                    ),
                  ),
                  child: const Icon(Icons.play_arrow_rounded,
                      color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProgressIndicator() {
    if (widget.progress == null) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final filled = constraints.maxWidth * (widget.progress ?? 0.0);
        return Stack(
          children: [
            Container(
              height: 2,
              color: Colors.white.withValues(alpha: 0.1),
            ),
            Container(
              width: filled,
              height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryColor.withValues(alpha: 0.7),
                    AppTheme.primaryColor,
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFeaturedCard() {
    return _buildStatsCard(); // Simplified for now
  }
}

// Usage in home_screen.dart - MUCH cleaner:
// Instead of:
//   _buildRiveMediaCard(item)
// Use:
//   MediaCard(
//     imageUrl: item.fullPosterUrl,
//     title: item.displayTitle,
//     rating: item.voteAverage,
//     onTap: () => _handleRiveMediaNavigation(item),
//     onDoubleTap: () => /* watchlist toggle */,
//     heroTag: 'trending_media_${item.id}',
//     size: MediaCardSize.medium,
//     variant: MediaCardVariant.withStats,
//   )
```

---

#### 5.2 Reduce Duplication Across Card Builders
**Locations:** Lines 376-424, 447-495, 1120-1180, etc.

**Current Issue:** `_buildTrendingCard`, `_buildRiveMediaCard`, `_buildKDramaCard`, `_buildWatchlistCard`, `_buildGenreMediaCard` are nearly identical

**Solution:** Use unified `MediaCard` component from 5.1, eliminating ~400 lines of duplicate code

---

#### 5.3 Add Hover State for Accessibility
**Enhancement to MediaCard:**
```dart
class _MediaCardState extends State<MediaCard>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedOpacity(
        opacity: _isHovered ? 0.9 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: // ... existing card ...
      ),
    );
  }
}
```

---

## 6. SCROLL BEHAVIOR & PERFORMANCE

### Current State
- ✅ BouncingScrollPhysics provides modern feel
- ✅ cacheExtent set appropriately (150)
- ⚠️ Many RepaintBoundary wrappers (good but check necessity)
- ❌ No scroll-based animations
- ❌ Header doesn't react to scroll position
- ❌ Potential performance issues with multiple animated lists

### Specific Improvements

#### 6.1 Add Scroll-Linked Header Animations
**Location:** Add new scroll listener to _HomeScreenState

```dart
// In initState():
_scrollController.addListener(_onScroll);

void _onScroll() {
  final offset = _scrollController.offset;
  
  // Collapse search bar when scrolling down
  if (offset > 100) {
    // Trigger header collapse animation
    setState(() => _isHeaderCollapsed = true);
  } else {
    setState(() => _isHeaderCollapsed = false);
  }
}

// In _buildHeader(), wrap with AnimatedContainer:
AnimatedContainer(
  duration: const Duration(milliseconds: 300),
  height: _isHeaderCollapsed ? 40 : 48,
  child: // ... existing header ...
)
```

---

#### 6.2 Implement Scroll-to-Top Indicator
**Location:** [home_screen.dart](home_screen.dart#L37-44) (scrollToTop method)

**Enhancement:**
```dart
void scrollToTop() {
  if (_scrollController.hasClients) {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 800), // Increased from 600
      curve: Curves.easeOutCubic,
    );
  }
}

// Show floating button when user scrolls down
bool _showScrollToTop = false;

@override
void initState() {
  super.initState();
  _scrollController.addListener(() {
    setState(() => _showScrollToTop = _scrollController.offset > 500);
  });
}

// In build, add FAB:
floatingActionButton: AnimatedSlide(
  duration: const Duration(milliseconds: 300),
  offset: _showScrollToTop ? Offset.zero : const Offset(0, 2),
  child: _showScrollToTop
      ? FloatingActionButton(
          onPressed: scrollToTop,
          child: Icon(Icons.arrow_upward),
        )
      : const SizedBox.shrink(),
)
```

---

#### 6.3 Optimize List Performance with Keys
**Location:** Multiple places in itemBuilder functions

**Current Issue:** Lists missing proper keys for efficient rebuilds

```dart
// In _buildContinueWatchingSection - add keys to items:
itemBuilder: (context, index) {
  final wp = continueWatching[index];
  return AnimationConfiguration.staggeredList(
    position: index,
    duration: const Duration(milliseconds: 400),
    child: SlideAnimation(
      key: ValueKey(wp.media.id), // ADD THIS
      horizontalOffset: 20.0,
      child: FadeInAnimation(
        child: _PressScaleCard(...),
      ),
    ),
  );
}
```

---

#### 6.4 Lazy Loading for Bottom Sections
**Location:** Genre sections at bottom of page

**Current:** All genres loaded immediately
**Enhancement:**
```dart
// Create pagination for bottom sections
ListView.builder(
  itemCount: displayedGenres.length,
  itemBuilder: (context, index) {
    if (index == displayedGenres.length - 1) {
      // Load more genres when reaching end
      Future.microtask(() => _loadMoreGenres());
    }
    return _buildGenreSection(displayedGenres[index]);
  },
)
```

---

## 7. MODERN UX PATTERNS & POLISH

### Current State
- ✅ Modern glassmorphism design on search bar
- ✅ Staggered animations
- ✅ Haptic feedback
- ⚠️ Hero animations present but limited
- ❌ Missing micro-interactions
- ❌ No toast notifications for actions
- ❌ Loading progress indication

### Specific Improvements

#### 7.1 Add Action Feedback Toasts
**Location:** Replace SnackBars with more modern toast approach

**Current Code:** [home_screen.dart](home_screen.dart#L590-603)
```dart
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Text('Added to Watchlist'),
    duration: const Duration(seconds: 1),
    behavior: SnackBarBehavior.floating,
    backgroundColor: const Color(0xFF1E1E1E),
  ),
);
```

**Enhanced:**
```dart
// Create lib/widgets/custom_toast.dart
class CustomToast extends StatelessWidget {
  final String message;
  final IconData icon;
  final Duration duration;

  const CustomToast({
    required this.message,
    required this.icon,
    this.duration = const Duration(milliseconds: 2000),
  });

  static void show(
    BuildContext context, {
    required String message,
    required IconData icon,
    Duration duration = const Duration(milliseconds: 2000),
  }) {
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (context) => CustomToast(
        message: message,
        icon: icon,
        duration: duration,
      ),
    );

    overlay.insert(entry);
    Future.delayed(duration, () => entry.remove());
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 60,
      left: 16,
      right: 16,
      child: TweenAnimationBuilder(
        tween: Tween<double>(begin: 0, end: 1),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) => Transform.translate(
          offset: Offset(0, -50 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            border: Border.all(
              color: AppTheme.primaryColor.withValues(alpha: 0.3),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(12),
            backdropFilter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppTheme.primaryColor, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Usage replace SnackBar:
CustomToast.show(
  context,
  message: wasInWatchlist ? 'Removed from Watchlist' : 'Added to Watchlist',
  icon: wasInWatchlist ? Icons.remove_circle_outline : Icons.check_circle_outline,
);
```

---

#### 7.2 Add Loading Progress for Carousels
**Location:** [home_screen.dart](home_screen.dart#L1779-1790) (CarouselSlider)

**Enhancement:**
```dart
// Add progress indicator under carousel
LinearProgressIndicator(
  minHeight: 2,
  value: _currentCarouselIndex / (widget.items.length - 1),
  backgroundColor: Colors.white.withValues(alpha: 0.1),
  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
)
```

---

#### 7.3 Enhanced Navigation Transitions
**Location:** [home_screen.dart](home_screen.dart#L99-142) (_handleMediaTap)

**Current:** Complex custom transition with 3 widgets stacked
**Enhancement - Simplify with Fluttertoast alternatives:**

```dart
void _handleMediaTap(ImdbSearchResult item) {
  Navigator.push(
    context,
    PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 500),
      reverseTransitionDuration: const Duration(milliseconds: 350),
      opaque: false,
      pageBuilder: (context, animation, secondaryAnimation) =>
          MediaInfoScreen(item: item),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // Use shared axis transition for polished feel
        return SharedAxisTransition(
          animation: animation,
          secondaryAnimation: secondaryAnimation,
          transitionType: SharedAxisTransitionType.scaled,
          child: child,
        );
      },
    ),
  );
}

// Add to pubspec.yaml if not present:
// animations: ^2.0.0
```

---

#### 7.4 Add Haptic Patterns for Different Actions
**Location:** Enhance all tap handlers in home_screen.dart

```dart
// Create lib/utils/haptic_patterns.dart
class HapticPatterns {
  static Future<void> lightSuccess() async {
    await HapticFeedback.lightImpact();
  }

  static Future<void> mediumAction() async {
    await HapticFeedback.mediumImpact();
  }

  static Future<void> heavyError() async {
    await HapticFeedback.heavyImpact();
  }

  static Future<void> selection() async {
    await HapticFeedback.selectionClick();
  }

  static Future<void> successPattern() async {
    await HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 50));
    await HapticFeedback.lightImpact();
  }

  static Future<void> addedToWatchlist() async {
    await HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    await HapticFeedback.lightImpact();
  }
}

// Usage in home_screen.dart:
HapticPatterns.addedToWatchlist();
// Instead of:
HapticFeedback.mediumImpact();
```

---

## 8. ACCESSIBILITY & INCLUSIVE DESIGN

### Improvements
- Add semantic labels to all interactive elements
- Implement focus states for keyboard navigation
- Add tooltips for gestures
- Ensure sufficient color contrast

```dart
// Example enhancement to _PressScaleCard:
@override
Widget build(BuildContext context) {
  return Semantics(
    button: true,
    enabled: true,
    onTap: widget.onTap,
    label: 'Media card for ${widget.title}',
    customSemanticsActions: {
      CustomSemanticsAction(label: 'Double tap to add to watchlist'): 
          () => widget.onDoubleTap?.call(),
    },
    child: GestureDetector(
      onTap: widget.onTap,
      // ... rest of code ...
    ),
  );
}
```

---

## 9. RECOMMENDED IMPLEMENTATION PRIORITY

### Phase 1: High-Impact Quick Wins (1-2 days)
1. Unified MediaCard component (5.1) - eliminates 400+ lines
2. Optimize animation durations (1.1-1.3)
3. Enhance section headers (4.1)
4. Add custom toast notifications (7.1)

### Phase 2: Polish & Performance (2-3 days)
5. Enhanced press interactions (2.1)
6. Reduce shimmer timing (3.1)
7. Add scroll-linked header animations (6.1)
8. Implement lazy loading for genres (6.4)

### Phase 3: Advanced Features (3-5 days)
9. Swipe-to-action gestures (2.2)
10. Long-press context menus (2.3)
11. Haptic feedback patterns (7.4)
12. FloatingActionButton scroll-to-top (6.2)

### Phase 4: Polish Pass (1-2 days)
13. Accessibility improvements (8)
14. Refine micro-animations throughout
15. Performance profiling & optimization

---

## 10. ESTIMATED IMPACT

| Improvement | Performance | UI Polish | Code Quality | Effort |
|---|---|---|---|---|
| Unified MediaCard | ⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | 2-3 hrs |
| Spring animations | ⭐⭐ | ⭐⭐⭐⭐ | ⭐ | 1-2 hrs |
| Enhanced pressed state | ⭐⭐ | ⭐⭐⭐ | ⭐⭐ | 1-2 hrs |
| Scroll-linked header | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐ | 1.5-2 hrs |
| Swipe gestures | ⭐ | ⭐⭐⭐ | ⭐⭐ | 1.5-2 hrs |
| Custom toasts | ⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐ | 1-1.5 hrs |
| Lazy loading | ⭐⭐⭐⭐ | ⭐ | ⭐⭐⭐ | 1.5-2 hrs |

---

## CODE LOCATIONS SUMMARY

| Improvement | File | Lines |
|---|---|---|
| Animation patterns | home_screen.dart | 519-530, 547-558, 610-621, 1779-1790 |
| Press scale card | home_screen.dart | 1920-1980 |
| Section headers | home_screen.dart | 336-374 |
| Loading states | home_screen.dart | 234-248, 531-545 |
| Card builders | home_screen.dart | 376-424, 447-495, 1120-1180, 1370-1450 |
| Scroll behavior | home_screen.dart | 31-35, 178-297 |
| Featured carousel | home_screen.dart | 1543-1850 |
| Continue watching | home_screen.dart | 1040-1240 |

