import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../providers/riverpod_compat.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/app_provider.dart';
import '../../services/imdb_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';
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
            final categoryMatch = _matchesCategory(item);
            final searchMatch = _matchesSearch(item);
            return categoryMatch && searchMatch;
          }).toList();

          filteredWatchlist = _applySorting(filteredWatchlist, provider);
          return Column(
            children: [
              _buildHeader(provider),
              Expanded(
                child: ListView(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  children: [
                    _buildStatsRow(rawWatchlist),
                    const SizedBox(height: 12),
                    _buildSearchBar(),
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
                    if (filteredWatchlist.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 48),
                        child: _buildEmptyState(),
                      )
                    else ...[
                      _buildResultsSummary(filteredWatchlist.length),
                      const SizedBox(height: 10),
                      GridView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 0.60,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: filteredWatchlist.length,
                        itemBuilder: (context, index) {
                          final item = filteredWatchlist[index];
                          return _WatchlistGridItem(
                            key: ValueKey(item.id),
                            item: item,
                            provider: provider,
                            onDelete: () => _deleteItem(provider, item),
                          );
                        },
                      ),
                    ],
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

  bool _matchesCategory(ImdbSearchResult item) {
    if (_selectedCategory == 'All') {
      return true;
    }
    if (_selectedCategory == 'Movies') {
      return item.kind == 'movie';
    }
    if (_selectedCategory == 'TV Shows') {
      return item.kind == 'tvSeries' ||
          item.kind == 'tvseries' ||
          item.kind == 'tvEpisode';
    }
    if (_selectedCategory == 'Priority') {
      return item.priority >= 7;
    }
    return true;
  }

  bool _matchesSearch(ImdbSearchResult item) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return true;
    }

    final searchable = [
      item.title,
      item.year,
      item.genres ?? '',
      item.kind ?? '',
      item.description ?? '',
      item.stars ?? '',
    ].join(' ').toLowerCase();

    return searchable.contains(query);
  }

  Widget _buildHeader(AppProvider provider) {
    return SafeArea(
      bottom: false,
      child: ScreenIntroHeader(
        eyebrow: 'YOUR',
        title: 'WATCHLIST',
        subtitle: 'Keep track of what you want to watch next.',
        trailing: PopupMenuButton<String>(
          icon: Icon(Icons.more_vert_rounded,
              color: AppTheme.textMuted, size: 22),
          color: AppTheme.elevatedColor,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                  color: AppTheme.borderColor.withValues(alpha: 0.3),
                  width: 1)),
          onSelected: (value) async {
            if (value == 'export') {
              final jsonStr = jsonEncode(
                  provider.watchlist.map((e) => e.toJson()).toList());
              await Clipboard.setData(ClipboardData(text: jsonStr));
              if (context.mounted) {
                showAppSnackBar(
                  context,
                  'Watchlist JSON copied to clipboard.',
                  type: AppFeedbackType.success,
                );
              }
            } else if (value == 'clear') {
              _showClearDialog();
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'export',
              child: Row(
                children: [
                  const Icon(Icons.ios_share_rounded,
                      color: AppTheme.primaryColor, size: 18),
                  const SizedBox(width: 12),
                  Text('Export as JSON',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      )),
                ],
              ),
            ),
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
      ),
    );
  }

  Widget _buildSortButton() {
    return PopupMenuButton<String>(
      icon: Icon(Icons.sort_rounded, color: AppTheme.textMuted, size: 22),
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
              color:
                  isSelected ? AppTheme.primaryColor : AppTheme.textSecondary),
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
            Icon(Icons.check_rounded, size: 16, color: AppTheme.primaryColor),
          ],
        ],
      ),
    );
  }

  Widget _buildCategories() {
    final categories = ['All', 'Movies', 'TV Shows', 'Priority'];
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
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color:
                      isSelected ? AppTheme.primaryColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.primaryColor
                        : AppTheme.borderColor.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  cat,
                  style: GoogleFonts.outfit(
                    color: isSelected ? Colors.black : AppTheme.textSecondary,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 13,
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: EmptyState(
          icon: _searchQuery.trim().isNotEmpty
              ? Icons.search_off_rounded
              : Icons.bookmark_border_rounded,
          title: _searchQuery.trim().isNotEmpty
              ? 'No matches for "$_searchQuery"'
              : _selectedCategory == 'All'
                  ? 'Your watchlist is empty'
                  : 'No $_selectedCategory saved yet',
          subtitle: _searchQuery.trim().isNotEmpty
              ? 'Try a different title, genre, year, or clear the search.'
              : _selectedCategory == 'All'
                  ? 'Save movies and shows from Home, Browse, or Search to build your list.'
                  : 'Try switching filters or add more titles from Browse.',
        ),
      ),
    );
  }

  Widget _buildStatsRow(List<ImdbSearchResult> watchlist) {
    final movieCount = watchlist.where((item) => item.kind == 'movie').length;
    final showCount = watchlist.where((item) {
      return item.kind == 'tvSeries' ||
          item.kind == 'tvseries' ||
          item.kind == 'tvEpisode';
    }).length;
    final priorityCount = watchlist.where((item) => item.priority >= 7).length;

    return Row(
      children: [
        Expanded(
          child: StatBox(
            label: 'Saved',
            value: '${watchlist.length}',
            icon: Icons.bookmark_rounded,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: StatBox(
            label: 'Movies / TV',
            value: '$movieCount / $showCount',
            icon: Icons.movie_filter_rounded,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: StatBox(
            label: 'Priority',
            value: '$priorityCount',
            icon: Icons.flag_rounded,
            color: AppTheme.warningColor,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: AppTheme.compactCardDecoration(),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() => _searchQuery = value);
        },
        style: GoogleFonts.outfit(
          color: AppTheme.textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: 'Search titles, genres, cast, or year',
          prefixIcon:
              const Icon(Icons.search_rounded, color: AppTheme.textMuted),
          suffixIcon: _searchQuery.trim().isEmpty
              ? null
              : IconButton(
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                  icon: const Icon(Icons.close_rounded,
                      color: AppTheme.textMuted),
                ),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildResultsSummary(int count) {
    final descriptor = _searchQuery.trim().isNotEmpty
        ? 'matching "$_searchQuery"'
        : _selectedCategory == 'All'
            ? 'saved right now'
            : 'in $_selectedCategory';

    return Text(
      '$count ${count == 1 ? 'title' : 'titles'} $descriptor',
      style: GoogleFonts.outfit(
        color: AppTheme.textMuted,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  void _deleteItem(AppProvider provider, ImdbSearchResult item) {
    HapticFeedback.mediumImpact();
    provider.toggleWatchlist(item);

    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Removed "${item.title}"',
          style: GoogleFonts.outfit(fontSize: 12),
        ),
        backgroundColor: AppTheme.elevatedColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        action: SnackBarAction(
          label: 'UNDO',
          textColor: AppTheme.primaryColor,
          onPressed: () {
            provider.toggleWatchlist(item);
            showAppSnackBar(
              context,
              'Restored "${item.title}"',
              type: AppFeedbackType.success,
            );
          },
        ),
        duration: const Duration(seconds: 3),
      ),
    );
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
              showAppSnackBar(
                context,
                'Watchlist cleared',
                type: AppFeedbackType.info,
              );
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

class _WatchlistGridItem extends StatelessWidget {
  final ImdbSearchResult item;
  final AppProvider provider;
  final VoidCallback onDelete;

  const _WatchlistGridItem({
    super.key,
    required this.item,
    required this.provider,
    required this.onDelete,
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

    return GestureDetector(
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
              return FadeTransition(opacity: animation, child: child);
            },
          ),
        );
      },
      onLongPress: () {
        int currentPriority = item.priority;
        showModalBottomSheet(
          context: context,
          backgroundColor: AppTheme.surfaceColor,
          builder: (context) => SafeArea(
            child: StatefulBuilder(
              builder: (context, setModalState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Priority',
                            style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: currentPriority > 0
                                  ? AppTheme.primaryColor.withValues(alpha: 0.2)
                                  : Colors.white12,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              currentPriority == 0
                                  ? 'None'
                                  : currentPriority.toString(),
                              style: GoogleFonts.outfit(
                                color: currentPriority > 0
                                    ? AppTheme.primaryColor
                                    : Colors.white70,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: AppTheme.primaryColor,
                        inactiveTrackColor: Colors.white12,
                        thumbColor: AppTheme.primaryColor,
                        overlayColor:
                            AppTheme.primaryColor.withValues(alpha: 0.2),
                        valueIndicatorColor: AppTheme.primaryColor,
                        valueIndicatorTextStyle:
                            const TextStyle(color: Colors.black),
                      ),
                      child: Slider(
                        value: currentPriority.toDouble(),
                        min: 0,
                        max: 10,
                        divisions: 10,
                        label: currentPriority == 0
                            ? 'None'
                            : currentPriority.toString(),
                        onChanged: (val) {
                          setModalState(() {
                            currentPriority = val.toInt();
                          });
                          HapticFeedback.selectionClick();
                        },
                        onChangeEnd: (val) {
                          provider.updateWatchlistPriority(
                              item.id, currentPriority);
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Divider(height: 1, color: Colors.white12),
                    ListTile(
                      leading: const Icon(Icons.delete_rounded,
                          color: AppTheme.errorColor),
                      title: const Text('Remove from Watchlist',
                          style: TextStyle(color: AppTheme.errorColor)),
                      onTap: () {
                        Navigator.pop(context);
                        onDelete();
                      },
                    ),
                    const SizedBox(height: 8),
                  ],
                );
              },
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: AppTheme.surfaceColor.withValues(alpha: 0.3),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: item.posterUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: AppTheme.cardColor),
                  errorWidget: (_, __, ___) =>
                      Container(color: AppTheme.cardColor),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius:
                      const BorderRadius.vertical(bottom: Radius.circular(12)),
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.9),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (item.rating != null) ...[
                          const Icon(Icons.star_rounded,
                              color: Color(0xFFFFD600), size: 10),
                          const SizedBox(width: 2),
                          Text(
                            item.rating!,
                            style: GoogleFonts.outfit(
                                color: Colors.white70, fontSize: 10),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          item.year,
                          style: GoogleFonts.outfit(
                              color: Colors.white70, fontSize: 10),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
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
                    minHeight: 3,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      progress > 0.9
                          ? AppTheme.successColor
                          : AppTheme.primaryColor,
                    ),
                  ),
                ),
              ),
            if (item.priority > 0)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_rounded,
                          color: Colors.black, size: 9),
                      const SizedBox(width: 2),
                      Text(
                        '${item.priority}',
                        style: GoogleFonts.outfit(
                          color: Colors.black,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
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
  }
}
