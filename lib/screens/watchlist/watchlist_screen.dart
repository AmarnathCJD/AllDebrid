import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../providers/app_provider.dart';
import '../../services/imdb_service.dart';
import '../../theme/app_theme.dart';
import '../home/media_info_screen.dart';

class WatchlistScreen extends StatefulWidget {
  const WatchlistScreen({super.key});

  @override
  State<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends State<WatchlistScreen>
    with TickerProviderStateMixin {
  String _selectedCategory = 'All';
  late AnimationController _fabController;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  String _sortMode = 'custom';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scrollController.addListener(() {
      if (_scrollController.offset > 200) {
        _fabController.forward();
      } else {
        _fabController.reverse();
      }
    });
  }

  @override
  void dispose() {
    _fabController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Consumer<AppProvider>(
        builder: (context, provider, _) {
          final rawWatchlist = provider.watchlist;

          var filteredWatchlist = rawWatchlist.where((item) {
            // Category filter
            bool categoryMatch = true;
            if (_selectedCategory == 'All') {
              categoryMatch = true;
            } else if (_selectedCategory == 'Movies') {
              categoryMatch = item.kind == 'movie';
            } else if (_selectedCategory == 'TV Shows') {
              categoryMatch = item.kind == 'tvSeries' ||
                  item.kind == 'tvseries' ||
                  item.kind == 'tvEpisode';
            } else if (_selectedCategory == 'K-Drama') {
              categoryMatch = item.customCategory == 'kdrama' ||
                  (item.genres != null &&
                      item.genres!.toLowerCase().contains('korean'));
            }

            // Search filter
            bool searchMatch = _searchQuery.isEmpty ||
                item.title.toLowerCase().contains(_searchQuery.toLowerCase());

            return categoryMatch && searchMatch;
          }).toList();

          filteredWatchlist = _applySorting(filteredWatchlist, provider);
          final completionStats = _calculateStats(rawWatchlist, provider);

          return Column(
            children: [
              _buildHeader(provider),
              Expanded(
                child: filteredWatchlist.isEmpty
                    ? _buildEmptyState()
                    : ListView(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                        children: [
                          _buildSearchBar(),
                          const SizedBox(height: 12),
                          _buildStatsBar(completionStats),
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
                            child: Row(
                              children: [
                                Expanded(child: _buildCategories()),
                                _buildSortButton(),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          ...filteredWatchlist.map((item) {
                            return _WatchlistListItem(
                              key: ValueKey(item.id),
                              item: item,
                              provider: provider,
                              onDelete: () => _deleteItem(provider, item),
                              onPriorityChange: () =>
                                  _cyclePriority(provider, item),
                            );
                          }),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FadeTransition(
        opacity: _fabController,
        child: ScaleTransition(
          scale: _fabController,
          child: FloatingActionButton.small(
            onPressed: () => _scrollController.animateTo(0,
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOut),
            backgroundColor: AppTheme.primaryColor,
            child: const Icon(Icons.arrow_upward_rounded,
                color: Colors.black, size: 18),
          ),
        ),
      ),
    );
  }

  List<ImdbSearchResult> _applySorting(
      List<ImdbSearchResult> list, AppProvider provider) {
    switch (_sortMode) {
      case 'priority':
        return List.from(list)
          ..sort((a, b) => b.priority.compareTo(a.priority));
      case 'alphabetical':
        return List.from(list)
          ..sort(
              (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      case 'rating':
        return List.from(list)
          ..sort((a, b) {
            final ra = double.tryParse(a.rating ?? '0') ?? 0;
            final rb = double.tryParse(b.rating ?? '0') ?? 0;
            return rb.compareTo(ra);
          });
      default:
        return list;
    }
  }

  Map<String, dynamic> _calculateStats(
      List<ImdbSearchResult> watchlist, AppProvider provider) {
    int total = watchlist.length;
    int completed = 0;
    int inProgress = 0;
    double totalProgress = 0;

    for (final item in watchlist) {
      final isTv = item.kind?.toLowerCase().contains('tv') == true ||
          item.kind?.toLowerCase() == 'tvseries';

      if (isTv) {
        final key = 'pos_tmdb_${item.id}_s1_e1';
        final pos = provider.getSetting<int>(key) ?? 0;
        if (pos > 0) {
          totalProgress += 0.5;
          inProgress++;
        }
      } else {
        final key = 'pos_tmdb_${item.id}';
        final pos = provider.getSetting<int>(key) ?? 0;
        if (pos > 0) {
          final progress = pos / (120 * 60 * 1000);
          totalProgress += progress.clamp(0.0, 1.0);
          if (progress > 0.9) {
            completed++;
          } else {
            inProgress++;
          }
        }
      }
    }

    return {
      'total': total,
      'completed': completed,
      'inProgress': inProgress,
      'notStarted': total - completed - inProgress,
      'avgProgress': total > 0 ? (totalProgress / total) : 0.0,
    };
  }

  Widget _buildHeader(AppProvider provider) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'YOUR',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textMuted,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const Text(
                    'WATCHLIST',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                      height: 1,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded,
                  color: AppTheme.textMuted, size: 22),
              color: AppTheme.elevatedColor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                      color: AppTheme.borderColor.withValues(alpha: 0.3),
                      width: 1)),
              onSelected: (value) {
                if (value == 'clear') {
                  _showClearDialog();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'clear',
                  child: Row(
                    children: [
                      Icon(Icons.delete_sweep_rounded,
                          color: AppTheme.errorColor, size: 18),
                      const SizedBox(width: 12),
                      Text('Clear All',
                          style: GoogleFonts.outfit(
                            color: AppTheme.errorColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          )),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() => _searchQuery = value);
        },
        decoration: InputDecoration(
          hintText: 'Search watchlist...',
          hintStyle: GoogleFonts.outfit(
            color: AppTheme.textMuted.withValues(alpha: 0.6),
            fontSize: 13,
          ),
          prefixIcon: Icon(Icons.search_rounded,
              color: AppTheme.textMuted, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                  child: Icon(Icons.close_rounded,
                      color: AppTheme.textMuted, size: 18),
                )
              : null,
          filled: true,
          fillColor: AppTheme.surfaceColor.withValues(alpha: 0.3),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: AppTheme.borderColor.withValues(alpha: 0.2),
              width: 0.8,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: AppTheme.borderColor.withValues(alpha: 0.2),
              width: 0.8,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: AppTheme.primaryColor.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          isDense: true,
        ),
        style: GoogleFonts.outfit(
          color: AppTheme.textPrimary,
          fontSize: 13,
        ),
        cursorColor: AppTheme.primaryColor,
      ),
    );
  }

  Widget _buildStatsBar(Map<String, dynamic> stats) {
    final total = stats['total'] as int;
    if (total == 0) return const SizedBox.shrink();

    final completed = stats['completed'] as int;
    final inProgress = stats['inProgress'] as int;
    final notStarted = stats['notStarted'] as int;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppTheme.borderColor.withValues(alpha: 0.25),
            width: 0.8,
          ),
        ),
        child: Row(
          children: [
            _buildStatChip(Icons.check_circle_outline_rounded, '$completed',
                'Done',
                color: AppTheme.successColor),
            const SizedBox(width: 12),
            _buildStatChip(Icons.play_circle_outline_rounded, '$inProgress',
                'Watching',
                color: AppTheme.primaryColor),
            const SizedBox(width: 12),
            _buildStatChip(
                Icons.circle_outlined, '$notStarted', 'Pending',
                color: AppTheme.textMuted),
            const Spacer(),
            SizedBox(
              width: 36,
              height: 36,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: total > 0 ? completed / total : 0,
                    strokeWidth: 2.5,
                    backgroundColor: AppTheme.borderColor.withValues(alpha: 0.3),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Color(0xFF5CB85C)),
                  ),
                  Text(
                    '${total > 0 ? ((completed / total) * 100).toInt() : 0}%',
                    style: GoogleFonts.outfit(
                      color: AppTheme.textMuted,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String value, String label,
      {required Color color}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(
              value,
              style: GoogleFonts.outfit(
                color: AppTheme.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.outfit(
            color: AppTheme.textMuted,
            fontSize: 9,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildSortButton() {
    return PopupMenuButton<String>(
      icon: Icon(Icons.sort_rounded,
          color: AppTheme.textMuted, size: 22),
      color: AppTheme.elevatedColor,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
              color: AppTheme.borderColor.withValues(alpha: 0.3), width: 1)),
      onSelected: (value) {
        setState(() => _sortMode = value);
        HapticFeedback.selectionClick();
      },
      itemBuilder: (context) => [
        _buildSortOption(
            'custom', 'Custom Order', Icons.drag_indicator_rounded),
        _buildSortOption('priority', 'Priority', Icons.flag_rounded),
        _buildSortOption('alphabetical', 'A-Z', Icons.sort_by_alpha_rounded),
        _buildSortOption('rating', 'Rating', Icons.star_rounded),
      ],
    );
  }

  PopupMenuItem<String> _buildSortOption(
      String value, String label, IconData icon) {
    final isSelected = _sortMode == value;
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon,
              size: 16,
              color: isSelected
                  ? AppTheme.primaryColor
                  : AppTheme.textSecondary),
          const SizedBox(width: 12),
          Text(
            label,
            style: GoogleFonts.outfit(
              color:
                  isSelected ? AppTheme.primaryColor : AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          if (isSelected) ...[
            const Spacer(),
            Icon(Icons.check_rounded,
                size: 16, color: AppTheme.primaryColor),
          ],
        ],
      ),
    );
  }

  Widget _buildCategories() {
    final categories = ['All', 'Movies', 'TV Shows', 'K-Drama'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: categories.map((cat) {
          final isSelected = _selectedCategory == cat;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                setState(() => _selectedCategory = cat);
                HapticFeedback.lightImpact();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primaryColor.withValues(alpha: 0.15)
                      : AppTheme.surfaceColor.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.primaryColor.withValues(alpha: 0.4)
                        : AppTheme.borderColor.withValues(alpha: 0.2),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  cat,
                  style: GoogleFonts.outfit(
                    color: isSelected
                        ? AppTheme.primaryColor
                        : AppTheme.textSecondary,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.bookmark_border_rounded,
              size: 32,
              color: AppTheme.primaryColor.withValues(alpha: 0.3),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _selectedCategory == 'All'
                ? 'Your watchlist is empty'
                : 'No $_selectedCategory in your watchlist',
            style: GoogleFonts.outfit(
              fontSize: 15,
              color: AppTheme.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Browse to add items',
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: AppTheme.textMuted.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  void _deleteItem(AppProvider provider, ImdbSearchResult item) {
    HapticFeedback.mediumImpact();
    provider.toggleWatchlist(item);

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Removed "${item.title}"',
            style: GoogleFonts.outfit(fontSize: 12)),
        backgroundColor: AppTheme.elevatedColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        action: SnackBarAction(
          label: 'UNDO',
          textColor: AppTheme.primaryColor,
          onPressed: () => provider.toggleWatchlist(item),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _cyclePriority(AppProvider provider, ImdbSearchResult item) {
    HapticFeedback.selectionClick();
    final nextPriority = (item.priority + 1) % 3;
    provider.updateWatchlistPriority(item.id, nextPriority);
  }

  void _showClearDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.elevatedColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: AppTheme.borderColor.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        title: Text('Clear Watchlist',
            style: GoogleFonts.outfit(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w700,
            )),
        content: Text(
          'This will remove all items from your watchlist.',
          style: GoogleFonts.outfit(
            color: AppTheme.textSecondary,
            fontSize: 13,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: GoogleFonts.outfit(
                  color: AppTheme.textMuted,
                  fontWeight: FontWeight.w600,
                )),
          ),
          TextButton(
            onPressed: () {
              context.read<AppProvider>().clearWatchlist();
              Navigator.pop(context);
            },
            child: Text('Clear',
                style: GoogleFonts.outfit(
                  color: AppTheme.errorColor,
                  fontWeight: FontWeight.w700,
                )),
          ),
        ],
      ),
    );
  }
}

class _WatchlistListItem extends StatelessWidget {
  final ImdbSearchResult item;
  final AppProvider provider;
  final VoidCallback onDelete;
  final VoidCallback onPriorityChange;

  const _WatchlistListItem({
    super.key,
    required this.item,
    required this.provider,
    required this.onDelete,
    required this.onPriorityChange,
  });

  double _getProgress() {
    final isTv = item.kind?.toLowerCase().contains('tv') == true ||
        item.kind?.toLowerCase() == 'tvseries';

    if (isTv) {
      final key = 'pos_tmdb_${item.id}_s1_e1';
      final pos = provider.getSetting<int>(key) ?? 0;
      if (pos > 0) return 0.5;
      return 0.0;
    } else {
      final key = 'pos_tmdb_${item.id}';
      final pos = provider.getSetting<int>(key) ?? 0;
      if (pos <= 0) return 0.0;
      const runtimeMin = 120;
      const totalMs = runtimeMin * 60 * 1000;
      return (pos / totalMs).clamp(0.0, 1.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _getProgress();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Slidable(
        key: ValueKey(item.id),
        endActionPane: ActionPane(
          motion: const BehindMotion(),
          dismissible: DismissiblePane(onDismissed: onDelete),
          children: [
            SlidableAction(
              onPressed: (_) => onDelete(),
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
              icon: Icons.delete_rounded,
              label: 'Delete',
              borderRadius: BorderRadius.circular(12),
            ),
          ],
        ),
        startActionPane: ActionPane(
          motion: const BehindMotion(),
          extentRatio: 0.55,
          children: [
            SlidableAction(
              onPressed: (_) {
                provider.updateWatchlistPriority(item.id, 0);
                HapticFeedback.selectionClick();
              },
              backgroundColor: const Color(0xFF607D8B),
              foregroundColor: Colors.white,
              icon: Icons.low_priority_rounded,
              label: 'Low',
              borderRadius:
                  const BorderRadius.horizontal(left: Radius.circular(12)),
            ),
            SlidableAction(
              onPressed: (_) {
                provider.updateWatchlistPriority(item.id, 1);
                HapticFeedback.selectionClick();
              },
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.black,
              icon: Icons.flag_rounded,
              label: 'Med',
            ),
            SlidableAction(
              onPressed: (_) {
                provider.updateWatchlistPriority(item.id, 2);
                HapticFeedback.selectionClick();
              },
              backgroundColor: AppTheme.accentColor,
              foregroundColor: Colors.white,
              icon: Icons.priority_high_rounded,
              label: 'High',
              borderRadius:
                  const BorderRadius.horizontal(right: Radius.circular(12)),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                PageRouteBuilder(
                  transitionDuration: const Duration(milliseconds: 400),
                  reverseTransitionDuration: const Duration(milliseconds: 350),
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      MediaInfoScreen(item: item),
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) {
                    return FadeTransition(
                      opacity: animation,
                      child: child,
                    );
                  },
                ),
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 96,
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.borderColor.withValues(alpha: 0.2),
                  width: 0.8,
                ),
              ),
              child: Stack(
                children: [
                  if (progress > 0)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(12),
                          bottomRight: Radius.circular(12),
                        ),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 2,
                          backgroundColor: Colors.transparent,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            progress > 0.9
                                ? AppTheme.successColor
                                : AppTheme.primaryColor,
                          ),
                        ),
                      ),
                    ),
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          bottomLeft: Radius.circular(12),
                        ),
                        child: SizedBox(
                          width: 68,
                          height: 96,
                          child: CachedNetworkImage(
                            imageUrl: item.posterUrl,
                            fit: BoxFit.cover,
                            placeholder: (_, __) =>
                                Container(color: AppTheme.cardColor),
                            errorWidget: (_, __, ___) =>
                                Container(color: AppTheme.cardColor),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  color: AppTheme.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    item.year,
                                    style: GoogleFonts.outfit(
                                      color: AppTheme.textMuted,
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _buildPriorityBadge(),
                                  if (progress > 0) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: (progress > 0.9
                                                ? AppTheme.successColor
                                                : AppTheme.primaryColor)
                                            .withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        progress > 0.9
                                            ? 'WATCHED'
                                            : '${(progress * 100).toInt()}%',
                                        style: GoogleFonts.outfit(
                                          color: progress > 0.9
                                              ? AppTheme.successColor
                                              : AppTheme.primaryColor,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const Spacer(),
                              Row(
                                children: [
                                  if (item.rating != null) ...[
                                    const Icon(Icons.star_rounded,
                                        color: Color(0xFFFFD600), size: 12),
                                    const SizedBox(width: 3),
                                    Text(
                                      item.rating!,
                                      style: GoogleFonts.outfit(
                                        color: AppTheme.textSecondary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                  const Spacer(),
                                  if (item.kind != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryColor
                                            .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        item.kind!.toLowerCase().contains('tv')
                                            ? 'TV'
                                            : 'MOVIE',
                                        style: GoogleFonts.outfit(
                                          color: AppTheme.primaryColor,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPriorityBadge() {
    final Map<int, Map<String, dynamic>> priorityMap = {
      0: {'label': 'LOW', 'color': const Color(0xFF607D8B)},
      1: {'label': 'MED', 'color': AppTheme.primaryColor},
      2: {'label': 'HIGH', 'color': AppTheme.accentColor},
    };

    final pInfo = priorityMap[item.priority] ?? priorityMap[1]!;

    return GestureDetector(
      onTap: onPriorityChange,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
          color: (pInfo['color'] as Color).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: (pInfo['color'] as Color).withValues(alpha: 0.25),
            width: 0.5,
          ),
        ),
        child: Text(
          pInfo['label'],
          style: GoogleFonts.outfit(
            color: pInfo['color'],
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}
